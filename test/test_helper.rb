# frozen_string_literal: true

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "ostruct"
require "digest"

# Set up minitest reporters
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Load the gem
require_relative "../lib/evc_rails"

# Mock Rails environment for testing
module Rails
  def self.env
    @env ||= OpenStruct.new(development?: false)
  end

  def self.logger
    @logger ||= OpenStruct.new(debug: ->(msg) {}, info: ->(msg) {}, warn: ->(msg) {})
  end
end

# Mock ActionView for testing
module ActionView
  class Template
    def self.registered_template_handler(handler)
      case handler
      when :erb
        Class.new do
          def self.call(template, source)
            "ERB_COMPILED: #{source}"
          end
        end
      else
        nil
      end
    end

    def self.register_template_handler(extension, handler)
      # Mock implementation
    end

    def self.handler_for_extension(extension)
      # Mock implementation
    end
  end
end

# Mock Mime module
module Mime
  class Type
    def self.register(mime_type, symbol, extensions, synonyms)
      # Mock implementation
    end
  end
end
