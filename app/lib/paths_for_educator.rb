# Determine paths for educators, based on what they have authorization to access.
class PathsForEducator
  def initialize(educator)
    @educator = educator
  end

  # Links shown on the navbar, different depending on role
  def navbar_links
    links = {}

    if PerDistrict.new.enabled_class_lists? && ClassListQueries.new(@educator).is_relevant_for_educator?
      links[:classlists] = '/classlists'
    end

    if PerDistrict.new.enabled_high_school_levels? && @educator.labels.include?('should_show_levels_shs_link')
      links[:levels_shs] = '/levels/shs'
    end

    if @educator.districtwide_access?
      links[:district] = '/district'
    end

    if @educator.school.present? && (@educator.schoolwide_access? || @educator.has_access_to_grade_levels?) && !@educator.districtwide_access?
      links[:school] = url_helpers.school_path(@educator.school)
    end

    if @educator.school.present? && @educator.schoolwide_access? && !@educator.districtwide_access?
      links[:absences] = url_helpers.absences_school_path(@educator.school)
      links[:tardies] = url_helpers.tardies_school_path(@educator.school)
      links[:discipline] = url_helpers.discipline_school_path(@educator.school)
    end

    if @educator.school.present? && @educator.school.is_high_school? && @educator.sections.size > 0
      links[:section] = url_helpers.educators_my_sections_path
    end

    if @educator.homeroom.present? && !@educator.homeroom.school.is_high_school?
      links[:homeroom] = url_helpers.homeroom_path(@educator.homeroom)
    end

    links
  end

  private
  def url_helpers
    Rails.application.routes.url_helpers
  end
end
