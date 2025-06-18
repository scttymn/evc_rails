# lib/evc_rails/railtie.rb
#
# This file defines a Rails::Railtie, which integrates the evc_rails gem
# with the Rails framework during its boot process.

require "evc_rails/template_handler"
require "action_view" # Ensure ActionView is loaded for handler registration

module EvcRails
  class Railtie < Rails::Railtie
    # Register MIME type and template handler early in the initialization process
    initializer "evc_rails.register_template_handler", before: :load_config_initializers do
      Rails.logger.info "Registering EVC template handler"
      # Register a unique MIME type for .evc templates
      Mime::Type.register "text/evc", :evc, %w[text/evc], %w[evc]

      # Register the template handler
      handler = EvcRails::TemplateHandlers::Evc.new
      ActionView::Template.register_template_handler(:evc, handler)

      Rails.logger.info "Template handler registered: #{handler.inspect}"
    end

    # Finalize configuration after Rails initialization
    config.after_initialize do
      Rails.logger.info "Configuring EVC template handlers"
      # Ensure :evc is prioritized in default handlers
      config.action_view.default_template_handlers ||= []
      config.action_view.default_template_handlers.prepend(:evc)

      # Verify handler registration (no re-registration)
      unless ActionView::Template.handler_for_extension(:evc)
        Rails.logger.warn "EVC template handler not registered; check initialization"
      end
    end
  end
end
