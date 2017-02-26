module Redcap
  class Configuration
    attr_accessor :host, :token, :format

    def initialize(options = {})
      @host   = options[:host]
      @token  = options[:token]
      @format = options[:format] || :json
    end
  end
end
