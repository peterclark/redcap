require 'uri'
require 'json'

# Helpers for stubbing the single REDCap endpoint.
#
# REDCap exposes one URL and selects the operation from the POST body, so every
# stub here targets the same address. Because the interesting part of most calls
# is *what the gem sent*, each stub records the decoded request body; assert on
# `last_request_body` as well as on the return value.
module RedcapStub
  TEST_HOST  = 'http://redcap.test/api/'.freeze
  TEST_TOKEN = 'TESTTOKEN'.freeze

  # A client pointed at the stubbed endpoint.
  def redcap_client(options = {})
    Redcap.new({ host: TEST_HOST, token: TEST_TOKEN }.merge(options))
  end

  # Point Record subclasses at the stubbed endpoint too.
  def configure_redcap(options = {})
    Redcap.configure = { host: TEST_HOST, token: TEST_TOKEN }.merge(options)
  end

  # `response` may be a Hash/Array (serialized to JSON) or a raw String, which
  # is sent verbatim so tests can exercise malformed and non-JSON bodies.
  def stub_redcap(response = [], status: 200, headers: {})
    body = response.is_a?(String) ? response : response.to_json
    requests = (@redcap_requests ||= [])

    stub_request(:post, TEST_HOST).to_return do |request|
      requests << decode_form(request.body)
      {
        status: status,
        body: body,
        headers: { 'Content-Type' => 'application/json' }.merge(headers)
      }
    end
  end

  # Successive responses for calls that make more than one request (`save` on a
  # new record fetches max_id before creating). Each argument is one complete
  # response body; the last one repeats once the queue is exhausted.
  def stub_redcap_sequence(*responses)
    requests = (@redcap_requests ||= [])
    queue = responses.dup

    stub_request(:post, TEST_HOST).to_return do |request|
      requests << decode_form(request.body)
      response = queue.size > 1 ? queue.shift : queue.first
      body = response.is_a?(String) ? response : response.to_json
      { status: 200, body: body, headers: { 'Content-Type' => 'application/json' } }
    end
  end

  # Temporarily set environment variables for the duration of the block.
  def with_env(vars)
    previous = {}
    vars.each { |key, value| previous[key] = ENV[key]; ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  # Every request body captured so far, decoded, oldest first.
  def redcap_requests
    @redcap_requests ||= []
  end

  def last_request_body
    redcap_requests.last
  end

  def request_count
    redcap_requests.size
  end

  # RestClient form-encodes a Hash payload; decode it back for assertions.
  def decode_form(body)
    URI.decode_www_form(body.to_s).to_h
  end
end
