require 'hashie'

module Redcap
  class Record < Hashie::Mash

    def self.find id
      client = Redcap.new
      results = client.records records: [id]
      results.first
    end

    def self.all
      client = Redcap.new
      client.records
    end

    def self.select *fields
      client = Redcap.new
      client.records fields: fields
    end

    def self.where condition
      raise "where only accepts a Hash" unless condition.is_a? Hash
      raise "where only accepts a Hash with one key/value pair" unless condition.size == 1
      key, value = condition.first
      client = Redcap.new
      client.records filter: "[#{key}] = #{value}"
    end

    def save
      client = Redcap.new
      client.log = true
      data = Hash[keys.zip(values)]
      client.update [data]
    end

  end
end
