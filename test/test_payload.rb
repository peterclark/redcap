require 'test_helper'

# The payload builder assembles REDCap's wire format directly; these assertions
# pin the indexed-key encoding that the rest of the gem depends on.
class PayloadTest < Minitest::Test

  def setup
    super
    @redcap = redcap_client
    @payload = build content: :record, records: [1, 2], fields: %w(name age), filter: '[age] > 40'
  end

  def build(**kwargs)
    @redcap.send(:build_payload, **kwargs)
  end

  def test_payload_is_hash
    assert_instance_of Hash, @payload
  end

  def test_payload_has_token
    assert_equal RedcapStub::TEST_TOKEN, @payload[:token]
  end

  def test_payload_has_format
    assert_equal :json, @payload[:format]
  end

  def test_payload_has_content
    assert_equal :record, @payload[:content]
  end

  def test_payload_has_records
    assert_equal 1, @payload['records[0]']
    assert_equal 2, @payload['records[1]']
  end

  def test_payload_has_fields
    assert_equal 'name', @payload['fields[0]']
    assert_equal 'age', @payload['fields[1]']
  end

  def test_payload_has_filter
    assert_equal '[age] > 40', @payload[:filterLogic]
  end

  def test_payload_omits_filter_when_absent
    refute build(content: :record).key?(:filterLogic)
  end

  def test_payload_omits_action_when_absent
    refute build(content: :record).key?(:action)
  end

  def test_payload_includes_action_when_given
    assert_equal :delete, build(content: :record, action: :delete)[:action]
  end

  def test_payload_has_no_indexed_keys_when_records_and_fields_are_empty
    payload = build(content: :project)
    assert_empty payload.keys.grep(/\A(records|fields)\[/)
  end

  def test_payload_tolerates_nil_records_and_fields
    payload = build(content: :record, records: nil, fields: nil)
    assert_empty payload.keys.grep(/\A(records|fields)\[/)
  end

end
