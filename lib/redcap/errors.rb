module Redcap
  # Base for everything this gem raises, so callers can rescue Redcap::Error
  # without reaching for RestClient's or JSON's exception hierarchies.
  class Error < StandardError; end

  # Host or token missing before a request was attempted.
  class ConfigurationError < Error; end

  # REDCap was reached but the exchange failed: a non-2xx status, a transport
  # failure, or a body carrying REDCap's own {"error": "..."} shape.
  class ResponseError < Error
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      @status = status
      @body   = body
      super(message)
    end
  end

  # A 2xx response whose body was not the JSON the format asked for.
  class ParseError < Error; end
end
