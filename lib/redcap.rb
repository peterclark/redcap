
require 'redcap/version'
require 'redcap/configuration'
require 'json'
require 'rest-client'
require 'logger'
require 'hashie'
require 'dotenv'
Dotenv.load

module Redcap
  attr_reader :configuration

  class << self
    def new(options = {})
      if options.empty? && ENV
        options[:host] = ENV['REDCAP_HOST']
        options[:token] = ENV['REDCAP_TOKEN']
      end
      self.configure = options
      Redcap::Client.new
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure=(options)
      if options.nil?
        @configuration = nil
      else
        @configuration = Configuration.new(options)
      end
    end

    def configure
      yield configuration
      configuration
    end
  end

  class Client
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

    def records
      response = post configuration.host,
        token: configuration.token,
        format: configuration.format,
        content: :record
      response.map { |record| Hashie::Mash.new record }
    end

    private

    def post(url, payload = {})
      log "Redcap POST to #{url} with #{payload}"
      response = RestClient.post url, payload
      response = JSON.parse(response)
      log 'Response:'
      log response
      response
    end
  end

end
