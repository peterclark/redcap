require 'test_helper'

class RedcapTest < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::Redcap::VERSION
  end

  def test_that_it_has_a_configuration
    assert_instance_of Redcap::Configuration, Redcap.new.configuration
  end

  def test_that_host_initializes_from_env
    with_env('REDCAP_HOST' => 'http://from-env.test') do
      assert_equal 'http://from-env.test', Redcap.new.configuration.host
    end
  end

  def test_that_token_initializes_from_env
    with_env('REDCAP_TOKEN' => 'ENVTOKEN') do
      assert_equal 'ENVTOKEN', Redcap.new.configuration.token
    end
  end

  def test_that_format_defaults_to_json
    assert_equal :json, Redcap.new.configuration.format
  end

  def test_it_accepts_a_block
    Redcap.configure do |c|
      c.host = 'http://www.google.com'
      c.token = 1234
    end
    assert_equal 'http://www.google.com', Redcap.configuration.host
    assert_equal 1234, Redcap.configuration.token
  end

  # Regression: `Redcap.new` used to rebuild the configuration from ENV,
  # silently discarding everything the block had just set.
  def test_block_configuration_survives_a_bare_new
    Redcap.configure do |c|
      c.host = 'http://example.com'
      c.token = 'SECRET'
    end
    client = Redcap.new
    assert_equal 'http://example.com', client.configuration.host
    assert_equal 'SECRET', client.configuration.token
  end

  def test_bare_new_does_not_clobber_configuration_with_empty_env
    with_env('REDCAP_HOST' => nil, 'REDCAP_TOKEN' => nil) do
      Redcap.new host: 'http://first.test', token: 'FIRST'
      assert_equal 'http://first.test', Redcap.new.configuration.host
    end
  end

  def test_it_accepts_a_hash
    redcap = Redcap.new host: 'http://www.yahoo.com', token: 5678
    assert_equal 'http://www.yahoo.com', redcap.configuration.host
    assert_equal 5678, redcap.configuration.token
  end

  def test_explicit_options_win_over_env
    with_env('REDCAP_HOST' => 'http://from-env.test') do
      assert_equal 'http://explicit.test', Redcap.new(host: 'http://explicit.test').configuration.host
    end
  end

  def test_explicit_options_replace_earlier_configuration
    Redcap.new host: 'http://first.test', token: 'FIRST'
    assert_equal 'http://second.test', Redcap.new(host: 'http://second.test').configuration.host
  end

  # Regression: reading the configuration via `configure` raised LocalJumpError.
  def test_configure_without_a_block_returns_the_configuration
    assert_instance_of Redcap::Configuration, Redcap.configure
    assert_same Redcap.configuration, Redcap.configure
  end

  def test_assigning_nil_resets_the_configuration
    Redcap.new host: 'http://first.test', token: 'FIRST'
    Redcap.configure = nil
    with_env('REDCAP_HOST' => nil) do
      assert_nil Redcap.configuration.host
    end
  end

  def test_it_has_a_logger
    assert_instance_of Logger, Redcap.new.logger
  end

  def test_log_is_off
    assert_equal false, Redcap.new.log?
  end

  def test_log_can_turn_on
    redcap = Redcap.new
    redcap.log = true
    assert_equal true, redcap.log?
  end

end
