require 'hashie'

module Redcap
  class Record < Hashie::Mash
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
      self.new response.first
    end

    def self.all
      response = client.records
      response.map { |r| self.new r }
    end

    def self.delete_all ids
      client.delete ids
    end

    def self.ids
      client.records(fields: [:record_id]).map { |r| r['record_id'].to_i }
    end

    def self.count
      ids.count
    end

    def self.pluck field
      return [] unless field
      response = client.records fields: [field]
      response.map { |r| r[field.to_s] }
    end

    def self.find_or_create_by condition
    end

    def self.having condition
    end

    def self.group field
    end

    def self.order condition
    end

    def self.where_not condition
    end

    def self.select *fields
      response = client.records fields: fields
      response.map { |r| self.new r }
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

    def id
      record_id
    end

    def save
      if record_id
        data = Hash[keys.zip(values)]
        client.update [data]
      else
        self.record_id = client.max_id + 1
        data = Hash[keys.zip(values)]
        result = client.create [data]
        result.first == record_id.to_s
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

    def self.client
      @@client = Redcap.new unless @@client
      @@client
    end

    def self.comparison condition, op
      raise "method only accepts a Hash" unless condition.is_a? Hash
      raise "method only accepts a Hash with one key/value pair" unless condition.size == 1
      key, val = condition.first
      response = if(key == :id)
        raise "method only accepts an Array of integers when searching by :id" unless val.is_a? Array
        client.records records: val
      elsif op == '='
        client.records filter: "[#{key}] = '#{val}'"
      elsif %w( > < >= <= ).include? op
        raise "method only accepts an integer or float for the value" unless val.is_a?(Integer) || val.is_a?(Float)
        response = client.records filter: "[#{key}] #{op} #{val}"
      else
        []
      end
      response.map { |r| self.new r }
    end

  end
end
