$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'redcap'
require 'redcap/configuration'

gem 'minitest'
require 'minitest/autorun'
require 'vcr'
require 'minitest-vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr'
  c.hook_into :webmock
end

MinitestVcr::Spec.configure!

class Person < Redcap::Record
end
