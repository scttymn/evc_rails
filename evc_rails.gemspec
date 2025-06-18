# frozen_string_literal: true

require_relative "lib/evc_rails/version"

Gem::Specification.new do |spec|
  spec.name = "evc_rails"
  spec.version = EvcRails::VERSION
  spec.authors = ["scttymn"]
  spec.email = ["scotty@hey.com"]

  spec.summary = "Enables JSX-like PascalCase component tags in Rails .evc view files."
  spec.description = "A Rails engine that provides a custom template handler for .evc files, allowing developers to use PascalCase ViewComponent tags (e.g., <MyComponent />) directly in their HTML, similar to JSX."

  spec.homepage = "https://github.com/scttymn/evc_rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "actionview"
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "rails", ">= 6.0"
  spec.add_runtime_dependency "view_component", ">= 2.0"
end
