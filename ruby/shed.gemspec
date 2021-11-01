# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shed/version"

Gem::Specification.new do |spec|
  spec.name = "shed"
  spec.version = Shed::VERSION
  spec.authors = ["Christian Gregg"]
  spec.email = ["christian@bissy.io"]
  spec.summary = "A ruby timeout propagator and load-shedder"
  spec.homepage = "https://github.com/CGA1123/shed"
  spec.license = "MIT"
  spec.metadata = {
    "github_repo" => "https://github.com/CGA1123/shed",
    "allowed_push_host" => "https://rubygems.pkg.github.com/CGA1123"
  }

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`
      .split("\x0")
      .reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.5"
end
