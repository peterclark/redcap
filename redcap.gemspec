# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redcap/version'

Gem::Specification.new do |spec|
  spec.name          = "redcap"
  spec.version       = Redcap::VERSION
  spec.authors       = ["Peter Clark"]
  spec.email         = ["peter@5clarks.net"]

  spec.summary       = "A Ruby gem for interacting with the REDCap API"
  spec.description   = "REDCap is a mature, secure web application for building and managing online surveys and databases. The redcap ruby gem allows programmatic access to a REDCap installation via the API using the ruby programming language."
  spec.homepage      = "https://github.com/peterclark/redcap"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'dotenv'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'json'
  spec.add_dependency 'hashie'

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
