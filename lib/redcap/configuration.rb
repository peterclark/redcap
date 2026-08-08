module Redcap
  class Configuration
    DEFAULT_TIMEOUT = 60

    attr_accessor :host, :token, :format, :timeout, :open_timeout

    # Options win over the environment. `fetch` rather than `||` so an explicit
    # `host: nil` stays nil instead of silently falling back to ENV.
    def initialize(options = {})
      @host         = options.fetch(:host)  { ENV['REDCAP_HOST'] }
      @token        = options.fetch(:token) { ENV['REDCAP_TOKEN'] }
      @format       = options[:format] || :json
      @timeout      = options.fetch(:timeout)      { DEFAULT_TIMEOUT }
      @open_timeout = options.fetch(:open_timeout) { DEFAULT_TIMEOUT }
    end

    def validate!
      raise ConfigurationError, 'Redcap host is not configured. Set REDCAP_HOST or pass :host.' if blank?(host)
      raise ConfigurationError, 'Redcap token is not configured. Set REDCAP_TOKEN or pass :token.' if blank?(token)
      self
    end

    private

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
