require 'test_helper'

# Error paths had no defined behavior before: RestClient and JSON exceptions
# leaked straight through the abstraction. These pin the contract.
class ErrorsTest < Minitest::Test

  def test_a_missing_host_raises_configuration_error
    client = Redcap.new host: nil, token: 'TOKEN'
    error = assert_raises(Redcap::ConfigurationError) { client.records }
    assert_match(/host/i, error.message)
  end

  def test_a_missing_token_raises_configuration_error
    client = Redcap.new host: RedcapStub::TEST_HOST, token: nil
    error = assert_raises(Redcap::ConfigurationError) { client.records }
    assert_match(/token/i, error.message)
  end

  def test_a_blank_host_raises_configuration_error
    client = Redcap.new host: '   ', token: 'TOKEN'
    assert_raises(Redcap::ConfigurationError) { client.records }
  end

  def test_configuration_errors_are_raised_before_any_request
    stub_redcap []
    client = Redcap.new host: nil, token: nil
    assert_raises(Redcap::ConfigurationError) { client.records }
    assert_equal 0, request_count
  end

  def test_a_server_error_raises_response_error_carrying_the_status
    stub_redcap 'upstream exploded', status: 500
    error = assert_raises(Redcap::ResponseError) { redcap_client.records }
    assert_equal 500, error.status
    assert_equal 'upstream exploded', error.body
  end

  def test_a_not_found_raises_response_error
    stub_redcap 'nope', status: 404
    assert_raises(Redcap::ResponseError) { redcap_client.records }
  end

  def test_a_forbidden_response_raises_response_error
    stub_redcap 'bad token', status: 403
    error = assert_raises(Redcap::ResponseError) { redcap_client.records }
    assert_equal 403, error.status
  end

  # REDCap answers some failures with 200 and an error-shaped body.
  def test_an_error_shaped_body_raises_response_error
    stub_redcap({ 'error' => 'You do not have permission' })
    error = assert_raises(Redcap::ResponseError) { redcap_client.records }
    assert_match(/permission/, error.message)
  end

  def test_a_non_json_body_raises_parse_error
    stub_redcap '<html>gateway timeout</html>'
    assert_raises(Redcap::ParseError) { redcap_client.records }
  end

  def test_truncated_json_raises_parse_error
    stub_redcap '[{"record_id":'
    assert_raises(Redcap::ParseError) { redcap_client.records }
  end

  def test_an_empty_body_returns_nil
    stub_redcap ''
    assert_nil redcap_client.records
  end

  def test_a_bare_numeric_body_is_parsed
    stub_redcap '2'
    assert_equal 2, redcap_client.delete([1, 2])
  end

  def test_every_error_descends_from_redcap_error
    [Redcap::ConfigurationError, Redcap::ResponseError, Redcap::ParseError].each do |klass|
      assert_operator klass, :<, Redcap::Error
    end
  end

end
