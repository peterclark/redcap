require 'hashie'

module Redcap
  class Record < Hashie::Mash
    # REDCap field names are alphanumeric identifiers; anything else is a sign
    # the caller is building a filter expression by hand.
    FIELD_NAME = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

    NOT_IMPLEMENTED = %i(find_or_create_by having group order where_not).freeze

    @@client = nil

    def self.metadata
      client.metadata
    end

    def self.fields
      client.fields
    end

    def self.find id
      return unless id.is_a? Integer
      response = client.records records: [id]
      return if response.nil? || response.empty?
      new response.first
    end

    def self.all
      instantiate client.records
    end

    def self.delete_all ids
      client.delete ids
    end

    def self.ids
      (client.records(fields: [:record_id]) || []).map { |r| r['record_id'].to_i }
    end

    def self.count
      ids.count
    end

    def self.pluck field
      return [] unless field
      response = client.records fields: [field]
      (response || []).map { |r| r[field.to_s] }
    end

    NOT_IMPLEMENTED.each do |name|
      define_singleton_method(name) do |*|
        raise NotImplementedError, "Redcap::Record.#{name} is not implemented yet"
      end
    end

    def self.select *fields
      instantiate client.records(fields: fields)
    end

    def self.where condition
      comparison condition, '='
    end

    def self.gt condition
      comparison condition, '>'
    end

    def self.lt condition
      comparison condition, '<'
    end

    def self.gte condition
      comparison condition, '>='
    end

    def self.lte condition
      comparison condition, '<='
    end

    # Public API: the README documents `People.client.log = true`.
    def self.client
      @@client ||= Redcap.new
    end

    # Drop the memoized client so a later call picks up new configuration.
    def self.reset_client!
      @@client = nil
    end

    def id
      record_id
    end

    def save
      if record_id
        client.update [to_data]
      else
        self.record_id = client.max_id + 1
        result = client.create [to_data]
        Array(result).first.to_s == record_id.to_s
      end
    end

    def destroy
      return unless record_id
      client.delete [record_id]
    end

    def client
      self.class.client
    end

    private

    def to_data
      Hash[keys.zip(values)]
    end

    def self.instantiate response
      (response || []).map { |r| new r }
    end

    def self.comparison condition, op
      raise ArgumentError, 'method only accepts a Hash' unless condition.is_a? Hash
      raise ArgumentError, 'method only accepts a Hash with one key/value pair' unless condition.size == 1

      key, val = condition.first
      response =
        if key.to_s == 'id'
          raise ArgumentError, 'method only accepts an Array of integers when searching by :id' unless val.is_a? Array
          client.records records: val
        elsif op == '='
          client.records filter: "[#{field_name! key}] = '#{escape val}'"
        elsif %w( > < >= <= ).include? op
          raise ArgumentError, 'method only accepts an integer or float for the value' unless val.is_a?(Integer) || val.is_a?(Float)
          client.records filter: "[#{field_name! key}] #{op} #{val}"
        else
          []
        end
      instantiate response
    end

    # Values are interpolated into REDCap's filterLogic, where string literals
    # are single-quoted. Without escaping, a value containing a quote closes the
    # literal early and the rest is read as filter syntax.
    def self.escape value
      value.to_s.gsub(/[\\']/) { |char| "\\#{char}" }
    end

    def self.field_name! key
      name = key.to_s
      raise ArgumentError, "#{key.inspect} is not a valid field name" unless name.match?(FIELD_NAME)
      name
    end

    private_class_method :instantiate, :comparison, :escape, :field_name!
  end
end
