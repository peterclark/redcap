require 'test_helper'

class Person < Redcap::Record
end

class RecordTest < Minitest::Test

  def setup
    super
    configure_redcap
    @person = Person.new
  end

  # --- client wiring -----------------------------------------------------

  def test_client_is_redcap_client
    assert_instance_of Redcap::Client, Redcap::Record.client
  end

  def test_client_is_reused
    assert_same Person.client, Person.new.client
  end

  def test_reset_client_drops_the_memoized_client
    first = Person.client
    Person.reset_client!
    refute_same first, Person.client
  end

  # --- find --------------------------------------------------------------

  ['string', Object, [1], { hash: true }, 9.8].each do |type|
    define_method "test_that_find_rejects_a_#{type.class}" do
      assert_nil Person.find(type)
    end
  end

  def test_find_returns_a_record
    stub_redcap [{ 'record_id' => '3', 'first_name' => 'Bob' }]
    person = Person.find(3)
    assert_instance_of Person, person
    assert_equal 'Bob', person.first_name
    assert_equal '3', last_request_body['records[0]']
  end

  # Regression: Mash.new(nil) is a truthy empty record, so `if Person.find(id)`
  # never guarded anything.
  def test_find_returns_nil_when_nothing_matches
    stub_redcap []
    assert_nil Person.find(999)
  end

  # --- collections -------------------------------------------------------

  def test_all_instantiates_every_record
    stub_redcap [{ 'record_id' => '1' }, { 'record_id' => '2' }]
    people = Person.all
    assert_equal 2, people.size
    assert(people.all? { |p| p.is_a?(Person) })
  end

  def test_ids_returns_integers
    stub_redcap [{ 'record_id' => '1' }, { 'record_id' => '10' }]
    assert_equal [1, 10], Person.ids
  end

  def test_count_counts_ids
    stub_redcap [{ 'record_id' => '1' }, { 'record_id' => '2' }, { 'record_id' => '3' }]
    assert_equal 3, Person.count
  end

  def test_pluck_returns_bare_values
    stub_redcap [{ 'first_name' => 'Joe' }, { 'first_name' => 'Sal' }]
    assert_equal %w(Joe Sal), Person.pluck(:first_name)
  end

  def test_pluck_without_a_field_returns_empty
    stub_redcap []
    assert_equal [], Person.pluck(nil)
    assert_equal 0, request_count
  end

  def test_select_requests_a_field_subset
    stub_redcap [{ 'record_id' => '1', 'age' => '40' }]
    people = Person.select(:first_name, :age)
    assert_instance_of Person, people.first
    assert_includes last_request_body.values, 'first_name'
  end

  def test_id_reads_record_id
    assert_equal 7, Person.new('record_id' => 7).id
  end

  # --- queries -----------------------------------------------------------

  def test_where_builds_an_equality_filter
    stub_redcap []
    Person.where first_name: 'Bob'
    assert_equal "[first_name] = 'Bob'", last_request_body['filterLogic']
  end

  # Regression: an unescaped quote closed the string literal early and the rest
  # of the value was read as filter syntax.
  def test_where_escapes_single_quotes_in_the_value
    stub_redcap []
    Person.where name: "x' or '1'='1"
    assert_equal "[name] = 'x\\' or \\'1\\'=\\'1'", last_request_body['filterLogic']
  end

  def test_where_escapes_backslashes_in_the_value
    stub_redcap []
    Person.where name: 'back\\slash'
    assert_equal "[name] = 'back\\\\slash'", last_request_body['filterLogic']
  end

  def test_where_rejects_a_field_name_that_is_not_an_identifier
    stub_redcap []
    assert_raises(ArgumentError) { Person.where "age] = 1 or [1" => 2 }
    assert_equal 0, request_count
  end

  def test_where_by_id_fetches_records_directly
    stub_redcap [{ 'record_id' => '1' }, { 'record_id' => '4' }]
    Person.where id: [1, 4]
    assert_equal '1', last_request_body['records[0]']
    assert_equal '4', last_request_body['records[1]']
    refute last_request_body.key?('filterLogic')
  end

  def test_where_by_id_requires_an_array
    assert_raises(ArgumentError) { Person.where id: 1 }
  end

  { gt: '>', lt: '<', gte: '>=', lte: '<=' }.each do |method, operator|
    define_method "test_#{method}_builds_a_#{method}_filter" do
      stub_redcap []
      Person.public_send(method, age: 40)
      assert_equal "[age] #{operator} 40", last_request_body['filterLogic']
    end

    define_method "test_#{method}_rejects_a_non_numeric_value" do
      assert_raises(ArgumentError) { Person.public_send(method, age: 'forty') }
    end
  end

  def test_comparisons_accept_a_float
    stub_redcap []
    Person.gt age: 40.5
    assert_equal '[age] > 40.5', last_request_body['filterLogic']
  end

  def test_comparison_requires_a_hash
    assert_raises(ArgumentError) { Person.where 'first_name' }
  end

  def test_comparison_requires_exactly_one_pair
    assert_raises(ArgumentError) { Person.where first_name: 'Bob', age: 40 }
  end

  # --- persistence -------------------------------------------------------

  def test_save_updates_an_existing_record
    stub_redcap({ 'count' => 1 })
    person = Person.new('record_id' => 3, 'first_name' => 'Bob')
    assert_equal true, person.save
    assert_equal 'count', last_request_body['returnContent']
    assert_equal [{ 'record_id' => 3, 'first_name' => 'Bob' }], JSON.parse(last_request_body['data'])
  end

  def test_save_creates_a_new_record_with_the_next_id
    stub_redcap_sequence [{ 'record_id' => '7' }], ['8']
    person = Person.new('first_name' => 'Joe')
    assert_equal true, person.save
    assert_equal 8, person.record_id
    assert_equal 'ids', last_request_body['returnContent']
  end

  def test_save_reports_failure_when_the_created_id_does_not_match
    stub_redcap_sequence [{ 'record_id' => '7' }], ['99']
    assert_equal false, Person.new('first_name' => 'Joe').save
  end

  def test_destroy_deletes_by_record_id
    stub_redcap '1'
    assert_equal 1, Person.new('record_id' => 3).destroy
    assert_equal 'delete', last_request_body['action']
    assert_equal '3', last_request_body['records[0]']
  end

  def test_destroy_without_a_record_id_does_nothing
    stub_redcap '1'
    assert_nil Person.new.destroy
    assert_equal 0, request_count
  end

  def test_delete_all_deletes_the_given_ids
    stub_redcap '2'
    assert_equal 2, Person.delete_all([1, 2])
    assert_equal 'delete', last_request_body['action']
  end

  # --- metadata ----------------------------------------------------------

  def test_metadata_delegates_to_the_client
    stub_redcap [{ 'field_name' => 'age' }]
    assert_equal [{ 'field_name' => 'age' }], Person.metadata
  end

  def test_fields_delegates_to_the_client
    stub_redcap [{ 'field_name' => 'age' }]
    assert_equal [:age], Person.fields
  end

  # --- unimplemented -----------------------------------------------------

  # Regression: these returned nil silently, so `People.order(:age)` looked
  # like it worked.
  Redcap::Record::NOT_IMPLEMENTED.each do |name|
    define_method "test_#{name}_raises_not_implemented" do
      assert_raises(NotImplementedError) { Person.public_send(name, age: 1) }
    end
  end

  # --- visibility --------------------------------------------------------

  def test_client_is_public
    assert_respond_to Redcap::Record, :client
  end

  # Regression: `private` does not apply to `def self.` methods, so the query
  # internals were public despite the apparent intent.
  def test_query_internals_are_private
    refute_respond_to Redcap::Record, :comparison
    refute_respond_to Redcap::Record, :escape
    assert_raises(NoMethodError) { Redcap::Record.comparison({ a: 1 }, '=') }
  end

end
