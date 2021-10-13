# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shed/version"

Gem::Specification.new do |spec|
  spec.name = "shed"
  spec.version = Shed::VERSION
  spec.authors = ["Christian Gregg"]
  spec.email = ["christian@bissy.io"]
  spec.summary = "A ruby wrapper for Slack's Block Kit"
  spec.homepage = "https://github.com/CGA1123/shed"
  spec.license = "MIT"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`
      .split("\x0")
      .reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.5"
  spec.add_runtime_dependency "faraday", "~> 1"
end
