# frozen_string_literal: true

require_relative "lib/sendkit/version"

Gem::Specification.new do |spec|
  spec.name = "sendkit"
  spec.version = SendKit::VERSION
  spec.authors = ["SendKit"]
  spec.email = ["support@sendkit.com"]

  spec.summary = "Ruby SDK for the SendKit email API"
  spec.description = "Official Ruby SDK for the SendKit email API. Send transactional emails with a simple, zero-dependency client."
  spec.homepage = "https://github.com/sendkitdev/sendkit-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]
end
