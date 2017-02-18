module Redcap
  class Configuration
    attr_accessor :host, :token

    def initialize(options = {})
      @host = options[:host]
      @token = options[:token]
    end
  end
end
