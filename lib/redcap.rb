require 'hashie'
require 'json'
require 'rest-client'
require 'logger'
require 'dotenv'
require 'memoist'
require 'redcap/version'
require 'redcap/errors'
require 'redcap/configuration'
require 'redcap/record'

Dotenv.load

module Redcap
  class << self
    # Precedence: explicit options > configuration already established (by an
    # earlier `configure` block or `new`) > the environment.
    #
    # The bare `Redcap.new` deliberately does *not* rebuild the configuration:
    # doing so used to discard whatever a preceding `Redcap.configure` block
    # had set, silently dropping the caller's credentials.
    def new(options = {})
      self.configure = options unless options.empty?
      configuration # establish it now, so ENV is read at construction time
      Redcap::Client.new
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure=(options)
      @configuration = options.nil? ? nil : Configuration.new(options)
    end

    def configure
      return configuration unless block_given?
      yield configuration
      configuration
    end
  end

  class Client
    extend Memoist

    attr_reader :logger
    attr_writer :log

    def initialize
      @logger = Logger.new STDOUT
    end

    def configuration
      Redcap.configuration
    end

    def log?
      @log ||= false
    end

    def log message
      return unless @log
      @logger.debug message
    end

    def project
      post build_payload(content: :project)
    end

    def max_id
      values = records(fields: %w(record_id)) || []
      values.map(&:values).flatten.map(&:to_i).max.to_i
    end

    def fields
      metadata.map { |m| m['field_name'].to_sym }
    end

    def metadata
      post build_payload(content: :metadata)
    end

    def records records: [], fields: [], filter: nil
      # Normalize before the union: mixing 'record_id' and :record_id used to
      # put both into the payload as two separate fields.
      fields = Array(fields).map(&:to_s)
      fields |= ['record_id'] if fields.any?
      post build_payload(content: :record, records: records, fields: fields, filter: filter)
    end

    def update data = []
      rows = data.is_a?(Array) ? data : [data]
      payload = write_payload(rows, returnContent: :count)
      flush_cache
      result = post payload
      result['count'] == rows.size
    end

    def create data = []
      rows = data.is_a?(Array) ? data : [data]
      flush_cache
      post write_payload(rows, returnContent: :ids)
    end

    def delete ids
      return unless ids.is_a?(Array) && ids.any?
      flush_cache
      post build_payload(content: :record, records: ids, action: :delete)
    end

    private

    def write_payload rows, returnContent:
      {
        token: configuration.token,
        format: configuration.format,
        content: :record,
        overwriteBehavior: :normal,
        type: :flat,
        returnContent: returnContent,
        data: rows.to_json
      }
    end

    def build_payload content: nil, records: [], fields: [], filter: nil, action: nil
      payload = {
        token: configuration.token,
        format: configuration.format,
        content: content
      }
      payload[:action] = action if action
      Array(records).each_with_index do |record, index|
        payload["records[#{index}]"] = record
      end
      Array(fields).each_with_index do |field, index|
        payload["fields[#{index}]"] = field
      end
      payload[:filterLogic] = filter if filter
      payload
    end

    def post payload = {}
      configuration.validate!
      log "Redcap POST to #{configuration.host} with #{loggable payload}"
      response = execute payload
      parse(response).tap do |body|
        log 'Response:'
        log body
      end
    end

    def execute payload
      RestClient::Request.execute(
        method: :post,
        url: configuration.host,
        payload: payload,
        timeout: configuration.timeout,
        open_timeout: configuration.open_timeout
      )
    rescue RestClient::ExceptionWithResponse => e
      raise ResponseError.new(
        "Redcap responded with #{e.http_code}",
        status: e.http_code,
        body: e.http_body
      )
    rescue RestClient::Exception, SocketError, SystemCallError, IOError => e
      raise ResponseError.new("Redcap request failed: #{e.message}")
    end

    def parse response
      body = response.body.to_s
      return nil if body.strip.empty?

      data = JSON.parse(body)
      if data.is_a?(Hash) && data['error']
        raise ResponseError.new("Redcap error: #{data['error']}", status: response.code, body: body)
      end
      data
    rescue JSON::ParserError => e
      raise ParseError, "Could not parse Redcap response as JSON: #{e.message}"
    end

    # The token rides in the body of every request, so it must never reach the log.
    def loggable payload
      return payload unless payload.is_a?(Hash) && payload.key?(:token)
      payload.merge(token: '[REDACTED]')
    end

    if ENV['REDCAP_CACHE'] == 'ON'
      memoize :post
    else
      # Memoist defines flush_cache only when something is memoized. Define a
      # no-op so callers need not know whether caching happens to be on.
      # Explicitly public: this sits below `private` in the class body.
      def flush_cache(*) = nil
      public :flush_cache
    end
  end
end
