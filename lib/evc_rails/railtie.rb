# frozen_string_literal: true

# This file defines a Rails::Railtie, which is the mechanism for Ruby gems
# to integrate with the Rails framework during its boot process.

module EvcRails
  class Railtie < Rails::Railtie
    # The `initializer` block runs when the Rails application is being initialized.
    # We use it to register our custom template handler.
    initializer "evc_rails.register_template_handler" do
      # Ensure ActionView is loaded before attempting to register the handler.
      # This is important in case ActionView hasn't fully loaded yet during initialization.
      ActiveSupport.on_load(:action_view) do
        # Register the Evc template handler for files with the '.evc' extension.
        # This tells Rails to use `EvcRails::TemplateHandlers::Evc` whenever it encounters
        # a view file ending in .evc.
        ActionView::Template.register_template_handler(:evc, EvcRails::TemplateHandlers::Evc.new)
      end
    end
  end
end
