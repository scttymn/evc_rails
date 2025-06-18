# frozen_string_literal: true

require "rails"
require "active_support/lazy_load_hooks"
require_relative "evc_rails/version"
require_relative "evc_rails/template_handler"
require_relative "evc_rails/railtie"

module EvcRails
  class Error < StandardError; end
end
