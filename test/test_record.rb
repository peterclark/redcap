require 'test_helper'

class RecordTest < Minitest::Test

  def setup
    @record = Redcap::Record.new
  end

  def test_client_is_redcap_client
    assert_instance_of Redcap::Client, Redcap::Record.client
  end

  def test_client_is_reused
    record2 = Redcap::Record.new
    assert_equal @record.client.object_id, record2.client.object_id
  end

end
