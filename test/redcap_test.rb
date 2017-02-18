require 'test_helper'

class RedcapTest < Minitest::Test

  def setup
    @redcap = Redcap.new
  end

  def test_that_it_has_a_version_number
    refute_nil ::Redcap::VERSION
  end

  def test_that_it_has_a_configuration
    assert_instance_of Redcap::Configuration, @redcap.configuration
  end

  def test_that_host_initializes_from_env
    assert_equal @redcap.configuration.host, ENV['REDCAP_HOST']
  end

  def test_that_token_initializes_from_env
    assert_equal @redcap.configuration.token, ENV['REDCAP_TOKEN']
  end

  def test_that_format_defaults_to_json
    assert_equal @redcap.configuration.format, :json
  end
end
