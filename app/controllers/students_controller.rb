class StudentsController < ApplicationController
  include ApplicationHelper

  before_action :authorize!, except: [
    :names,
    :lasids,
    :sample_students_json
  ]
  before_action :authorize_for_districtwide_access_admin, only: [
    :lasids
  ]

  def authorize!
    student = Student.find(params[:id])
    raise Exceptions::EducatorNotAuthorized unless current_educator.is_authorized_for_student(student)
  end

  def authorize_for_districtwide_access_admin
    unless current_educator.admin? && current_educator.districtwide_access?
      render json: { error: "You don't have the correct authorization." }
    end
  end

  def show
    student = Student.find(params[:id])
    chart_data = StudentProfileChart.new(student).chart_data
    can_see_transition_notes = current_educator.is_authorized_to_see_transition_notes

    @serialized_data = {
      current_educator: current_educator.as_json(methods: [:labels]),
      student: serialize_student_for_profile(student),          # School homeroom, most recent school year attendance/discipline counts
      feed: student_feed(student, restricted_notes: false),     # Notes, services
      chart_data: chart_data,                                   # STAR, MCAS, discipline, attendance charts
      dibels: student.dibels_results.select(:id, :date_taken, :benchmark),
      service_types_index: ServiceSerializer.service_types_index,
      educators_index: Educator.to_index,
      access: student.latest_access_results,
      transition_notes: (can_see_transition_notes ? student.transition_notes : []),
      iep_document: student.iep_document,
      sections: serialize_student_sections_for_profile(student),
      current_educator_allowed_sections: current_educator.allowed_sections.map(&:id),
      attendance_data: {
        discipline_incidents: student.discipline_incidents.order(occurred_at: :desc),
        tardies: student.tardies.order(occurred_at: :desc),
        absences: student.absences.order(occurred_at: :desc)
      }
    }
    render 'shared/serialized_data'
  end

  def restricted_notes
    raise Exceptions::EducatorNotAuthorized unless current_educator.can_view_restricted_notes

    student = Student.find(params[:id])
    @serialized_data = {
      current_educator: current_educator,
      student: serialize_student_for_profile(student),
      feed: student_feed(student, restricted_notes: true),
      educators_index: Educator.to_index,
    }
    render 'shared/serialized_data'
  end

  def student_report
    set_up_student_report_data
    footer_text = "#{PerDistrict.new.district_name} Student Report -- Generated #{format_date_for_student_report(todays_date_for_student_report)} by #{current_educator.full_name} -- Page [page] of [topage]"

    # KR: not sure why, but JS isn't running locally for me or on Travis, so
    # disabling this check since we aren't testing anything generated by JS
    # anyway.
    wait_for_js = if params[:disable_js] && Rails.env.test? then
      {}
    else
      { window_status: 'READY' }
    end

    respond_to do |format|
      format.pdf do
        render(wait_for_js.merge({
          pdf: 'student_report',
          title: 'Student Report',
          footer: { center: footer_text, font_name: 'Open Sans', font_size: 9},
          show_as_html: params.key?('debug')
        }))
      end
    end
  end

  def photo
    student = Student.find(params[:id])

    @student_photo = student.student_photos.order(created_at: :desc).first

    return render json: { error: 'no photo' }, status: 404 if @student_photo.nil?

    @s3_filename = @student_photo.s3_filename

    object = s3.get_object(key: @s3_filename, bucket: ENV['AWS_S3_PHOTOS_BUCKET'])

    send_data object.body.read, filename: @s3_filename, type: 'image/jpeg'
  end

  # post
  def service
    clean_params = params.require(:service).permit(*[
      :student_id,
      :service_type_id,
      :date_started,
      :provided_by_educator_name,
      :estimated_end_date
    ])

    estimated_end_date = clean_params["estimated_end_date"]

    service = Service.new(clean_params.merge({
      recorded_by_educator_id: current_educator.id,
      recorded_at: Time.now
    }))

    serializer = ServiceSerializer.new(service)

    if service.save
      if estimated_end_date.present? && estimated_end_date.to_time < Time.now
        service.update_attributes(:discontinued_at => estimated_end_date.to_time, :discontinued_by_educator_id => current_educator.id)
      end
      render json: serializer.serialize_service
    else
      render json: { errors: service.errors.full_messages }, status: 422
    end
  end

  # Used by the search bar to query for student names
  def names
    cached_json_for_searchbar = current_educator.student_searchbar_json

    if cached_json_for_searchbar
      render json: cached_json_for_searchbar
    else
      render json: SearchbarHelper.names_for(current_educator)
    end
  end

  # Used by the service upload page to validate student local ids
  # LASID => "locally assigned ID"
  def lasids
    render json: Student.pluck(:local_id)
  end

  # Admin only; get a sample of students for looking at data across the site
  def sample_students_json
    raise Exceptions::EducatorNotAuthorized unless current_educator.can_set_districtwide_access?

    seed = params.fetch(:seed, 42)
    n = 20
    authorized_sample_students = authorized do
      Student.active.sample(n, random: Random.new(seed))
    end
    sample_students_json = authorized_sample_students.as_json({
      only: [:id, :grade, :first_name, :last_name],
      include: {
        school: {
          only: [:id, :name, :school_type]
        }
      }
    })
    render json: {
      sample_students: sample_students_json
    }
  end

  private

  def serialize_student_for_profile(student)
    # These are serialized, even if importing these is disabled
    # and the value is nil.
    per_district_fields = {
      house: student.house,
      counselor: student.counselor,
      sped_liaison: student.sped_liaison
    }

    student.as_json.merge(per_district_fields).merge({
      has_photo: (student.student_photos.size > 0),
      absences_count: student.most_recent_school_year_absences_count,
      tardies_count: student.most_recent_school_year_tardies_count,
      school_name: student.try(:school).try(:name),
      school_type: student.try(:school).try(:school_type),
      homeroom_name: student.try(:homeroom).try(:name),
      discipline_incidents_count: student.most_recent_school_year_discipline_incidents_count,
      restricted_notes_count: student.event_notes.where(is_restricted: true).count,
    }).stringify_keys
  end

  def serialize_student_sections_for_profile(student)
    student.sections_with_grades.as_json({:include => { :educators => {:only => :full_name}}, :methods => :course_description})
  end

  # The feed of mutable data that changes most frequently and is owned by Student Insights.
  # restricted_notes: If false display non-restricted notes, if true display only restricted notes.
  def student_feed(student, restricted_notes: false)
    {
      event_notes: student.event_notes
        .select {|note| note.is_restricted == restricted_notes}
        .map {|event_note| EventNoteSerializer.new(event_note).serialize_event_note },
      services: {
        active: student.services.active.map {|service| ServiceSerializer.new(service).serialize_service },
        discontinued: student.services.discontinued.map {|service| ServiceSerializer.new(service).serialize_service }
      },
      deprecated: {
        interventions: student.interventions.map { |intervention| DeprecatedInterventionSerializer.new(intervention).serialize_intervention }
      }
    }
  end

  def school_year_id_range(from_date, to_date)
    # Find the years represented by the dates

    #start with to_date and work backward each year until < from_date
    current_date = to_date
    school_year_ids = []

    while current_date > from_date do
      school_year_ids.push(DateToSchoolYear.new(current_date).convert.id)

      current_date = current_date - 1.year
    end

    return school_year_ids

  end

  def set_up_student_report_data
    @student = Student.find(params[:id])
    @current_educator = current_educator
    @sections = (params[:sections] || "").split(",")

    @filter_from_date = params[:from_date] ? Date.strptime(params[:from_date],  "%m/%d/%Y") : Date.today
    @filter_to_date = (params[:from_date] ? Date.strptime(params[:to_date],  "%m/%d/%Y") : Date.today).advance(days: 1) # so we include the current day

    # Load event notes that are NOT restricted for the student for the filtered dates
    @event_notes = @student.event_notes.where(:is_restricted => false).where(recorded_at: @filter_from_date..@filter_to_date)

    # Load services for the student for the filtered dates
    @services = @student.services.where("date_started <= ? AND (discontinued_at >= ? OR discontinued_at IS NULL)", @filter_to_date, @filter_from_date).order('date_started, discontinued_at')

    # Load student school years for the filtered dates
    @student_school_years = @student.events_by_student_school_years(@filter_from_date, @filter_to_date)

    # Sort the discipline incidents by occurrance date
    @discipline_incidents = @student.discipline_incidents.sort_by(&:occurred_at).select do |hash|
      hash[:occurred_at] >= @filter_from_date && hash[:occurred_at] <= @filter_to_date
    end

    # This is a hash with the test name as the key and an array of date-sorted student assessment objects as the value
    student_assessments_by_date = @student.student_assessments.order_by_date_taken_asc.includes(:assessment).where(date_taken: @filter_from_date..@filter_to_date)

    @student_assessments = student_assessments_by_date.each_with_object({}) do |student_assessment, hash|
      test = student_assessment.assessment
      test_name = "#{test.family} #{test.subject}"

      hash[test_name] ||= []

      result = case test.family
        when "MCAS" then student_assessment.scale_score
        when "Next Gen MCAS" then student_assessment.scale_score
        else student_assessment.scale_score
      end

      hash[test_name].push([student_assessment.date_taken, result])
    end.sort.to_h

    @star_math_results = @student.star_math_results.order(date_taken: :asc)
                                 .where(date_taken: @filter_from_date..@filter_to_date)
                                 .map { |star| [star.date_taken, star.percentile_rank] }
    @star_reading_results = @student.star_reading_results.order(date_taken: :asc)
                                 .where(date_taken: @filter_from_date..@filter_to_date)
                                 .map { |star| [star.date_taken, star.percentile_rank] }

    @student_assessments['STAR Math Percentile'] = @star_math_results
    @student_assessments['STAR Reading Percentile'] = @star_reading_results

    @dibels_results = @student.dibels_results.order(date_taken: :asc)
                              .where(date_taken: @filter_from_date..@filter_to_date)
                              .map { |dibels| [dibels.date_taken, dibels.benchmark] }

    @student_assessments['DIBELS'] = @dibels_results

    @serialized_data = {
      graph_date_range: {
        filter_from_date: @filter_from_date.to_time,
        filter_to_date: @filter_to_date
      },
      attendance_data: {
        discipline_incidents: @student.discipline_incidents.order(occurred_at: :desc),
        tardies: @student.tardies.order(occurred_at: :desc),
        absences: @student.absences.order(occurred_at: :desc)
      }
    }
  end

  def s3
    if EnvironmentVariable.is_true('USE_PLACEHOLDER_STUDENT_PHOTO')
      @client ||= MockAwsS3.new
    else
      @client ||= Aws::S3::Client.new
    end
  end

  # Add this as a helper method that the ERB template can call
  helper_method :format_date_for_student_report
  def format_date_for_student_report(date)
    date.strftime("%m/%d/%Y")
  end

  def todays_date_for_student_report
    Time.now.in_time_zone('Eastern Time (US & Canada)').to_date
  end
end
