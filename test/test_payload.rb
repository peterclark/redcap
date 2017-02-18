require 'test_helper'

class PayloadTest < Minitest::Test

  def setup
    @redcap = Redcap.new
    @payload = @redcap.send(:build_payload, content: :record, records: [1,2], fields: %w(name age), filter: '[age] > 40')
  end

  def test_payload_is_hash
    assert_instance_of Hash, @payload
  end

  def test_payload_has_token
    assert_equal @payload[:token], @redcap.configuration.token
  end

  def test_payload_has_format
    assert_equal @payload[:format], @redcap.configuration.format
  end

  def test_payload_has_content
    assert_equal @payload[:content], :record
  end

  def test_payload_has_records
    assert_equal @payload['records[0]'], 1
    assert_equal @payload['records[1]'], 2
  end

  def test_payload_has_fields
    assert_equal @payload['fields[0]'], 'name'
    assert_equal @payload['fields[1]'], 'age'
  end

  def test_payload_has_filter
    assert_equal @payload[:filterLogic], '[age] > 40'
  end

end
