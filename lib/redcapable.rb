module Redcapable

  # extend the including class with ClassMethods
  def self.included(klass)
    klass.extend ClassMethods
    # create attribute accessors for all redcap fields.
    klass.class_eval do
      fields = Redcap.new.fields
      attr_accessor *(fields)
      const_set :REDCAP_FIELDS, fields
      def initialize hash={}
        hash.each do |k,v|
          instance_variable_set "@#{k}", v
        end if hash && hash.is_a?(Hash)
      end
    end
  end

  # instance methods
  def id
    record_id
  end

  def save
    data = {}
    self.class::REDCAP_FIELDS.each do |field|
      data[field] = send(field.to_sym)
    end
    if record_id
      client.update [data]
    else
      self.record_id = client.max_id + 1
      result = client.create [data]
      result.first == record_id.to_s
    end
  end

  def client
    self.class.client
  end

  # class methods
  module ClassMethods
    @client = nil

    def find id
      return unless id.is_a? Integer
      response = client.records records: [id]
      new response.first
    end

    def all
      response = client.records
      response.map { |r| new r }
    end

    def ids
      client.records(fields: [:record_id]).map { |r| r['record_id'].to_i }
    end

    def count
      ids.count
    end

    def pluck field
      return [] unless field
      response = client.records fields: [field]
      response.map { |r| r[field.to_s] }
    end

    def select *fields
      response = client.records fields: fields
      response.map { |r| new r }
    end

    def where condition
      comparison condition, '='
    end

    def gt condition
      comparison condition, '>'
    end

    def lt condition
      comparison condition, '<'
    end

    def gte condition
      comparison condition, '>='
    end

    def lte condition
      comparison condition, '<='
    end

    def client
      @client = Redcap.new unless @client
      @client
    end

    private

    def comparison condition, op
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
      response.map { |r| new r }
    end
  end
end
