require 'rails_helper'

describe ProfileController, :type => :controller do
  def create_service(student, educator)
    FactoryBot.create(:service, {
      student: student,
      recorded_by_educator: educator,
      provided_by_educator_name: 'Muraki, Mari'
    })
  end

  def create_event_note(student, educator, params = {})
    FactoryBot.create(:event_note, {
      student: student,
      educator: educator,
    }.merge(params))
  end

  def parse_json(response_body)
    JSON.parse(response_body)
  end

  describe '#json' do
    let!(:school) { FactoryBot.create(:school) }
    let(:educator) { FactoryBot.create(:educator_with_homeroom) }
    let(:other_educator) { FactoryBot.create(:educator, full_name: "Teacher, Louis") }
    let(:student) { FactoryBot.create(:student, school: school) }
    let(:course) { FactoryBot.create(:course, school: school) }
    let(:section) { FactoryBot.create(:section, course: course) }
    let!(:ssa) { FactoryBot.create(:student_section_assignment, student: student, section: section) }
    let!(:esa) { FactoryBot.create(:educator_section_assignment, educator: other_educator, section: section)}
    let(:homeroom) { student.homeroom }

    def make_request(educator, student_id)
      request.env['HTTPS'] = 'on'
      sign_in(educator)
      request.env['HTTP_ACCEPT'] = 'application/json'
      get :json, params: {
        id: student_id,
        format: :json
      }
    end

    describe 'integration test for restricted note redactions' do
      let(:educator) { FactoryBot.create(:educator, :admin, school: school, full_name: "Teacher, Karen") }

      before do
        event_note = FactoryBot.create(:event_note, student: student, text: 'RESTRICTED-one', is_restricted: true)
        FactoryBot.create(:event_note_revision, student: student, text: 'RESTRICTED-two', event_note: event_note)
      end

      it 'redacts correctly' do
        sign_in(educator)
        make_request(educator, student.id)
        expect(response.status).to eq 200
        json_string = JSON.parse(response.body).to_json
        expect(json_string).to include('<redacted>'.to_json)
        expect(json_string).not_to include('RESTRICTED-one')
        expect(json_string).not_to include('RESTRICTED-two')
      end
    end

    describe 'integration test for transition note redactions' do
      let(:educator) { FactoryBot.create(:educator, :admin, school: school, full_name: "Teacher, Karen") }

      before do
        FactoryBot.create(:transition_note, student: student, text: 'RESTRICTED-transition-note', is_restricted: true)
      end

      it 'redacts correctly' do
        sign_in(educator)
        make_request(educator, student.id)
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json.to_json).to include('<redacted>'.to_json)
        expect(json.to_json).not_to include('RESTRICTED-transition-note')
        expect(json['feed']['transition_notes'][0]['text']).to eq '<redacted>'
      end
    end

    describe 'f_and_p_assessments' do
      let!(:pals) { TestPals.create! }
      let!(:f_and_p) do
        FAndPAssessment.create!({
          student_id: pals.healey_kindergarten_student.id,
          benchmark_date: Date.parse('2018-02-22'),
          instructional_level: 'B',
          f_and_p_code: 'WC',
          uploaded_by_educator_id: pals.uri.id
        })
      end

      it 'works' do
        sign_in(pals.uri)
        make_request(pals.uri, pals.healey_kindergarten_student.id)
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['f_and_p_assessments']).to eq([{
          "id"=>f_and_p.id,
          "benchmark_date"=>"2018-02-22",
          "instructional_level"=>"B",
          "f_and_p_code"=>"WC"
        }])
      end
    end

    describe 'ed_plans' do
      def create_ed_plan!(attrs = {})
        EdPlan.create!({
          student_id: pals.healey_kindergarten_student.id,
          sep_status: 1,
          sep_effective_date: Date.parse('2016-09-15'),
          sep_fieldd_006: 'Health disability',
          sep_fieldd_007: 'Rich Districtwide, Laura Principal, Sarah Teacher, Jon Arbuckle (parent)',
          sep_oid: 'test-sep-oid'
        }.merge(attrs))
      end

      let!(:pals) { TestPals.create! }

      it 'only includes active ed plans' do
        create_ed_plan!(sep_status: 4, sep_oid: 'test-sep-discarded')
        create_ed_plan!(sep_status: 2, sep_oid: 'test-sep-previous')
        create_ed_plan!(sep_status: 0, sep_oid: 'test-sep-draft')
        sign_in(pals.uri)
        make_request(pals.uri, pals.healey_kindergarten_student.id)

        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['ed_plans'].size).to eq(0)
      end

      it 'works when enabled' do
        create_ed_plan!
        sign_in(pals.uri)
        make_request(pals.uri, pals.healey_kindergarten_student.id)
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['ed_plans'].size).to eq(1)
        expect(json['ed_plans'].first.keys).to contain_exactly(*[
          'id',
          'sep_oid',
          'student_id',
          'sep_status',
          'sep_effective_date',
          'sep_review_date',
          'sep_last_meeting_date',
          'sep_district_signed_date',
          'sep_parent_signed_date',
          'sep_end_date',
          'sep_last_modified',
          'sep_fieldd_001',
          'sep_fieldd_002',
          'sep_fieldd_003',
          'sep_fieldd_004',
          'sep_fieldd_005',
          'sep_fieldd_006',
          'sep_fieldd_007',
          'sep_fieldd_008',
          'sep_fieldd_009',
          'sep_fieldd_010',
          'sep_fieldd_011',
          'sep_fieldd_012',
          'sep_fieldd_013',
          'sep_fieldd_014',
          'created_at',
          'updated_at',
          'ed_plan_accommodations'
        ])
      end
    end

    describe 'integration test for profile_insights' do
      let!(:educator) { FactoryBot.create(:educator, :admin, school: school, full_name: "Teacher, Karen") }
      let!(:transition_note_text) do
        "What are this student's strengths?\neverything!\n\nWhat is this student's involvement in the school community like?\nreally good\n\nHow does this student relate to their peers?\nnot sure\n\nWho is the student's primary guardian?\nokay\n\nAny additional comments or good things to know about this student?\nnope :)"
      end
      let!(:transition_note) { FactoryBot.create(:transition_note, student: student, text: transition_note_text) }
      let!(:survey) { FactoryBot.create(:student_voice_completed_survey, student: student) }

      it 'returns the right shape' do
        sign_in(educator)
        make_request(educator, student.id)
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['profile_insights'].size).to eq 6
        expect(json['profile_insights'].map {|insight| insight['type'] }).to contain_exactly(*[
          'student_voice_survey_response',
          'student_voice_survey_response',
          'student_voice_survey_response',
          'student_voice_survey_response',
          'student_voice_survey_response',
          'transition_note_strength'
        ])
        expect(json['profile_insights']).to include({
          "type"=>"transition_note_strength",
          "json"=> {
            "strengths_quote_text"=>"everything!",
            "transition_note"=>{
              "id"=>transition_note.id,
              "created_at"=>a_kind_of(String),
              "educator"=>{
                "id"=>transition_note.educator.id,
                "full_name"=>transition_note.educator.full_name,
                "email"=>transition_note.educator.email
              },
              "text"=>transition_note_text
            }
          }
        })
        expect(json['profile_insights']).to include({
          "type"=>"student_voice_survey_response",
          "json"=>{
            "prompt_key"=>"proud",
            "prompt_text"=>"I am proud that I....",
            "survey_response_text"=>survey.proud,
            "student_voice_completed_survey"=>{
              "id"=>survey.id,
              "form_timestamp"=>a_kind_of(String),
              "created_at"=>a_kind_of(String),
              "survey_text"=>a_kind_of(String)
            }
          }
        })
      end
    end

    context 'when educator is not logged in' do
      it 'redirects to sign in page' do
        make_request(educator, student.id)
        expect(response.status).to eq 403
      end
    end

    context 'when educator is logged in' do
      before { sign_in(educator) }

      context 'educator has schoolwide access' do
        let(:educator) { FactoryBot.create(:educator, :admin, school: school, full_name: "Teacher, Karen") }

        it 'is successful' do
          make_request(educator, student.id)
          expect(response).to be_successful
        end

        it 'assigns the student\'s serialized data correctly' do
          make_request(educator, student.id)
          json = parse_json(response.body)
          expect(json.keys).to contain_exactly(*[
            'current_educator',
            'student',
            'feed',
            'chart_data',
            'dibels',
            'f_and_p_assessments',
            'ed_plans',
            'service_types_index',
            'educators_index',
            'profile_insights',
            'grades_reflection_insights',
            'access',
            'teams',
            'latest_iep_document',
            'sections',
            'current_educator_allowed_sections',
            'attendance_data'
          ])
          expect(json['current_educator']['id']).to eq educator['id']
          expect(json['current_educator']['email']).to eq educator['email']
          expect(json['current_educator']['labels']).to eq []
          expect(json['student']["id"]).to eq student.id
          expect(json['student']).not_to have_key('restricted_notes_count')

          expect(json['dibels']).to eq []
          expect(json['f_and_p_assessments']).to eq []
          expect(json['feed']).to eq({
            'event_notes' => [],
            'transition_notes' => [],
            'fall_student_voice_surveys' => [],
            'homework_help_sessions' => [],
            'flattened_forms' => [],
            'services' => {
              'active' => [],
              'discontinued' => []
            },
            'deprecated' => {
              'interventions' => []
            }
          })

          expect(json['service_types_index']).to eq({
            '502' => {'id'=>502, 'name'=>"Attendance Officer"},
            '503' => {'id'=>503, 'name'=>"Attendance Contract"},
            '504' => {'id'=>504, 'name'=>"Behavior Contract"},
            '505' => {'id'=>505, 'name'=>"Counseling, in-house"},
            '506' => {'id'=>506, 'name'=>"Counseling, outside"},
            '507' => {'id'=>507, 'name'=>"Reading intervention"},
            '508' => {'id'=>508, 'name'=>"Math intervention"},
            '509' => {'id'=>509, 'name'=>"SomerSession"},
            '510' => {'id'=>510, 'name'=>"Summer Program for English Language Learners"},
            '511' => {'id'=>511, 'name'=>"Afterschool Tutoring"},
            '512' => {'id'=>512, 'name'=>"Freedom School"},
            '513' => {'id'=>513, 'name'=>"Community Schools"},
            '514' => {'id'=>514, 'name'=>"X-Block"},
            '515' => {'id'=>515, 'name'=>"Calculus Project"},
            '516' => {'id'=>516, 'name'=>"Boston Breakthrough"},
            '517' => {'id'=>517, 'name'=>"Summer Explore"},
            '518' => {'id'=>518, 'name'=>"Focused Math Intervention"}
          })

          expect(json['educators_index']).to include({
            educator.id.to_s => {
              'id'=>educator.id,
              'email'=>educator.email,
              'full_name'=> 'Teacher, Karen'
            }
          })

          expect(json['attendance_data'].keys).to contain_exactly(*[
            'discipline_incidents',
            'tardies',
            'absences'
          ])

          expect(json['sections'].length).to equal(1)
          expect(json['sections'][0]["id"]).to eq(section.id)
          expect(json['sections'][0]["grade_numeric"]).to eq(ssa.grade_numeric.to_s)
          expect(json['sections'][0]["educators"][0]["full_name"]).to eq(other_educator.full_name)
          expect(json['current_educator_allowed_sections']).to include(section.id)
        end

        context 'student has multiple discipline incidents' do
          let!(:student) { FactoryBot.create(:student, school: school) }
          let(:most_recent_school_year) { student.most_recent_school_year }
          let!(:more_recent_incident) {
            FactoryBot.create(
              :discipline_incident,
              student: student,
              occurred_at: Time.now - 1.day
            )
          }

          let!(:less_recent_incident) {
            FactoryBot.create(
              :discipline_incident,
              student: student,
              occurred_at: Time.now - 2.days
            )
          }

          it 'sends the expected shape' do
            make_request(educator, student.id)
            json = parse_json(response.body)
            expect(json['attendance_data']['discipline_incidents'].first.keys).to contain_exactly(*[
              'has_exact_time',
              'id',
              'incident_code',
              'incident_description',
              'incident_location',
              'occurred_at',
              'student'
            ])
          end

          it 'sets the correct order' do
            make_request(educator, student.id)
            json = parse_json(response.body)
            discipline_incident_ids = json['attendance_data']['discipline_incidents'].map {|event| event['id'] }
            expect(discipline_incident_ids).to eq [
              more_recent_incident.id,
              less_recent_incident.id
            ]
          end
        end
      end

      context 'educator has an associated label' do
        let(:educator) { FactoryBot.create(:educator, :admin, school: school) }
        let!(:label) { EducatorLabel.create!(label_key: 'k8_counselor', educator: educator) }

        it 'serializes the educator label correctly' do
          make_request(educator, student.id)
          json = parse_json(response.body)
          expect(json['current_educator']['labels']).to eq ['k8_counselor']
        end
      end

      context 'educator has grade level access' do
        let(:educator) { FactoryBot.create(:educator, grade_level_access: [student.grade], school: school )}

        it 'is successful' do
          make_request(educator, student.id)
          expect(response).to be_successful
        end
      end

      context 'educator has homeroom access' do
        let(:educator) { FactoryBot.create(:educator, school: school) }
        before { homeroom.update(educator: educator, school: school) }

        it 'is successful' do
          make_request(educator, student.id)
          expect(response).to be_successful
        end
      end

      context 'educator has section access' do
        let!(:educator) { FactoryBot.create(:educator, school: school)}
        let!(:course) { FactoryBot.create(:course, school: school)}
        let!(:section) { FactoryBot.create(:section) }
        let!(:esa) { FactoryBot.create(:educator_section_assignment, educator: educator, section: section) }
        let!(:section_student) { FactoryBot.create(:student, school: school) }
        let!(:ssa) { FactoryBot.create(:student_section_assignment, student: section_student, section: section) }

        it 'is successful' do
          make_request(educator, section_student.id)
          expect(response).to be_successful
        end
      end

      context 'educator does not have schoolwide, grade level, or homeroom access' do
        let(:educator) { FactoryBot.create(:educator, school: school) }

        it 'fails' do
          make_request(educator, student.id)
          expect(response.status).to eq 403
        end
      end

      context 'educator has some grade level access but for the wrong grade' do
        let(:student) { FactoryBot.create(:student, grade: '1', school: school) }
        let(:educator) { FactoryBot.create(:educator, grade_level_access: ['KF'], school: school) }

        it 'fails' do
          make_request(educator, student.id)
          expect(response.status).to eq 403
        end
      end

      context 'educator access restricted to SPED students' do
        let(:educator) { FactoryBot.create(:educator,
                                            grade_level_access: ['1'],
                                            restricted_to_sped_students: true,
                                            school: school )
        }

        context 'student in SPED' do
          let(:student) { FactoryBot.create(:student,
                                              grade: '1',
                                              program_assigned: 'Sp Ed',
                                              school: school)
          }

          it 'is successful' do
            make_request(educator, student.id)
            expect(response).to be_successful
          end
        end

        context 'student in Reg Ed' do
          let(:student) { FactoryBot.create(:student,
                                              grade: '1',
                                              program_assigned: 'Reg Ed')
          }

          it 'fails' do
            make_request(educator, student.id)
            expect(response.status).to eq 403
          end
        end

      end

      context 'educator access restricted to ELL students' do
        let(:educator) { FactoryBot.create(:educator,
                                            grade_level_access: ['1'],
                                            restricted_to_english_language_learners: true,
                                            school: school )
        }

        context 'limited English proficiency' do
          let(:student) { FactoryBot.create(:student,
                                              grade: '1',
                                              limited_english_proficiency: 'FLEP',
                                              school: school)
          }

          it 'is successful' do
            make_request(educator, student.id)
            expect(response).to be_successful
          end
        end

        context 'fluent in English' do
          let(:student) { FactoryBot.create(:student,
                                              grade: '1',
                                              limited_english_proficiency: 'Fluent')
          }

          it 'fails' do
            make_request(educator, student.id)
            expect(response.status).to eq 403
          end
        end
      end
    end
  end

  describe '#serialize_student_for_profile' do
    it 'returns a hash with the additional keys that UI code expects' do
      student = FactoryBot.create(:student)
      serialized_student = controller.send(:serialize_student_for_profile, student)
      expect(serialized_student.keys).to include(*[
        'homeroom',
        'absences_count',
        'tardies_count',
        'school_name',
        'homeroom_name',
        'house',
        'counselor',
        'sped_liaison',
        'ell_entry_date',
        'ell_transition_date',
        'discipline_incidents_count'
      ])
    end
  end

  describe '#student_feed' do
    let(:student) { FactoryBot.create(:student) }
    let(:educator) { FactoryBot.create(:educator, :admin) }
    let!(:service) { create_service(student, educator) }
    let!(:event_note) { create_event_note(student, educator) }

    it 'returns expected keys' do
      feed = controller.send(:student_feed, student)
      expect(feed.keys).to contain_exactly(*[
        :event_notes,
        :services,
        :deprecated,
        :transition_notes,
        :fall_student_voice_surveys,
        :homework_help_sessions,
        :flattened_forms
      ])
    end

    it 'returns services' do
      feed = controller.send(:student_feed, student)
      expect(feed[:services].keys).to eq [:active, :discontinued]
      expect(feed[:services][:discontinued].first[:id]).to eq service.id
    end

    it 'returns event notes' do
      feed = controller.send(:student_feed, student)
      event_notes = feed[:event_notes]

      expect(event_notes.size).to eq 1
      expect(event_notes.first[:student_id]).to eq(student.id)
      expect(event_notes.first[:educator_id]).to eq(educator.id)
    end

    context 'after service is discontinued' do
      it 'filters it' do
        feed = controller.send(:student_feed, student)
        expect(feed[:services][:active].size).to eq 0
        expect(feed[:services][:discontinued].first[:id]).to eq service.id
      end
    end

    it 'imported forms' do
      imported_form = ImportedForm.create!({
        student_id: student.id,
        educator_id: educator.id,
        form_key: 'shs_what_i_want_my_teacher_to_know_mid_year',
        form_url: 'https://example.com/foo_form_url',
        form_timestamp: Time.parse('2019-01-28 09:23:43.000000000 +0000'),
        form_json: {
          "What was the high point for you in school this year so far?"=>"A high point has been my grade in Biology since I had to work a lot for it",
          "I am proud that I..."=>"Have good grades in my classes",
          "My best qualities are..."=>"helping others when they don't know how to do homework assignments",
          "My activities and interests outside of school are..."=>"cheering",
          "I get nervous or stressed in school when..."=>"I get a low grade on an assignment that I thought I would do well on",
          "I learn best when my teachers..."=>"show me each step of what I have to do"
        }
      })
      feed = controller.send(:student_feed, student)
      expect(feed[:flattened_forms].size).to eq 1
      expect(feed[:flattened_forms].first[:id]).to eq imported_form.id
      expect(feed[:flattened_forms].first.keys).to contain_exactly(*[
        :id,
        :student_id,
        :educator_id,
        :form_key,
        :form_title,
        :form_timestamp,
        :text,
        :updated_at
      ])
    end
  end
end
