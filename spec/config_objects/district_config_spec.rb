require 'rails_helper'

RSpec.describe DistrictConfig do

  describe '.get_remote_filenames_from_env' do

    context 'remote file name variables set in ENV' do

      it 'stores the file names from env in class attribute hash' do
        env = {
          'FILENAME_FOR_STUDENTS_IMPORT' => 'best-remote-filename-ever'
        }

        DistrictConfig.get_remote_filenames_from_env(env)

        expect(DistrictConfig.remote_filenames).to eq({
          "FILENAME_FOR_ASSESSMENT_IMPORT" => nil,
          "FILENAME_FOR_ATTENDANCE_IMPORT" => nil,
          "FILENAME_FOR_BEHAVIOR_IMPORT" => nil,
          "FILENAME_FOR_COURSE_SECTION_IMPORT" => nil,
          "FILENAME_FOR_EDUCATORS_IMPORT" => nil,
          "FILENAME_FOR_EDUCATOR_SECTION_ASSIGNMENT_IMPORT" => nil,
          "FILENAME_FOR_STAR_MATH_IMPORT" => nil,
          "FILENAME_FOR_STAR_READING_IMPORT" => nil,
          "FILENAME_FOR_STUDENTS_IMPORT" => "best-remote-filename-ever",
          "FILENAME_FOR_STUDENTS_SECTION_ASSIGNMENT_IMPORT" => nil,
          "FILENAME_FOR_STUDENT_AVERAGES_IMPORT" => nil,
        })
      end

    end

    context 'remote file name variables not set in ENV (i.e. test or development)' do

      it 'stores a hash with empty values' do
        env = {}

        DistrictConfig.get_remote_filenames_from_env(env)

        expect(DistrictConfig.remote_filenames).to eq({
          "FILENAME_FOR_ASSESSMENT_IMPORT" => nil,
          "FILENAME_FOR_ATTENDANCE_IMPORT" => nil,
          "FILENAME_FOR_BEHAVIOR_IMPORT" => nil,
          "FILENAME_FOR_COURSE_SECTION_IMPORT" => nil,
          "FILENAME_FOR_EDUCATORS_IMPORT" => nil,
          "FILENAME_FOR_EDUCATOR_SECTION_ASSIGNMENT_IMPORT" => nil,
          "FILENAME_FOR_STAR_MATH_IMPORT" => nil,
          "FILENAME_FOR_STAR_READING_IMPORT" => nil,
          "FILENAME_FOR_STUDENTS_IMPORT" => nil,
          "FILENAME_FOR_STUDENTS_SECTION_ASSIGNMENT_IMPORT" => nil,
          "FILENAME_FOR_STUDENT_AVERAGES_IMPORT" => nil,
        })
      end
    end

  end

end
