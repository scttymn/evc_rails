# frozen_string_literal: true

# This file contains the core logic for the .evc template handler.
# It's now part of the `EvcRails` module to keep it namespaced within the gem.

module EvcRails
  module TemplateHandlers
    class Evc
      # Regex to match PascalCase component tags.
      PASCAL_CASE_TAG_REGEX = %r{<([A-Z][a-zA-Z_]*)([^>]*?)\s*/>}

      # Regex to match individual key="value" or key='value' attributes.
      ATTRIBUTE_REGEX = /(\w+)=["']([^"']*)["']/

      def call(template)
        source = template.source

        processed_source = source.gsub(PASCAL_CASE_TAG_REGEX) do |match|
          component_tag_name = ::Regexp.last_match(1)
          attributes_str = ::Regexp.last_match(2)

          component_class_name = if component_tag_name.end_with?("Component")
                                   component_tag_name
                                 else
                                   "#{component_tag_name}Component"
                                 end

          params = {}
          attributes_str.scan(ATTRIBUTE_REGEX) do |key, value|
            params[key.to_sym] = value
          end

          render_params_str = params.map do |k, v|
            "#{k}: \"#{v.gsub('"', '\"')}\""
          end.join(", ")

          "<%= render #{component_class_name}.new(#{render_params_str}) %>"
        end

        # It's crucial to use the ActionView::Template.registered_template_handler(:erb)
        # to ensure any remaining ERB in the .evc file is processed correctly.
        erb_handler = ActionView::Template.registered_template_handler(:erb)
        erb_handler.call(ActionView::Template.new(processed_source, template.identifier, erb_handler,
                                                  format: template.format))
      end
    end
  end
end
