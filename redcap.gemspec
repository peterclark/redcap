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

  spec.required_ruby_version = ">= 3.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|\.github)/}) || f.match(%r{^(PLAN|CLAUDE)\.md$})
  end
  # bin/ holds development scripts (console, setup); exe/ would hold shipped
  # executables. This gem ships none, so `executables` is intentionally empty.
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'dotenv'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'json'
  spec.add_dependency 'hashie', ">= 3.4", "< 6"
  spec.add_dependency 'memoist'

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "awesome_print"
end
