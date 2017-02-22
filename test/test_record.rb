require 'test_helper'

class Person < Redcap::Record
end

class RecordTest < Minitest::Test

  def setup
    @person = Person.new
  end

  def test_client_is_redcap_client
    assert_instance_of Redcap::Client, Redcap::Record.client
  end

  def test_client_is_reused
    p2 = Person.new
    assert_equal @person.client.object_id, p2.client.object_id
  end

  ['string', Object, [1], { hash: true }, 9.8].each do |type|
    define_method "test_that_find_rejects_a_#{type.class}" do
      assert_nil Person.find( type )
    end
  end

end
