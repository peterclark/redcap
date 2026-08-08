$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'redcap'
require 'redcap/configuration'

gem 'minitest'
require 'minitest/autorun'
require 'webmock/minitest'

# Nothing in this suite should reach the network. An unstubbed request fails
# loudly rather than escaping to a real REDCap instance.
WebMock.disable_net_connect!

require 'support/redcap_stub'

class Minitest::Test
  include RedcapStub

  # Both the configuration and Record's client are process-global, and Minitest
  # randomizes order, so every test starts from a clean slate rather than
  # inheriting whatever ran before it.
  def setup
    reset_redcap!
  end

  def teardown
    reset_redcap!
  end

  def reset_redcap!
    Redcap.configure = nil
    Redcap::Record.reset_client!
  end
end
