RSpec.describe 'LdapAuthenticatableTiny' do
  before(:each) do
    @timing = ENV['CONSISTENT_TIMING_FOR_LOGIN_IN_MILLISECONDS']
    ENV['CONSISTENT_TIMING_FOR_LOGIN_IN_MILLISECONDS'] = '500'
  end
  after(:each) { ENV['CONSISTENT_TIMING_FOR_LOGIN_IN_MILLISECONDS'] = @timing }

  def test_strategy
    warden_env = nil
    Devise::Strategies::LdapAuthenticatableTiny.new(warden_env)
  end

  def test_tls_options_text
    '{"tls_foo": "tls_bar"}'
  end

  def test_options(login, password)
    {
      :auth => {
        :method=>:simple,
        :username=>login,
        :password=>password
      },
      :encryption => {
        :method=>:simple_tls,
        :tls_options=>{
          :tls_foo => 'tls_bar'
        }
      },
      :host => 'foo.com',
      :port => 12345
    }
  end

  describe '#authenticate! integration tests across districts, with is_authorized_by_ldap mocked' do
    def mocked_test_strategy(options = {})
      strategy = test_strategy
      allow(strategy).to receive_messages({
        authentication_hash: { login_text: options[:login_text] },
        password: options[:password]
      })
      allow(strategy).to receive(:is_authorized_by_ldap?).with(MockLDAP, options[:ldap_login], options[:password]).and_return options[:is_authorized_by_ldap?]
      strategy
    end

    # just sugar
    def outcomes_after_authenticate!(strategy)
      strategy.authenticate!
      [strategy.result, strategy.message, strategy.user]
    end

    it 'works for Somerville' do
      allow(PerDistrict).to receive(:new).and_return(PerDistrict.new(district_key: PerDistrict::SOMERVILLE))
      pals = TestPals.create!(email_domain: 'k12.somerville.ma.us')
      strategy = mocked_test_strategy({
        login_text: 'uri@k12.somerville.ma.us',
        password: 'supersecure',
        ldap_login: 'uri@k12.somerville.ma.us',
        is_authorized_by_ldap?: true
      })
      expect(outcomes_after_authenticate!(strategy)).to eq [:success, nil, pals.uri]
    end

    it 'works for New Bedford' do
      pals = TestPals.create!(email_domain: 'newbedfordschools.org')
      allow(PerDistrict).to receive(:new).and_return(PerDistrict.new(district_key: PerDistrict::NEW_BEDFORD))
      strategy = mocked_test_strategy({
        login_text: 'uri@newbedfordschools.org',
        password: 'supersecure',
        ldap_login: 'uri@newbedfordschools.org',
        is_authorized_by_ldap?: true
      })
      expect(outcomes_after_authenticate!(strategy)).to eq [:success, nil, pals.uri]
    end

    it 'works for Bedford' do
      pals = TestPals.create!(email_domain: 'bedfordps.org')
      allow(PerDistrict).to receive(:new).and_return(PerDistrict.new(district_key: PerDistrict::BEDFORD))
      strategy = mocked_test_strategy({
        login_text: 'uri',
        password: 'supersecure',
        ldap_login: 'uri@bedford.k12.ma.us',
        is_authorized_by_ldap?: true
      })
      expect(outcomes_after_authenticate!(strategy)).to eq [:success, nil, pals.uri]
    end

    it 'works for demo' do
      pals = TestPals.create!
      allow(PerDistrict).to receive(:new).and_return(PerDistrict.new(district_key: PerDistrict::DEMO))
      strategy = mocked_test_strategy({
        login_text: 'uri@demo.studentinsights.org',
        password: 'supersecure',
        ldap_login: 'uri@demo.studentinsights.org',
        is_authorized_by_ldap?: true
      })
      expect(outcomes_after_authenticate!(strategy)).to eq [:success, nil, pals.uri]
    end
  end

  describe '#authenticate! when methods are mocked' do
    let!(:pals) { TestPals.create! }

    it 'calls fail when email not found' do
      strategy = test_strategy
      allow(strategy).to receive(:authentication_hash) { { login_text: 'foo@demo.studentinsights.org' } }
      strategy.authenticate!

      expect(strategy.result).to eq :failure
      expect(strategy.message).to eq :not_found_in_database
      expect(strategy.user).to eq nil
    end

    it 'calls fail when email found but not is_authorized_by_ldap?' do
      strategy = test_strategy
      allow(strategy).to receive(:authentication_hash) { { login_text: 'uri@demo.studentinsights.org' } }
      allow(strategy).to receive(:password) { 'supersecure' }
      allow(strategy).to receive(:is_authorized_by_ldap?).with(MockLDAP, 'uri@demo.studentinsights.org', 'supersecure').and_return false

      strategy.authenticate!
      expect(strategy.result).to eq :failure
      expect(strategy.message).to eq :invalid
      expect(strategy.user).to eq nil
    end

    it 'reports error and calls fail! when is_authorized_by_ldap? times out' do
      expect(Rollbar).to receive(:error).with(any_args)

      strategy = test_strategy
      allow(strategy).to receive(:authentication_hash) { { login_text: 'uri@demo.studentinsights.org' } }
      allow(strategy).to receive(:password) { 'supersecure' }
      allow(strategy).to receive(:is_authorized_by_ldap?).with(MockLDAP, 'uri@demo.studentinsights.org', 'supersecure').and_raise(Net::LDAP::Error)
      strategy.authenticate!

      expect(strategy.result).to eq :failure
      expect(strategy.message).to eq :error
      expect(strategy.user).to eq nil
    end

    it 'calls success! even when cases are different' do
      strategy = test_strategy
      allow(strategy).to receive(:authentication_hash) { { login_text: 'URI@demo.studentinsights.org' } }
      allow(strategy).to receive(:password) { 'supersecure' }
      allow(strategy).to receive(:is_authorized_by_ldap?).with(MockLDAP, 'uri@demo.studentinsights.org', 'supersecure').and_return true
      strategy.authenticate!

      expect(strategy.result).to eq :success
      expect(strategy.message).to eq nil
      expect(strategy.user).to eq pals.uri
    end

    it 'calls success! when valid Educator and is_authorized_by_ldap?' do
      strategy = test_strategy
      allow(strategy).to receive(:authentication_hash) { { login_text: 'uri@demo.studentinsights.org' } }
      allow(strategy).to receive(:password) { 'supersecure' }
      allow(strategy).to receive(:is_authorized_by_ldap?).with(MockLDAP, 'uri@demo.studentinsights.org', 'supersecure').and_return true
      strategy.authenticate!

      expect(strategy.result).to eq :success
      expect(strategy.message).to eq nil
      expect(strategy.user).to eq pals.uri
    end
  end

  describe '#ldap_options_for' do
    before do
      allow(ENV).to receive(:[]).with('DISTRICT_LDAP_HOST').and_return('foo.com')
      allow(ENV).to receive(:[]).with('DISTRICT_LDAP_PORT').and_return('12345.com')
      allow(ENV).to receive(:[]).with('DISTRICT_LDAP_ENCRYPTION_TLS_OPTIONS_JSON').and_return(test_tls_options_text)
      allow(ENV).to receive(:[]).with('DISTRICT_LDAP_TIMEOUT_IN_SECONDS').and_return('30')
   end

    it 'respects environment variables' do
      strategy = test_strategy
      expect(strategy.send(:ldap_options_for, 'foo', 'bar')).to eq({
        :auth => {
          :method=>:simple,
          :username=>"foo",
          :password=>"bar"
        },
        :connect_timeout => 30,
        :encryption => {
          :method=>:simple_tls,
          :tls_options=>{
            :tls_foo => 'tls_bar'
          }
        },
        :host => 'foo.com',
        :port => 12345
      })
    end
  end

  describe '#is_authorized_by_ldap? calls Net::LDAP correctly' do
    let!(:pals) { TestPals.create! }

    it 'returns false and locks for invalid credentials' do
      strategy = test_strategy

      args = [
        :is_authorized_by_ldap?,
        MockLDAP,
        'uri@demo.studentinsights.org',
        'bar'
      ]

      expect(strategy.send(*args)).to eq false
    end

    it 'returns true for valid credentials' do
      strategy = test_strategy

      args = [
        :is_authorized_by_ldap?,
        MockLDAP,
        'uri@demo.studentinsights.org',
        'demo-password'
      ]

      expect(strategy.send(*args)).to eq true
    end

    it 'returns false for nil password regardless' do
      strategy = test_strategy

      args = [
        :is_authorized_by_ldap?,
        MockLDAP,
        'uri@demo.studentinsights.org',
        nil
      ]

      expect(strategy.send(*args)).to eq false
    end

    it 'returns false for empty password regardless' do
      strategy = test_strategy

      args = [
        :is_authorized_by_ldap?,
        MockLDAP,
        'uri@demo.studentinsights.org',
        ''
      ]

      expect(strategy.send(*args)).to eq false
    end
  end
end
