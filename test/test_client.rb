require 'test_helper'

# Exercises the HTTP surface. Every assertion checks the request body as well as
# the return value: what the gem sends is the part REDCap actually sees.
class ClientTest < Minitest::Test

  def setup
    super
    @client = redcap_client
  end

  # --- reads -------------------------------------------------------------

  def test_records_posts_record_content
    stub_redcap [{ 'record_id' => '1' }]
    assert_equal [{ 'record_id' => '1' }], @client.records
    assert_equal 'record', last_request_body['content']
    assert_equal RedcapStub::TEST_TOKEN, last_request_body['token']
    assert_equal 'json', last_request_body['format']
  end

  def test_records_sends_no_field_keys_when_none_requested
    stub_redcap []
    @client.records
    assert_empty last_request_body.keys.grep(/\Afields\[/)
  end

  def test_records_sends_indexed_record_ids
    stub_redcap []
    @client.records records: [4, 7]
    assert_equal '4', last_request_body['records[0]']
    assert_equal '7', last_request_body['records[1]']
  end

  def test_records_sends_filter_logic
    stub_redcap []
    @client.records filter: '[age] > 40'
    assert_equal '[age] > 40', last_request_body['filterLogic']
  end

  def test_records_adds_record_id_to_a_field_subset
    stub_redcap []
    @client.records fields: [:first_name]
    assert_equal %w(first_name record_id), field_names
  end

  # Regression: 'record_id' and :record_id both survived the union, so the
  # payload carried the same field twice.
  def test_records_does_not_duplicate_a_string_record_id
    stub_redcap []
    @client.records fields: %w(record_id name)
    assert_equal %w(record_id name), field_names
  end

  def test_records_normalizes_symbol_fields_to_strings
    stub_redcap []
    @client.records fields: [:age]
    assert_equal %w(age record_id), field_names
  end

  def test_metadata_posts_metadata_content
    stub_redcap [{ 'field_name' => 'age' }]
    assert_equal [{ 'field_name' => 'age' }], @client.metadata
    assert_equal 'metadata', last_request_body['content']
  end

  def test_fields_maps_metadata_to_symbols
    stub_redcap [{ 'field_name' => 'record_id' }, { 'field_name' => 'age' }]
    assert_equal %i(record_id age), @client.fields
  end

  def test_project_posts_project_content
    stub_redcap({ 'project_title' => 'Study' })
    assert_equal({ 'project_title' => 'Study' }, @client.project)
    assert_equal 'project', last_request_body['content']
  end

  def test_max_id_returns_the_highest_record_id
    stub_redcap [{ 'record_id' => '2' }, { 'record_id' => '11' }, { 'record_id' => '7' }]
    assert_equal 11, @client.max_id
  end

  def test_max_id_is_zero_when_there_are_no_records
    stub_redcap []
    assert_equal 0, @client.max_id
  end

  # --- writes ------------------------------------------------------------

  def test_create_posts_data_as_json_and_asks_for_ids
    stub_redcap ['5']
    assert_equal ['5'], @client.create([{ record_id: 5, first_name: 'Joe' }])
    assert_equal 'ids', last_request_body['returnContent']
    assert_equal 'normal', last_request_body['overwriteBehavior']
    assert_equal 'flat', last_request_body['type']
    assert_equal [{ 'record_id' => 5, 'first_name' => 'Joe' }], JSON.parse(last_request_body['data'])
  end

  def test_create_wraps_a_bare_hash
    stub_redcap ['5']
    @client.create(record_id: 5)
    assert_equal [{ 'record_id' => 5 }], JSON.parse(last_request_body['data'])
  end

  def test_update_asks_for_a_count
    stub_redcap({ 'count' => 1 })
    assert_equal true, @client.update([{ record_id: 1 }])
    assert_equal 'count', last_request_body['returnContent']
  end

  # Regression: the count was compared against a hard-coded 1, so a successful
  # write of two records reported failure.
  def test_update_of_two_records_succeeds_when_two_are_written
    stub_redcap({ 'count' => 2 })
    assert_equal true, @client.update([{ record_id: 1 }, { record_id: 2 }])
  end

  def test_update_fails_when_the_count_falls_short
    stub_redcap({ 'count' => 1 })
    assert_equal false, @client.update([{ record_id: 1 }, { record_id: 2 }])
  end

  def test_update_wraps_a_bare_hash
    stub_redcap({ 'count' => 1 })
    assert_equal true, @client.update(record_id: 1)
  end

  def test_delete_sends_the_delete_action
    stub_redcap '2'
    assert_equal 2, @client.delete([1, 2])
    assert_equal 'delete', last_request_body['action']
    assert_equal '1', last_request_body['records[0]']
  end

  def test_delete_ignores_a_non_array
    stub_redcap '1'
    assert_nil @client.delete(1)
    assert_equal 0, request_count
  end

  def test_delete_ignores_an_empty_array
    stub_redcap '0'
    assert_nil @client.delete([])
    assert_equal 0, request_count
  end

  # --- logging -----------------------------------------------------------

  def test_logging_is_off_by_default
    stub_redcap []
    @client.logger.define_singleton_method(:debug) { |_| flunk 'logger should be silent' }
    @client.records
  end

  # Regression: the whole payload was interpolated into the log line, and the
  # token is a payload key on every request.
  def test_the_token_is_redacted_from_the_log
    stub_redcap []
    lines = capture_log { @client.records }
    refute lines.any? { |line| line.to_s.include?(RedcapStub::TEST_TOKEN) }, 'token leaked into the log'
    assert lines.any? { |line| line.to_s.include?('[REDACTED]') }
  end

  def test_the_log_still_reports_the_host_and_payload
    stub_redcap []
    lines = capture_log { @client.records }
    assert lines.first.to_s.include?(RedcapStub::TEST_HOST)
    assert lines.first.to_s.include?('record')
  end

  # --- caching -----------------------------------------------------------

  # Regression: flush_cache was a Memoist artifact that only existed when
  # REDCAP_CACHE was set at require time, so the documented call raised.
  # Holds whether or not REDCAP_CACHE was set at require time; the return value
  # differs between the Memoist and no-op implementations, so only the call
  # itself is asserted.
  def test_flush_cache_is_always_defined
    assert_respond_to @client, :flush_cache
    @client.flush_cache
  end

  private

  def field_names
    last_request_body.select { |k, _| k.start_with?('fields[') }.values
  end

  def capture_log
    lines = []
    @client.log = true
    @client.logger.define_singleton_method(:debug) { |message| lines << message }
    yield
    lines
  end

end
