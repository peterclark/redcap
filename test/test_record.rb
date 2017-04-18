require 'test_helper'

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

  describe 'find' do
    before do
      VCR.use_cassette 'find' do
        @person = Person.find 1
      end
    end

    it 'finds a record' do
      assert_instance_of Person, @person
    end
    it 'has an id' do
      assert_equal @person.id, '1'
    end
    it 'has a record_id' do
      assert_equal @person.record_id, '1'
    end
  end

  describe 'all', vcr: true do
    before do
      VCR.use_cassette 'all' do
        @people = Person.all
      end
    end

    it 'returns an Array' do
      assert_instance_of Array, @people
    end
    it 'contains Persons' do
      assert_instance_of Person, @people.first
    end
  end

end
