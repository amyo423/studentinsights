# This class is responsible for pulling YAML district config out of the
# filesystem and parsing it into a Ruby hash.

# Deprecated, see PerDistrict
class LoadDistrictConfig

  def initialize(district_key = ENV['DISTRICT_KEY'])
    @district_key = district_key
  end

  def remote_filenames
    load_yml.fetch("remote_filenames")
  end

  private
  def load_yml
    YAML.load(File.open(config_file_path))
  end

  def district_key_to_config_file
    {
      'somerville' => 'config/district_somerville.yml',
      'new_bedford' => 'config/district_new_bedford.yml',
      'bedford' => 'config/district_bedford.yml',
    }
  end

  def config_file_path
    district_key_to_config_file.fetch(@district_key)
  end

end
