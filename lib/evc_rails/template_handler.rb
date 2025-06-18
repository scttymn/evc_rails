# lib/evc_rails/template_handler.rb
#
# This file contains the core logic for the .evc template handler.
# It's part of the `EvcRails` module to keep it namespaced within the gem.
# Handles .evc templates, converting PascalCase tags (self-closing <MyComponent attr={value} />
# or container <MyComponent>content</MyComponent>) into Rails View Component renders.
# Supports string literals and Ruby expressions as attribute values. The handler is
# agnostic to specific component APIs, passing content as a block for the component
# to interpret via yield or custom methods.

module EvcRails
  module TemplateHandlers
    class Evc
      # Regex to match opening or self-closing PascalCase component tags with attributes
      TAG_REGEX = %r{<([A-Z][a-zA-Z_]*)([^>]*)/?>}

      # Regex to match closing PascalCase component tags
      CLOSE_TAG_REGEX = %r{</([A-Z][a-zA-Z_]*)>}

      # Regex for attributes: Supports string literals (key="value", key='value')
      # and Ruby expressions (key={@variable}).
      # Group 1: Attribute key, Group 2: Double-quoted value, Group 3: Single-quoted value,
      # Group 4: Ruby expression.
      ATTRIBUTE_REGEX = /(\w+)=(?:"([^"]*)"|'([^']*)'|\{([^}]*)\})/

      # Cache for compiled templates to improve performance
      def call(template, source = nil)
        # Only use cache in non-development environments
        if !Rails.env.development? && @cache && @cache[identifier] && source == @cache[identifier][:source]
          return @cache[identifier][:result]
        end
      
        @cache ||= {} unless Rails.env.development? # Initialize cache only in production
        identifier = template.identifier
        processed_source = process_template(source, template)
        erb_handler = ActionView::Template.registered_template_handler(:erb)
        result = erb_handler.call(template, processed_source)
        @cache[identifier] = { source: source, result: result } unless Rails.env.development?
        result
      end

      private

      def process_template(source, template)
        result = ""
        pos = 0
        stack = [] # Track [component_class, render_params, start_pos]

        while pos < source.length
          if (match = TAG_REGEX.match(source, pos))
            result << source[pos...match.begin(0)] # Append text before tag
            pos = match.end(0)

            is_self_closing = match[0].end_with?("/>")
            tag_name = match[1]
            attributes_str = match[2].strip

            component_class_name = if tag_name.end_with?("Component")
                                     tag_name
                                   else
                                     "#{tag_name}Component"
                                   end

            begin
              component_class_name.constantize
            rescue NameError
              raise ArgumentError, "Component #{component_class_name} not found in template #{template.identifier}"
            end

            params = []
            attributes_str.scan(ATTRIBUTE_REGEX) do |key, quoted_value, single_quoted_value, ruby_expression|
              if key !~ /\A[a-z_][a-z0-9_]*\z/i
                raise ArgumentError, "Invalid attribute key '#{key}' in template #{template.identifier}"
              end

              formatted_key = "#{key}:"
              if ruby_expression
                params << "#{formatted_key} #{ruby_expression}"
              elsif quoted_value
                params << "#{formatted_key} \"#{quoted_value.gsub('"', '\"')}\""
              elsif single_quoted_value
                params << "#{formatted_key} \"#{single_quoted_value.gsub("'", "\\'")}\""
              end
            end

            render_params_str = params.join(", ")

            if is_self_closing
              result << "<%= render #{component_class_name}.new(#{render_params_str}) %>"
            else
              stack << [component_class_name, render_params_str, pos]
            end

          elsif (match = CLOSE_TAG_REGEX.match(source, pos))
            result << source[pos...match.begin(0)] # Append text before closing tag
            pos = match.end(0)

            closing_tag_name = match[1]
            if stack.empty?
              raise ArgumentError, "Unmatched closing tag </#{closing_tag_name}> in template #{template.identifier}"
            end

            component_class_name, render_params_str, start_pos = stack.pop
            if component_class_name != closing_tag_name
              raise ArgumentError, "Mismatched tags: expected </#{component_class_name}>, got </#{closing_tag_name}>"
            end

            content = process_template(source[start_pos...pos], template)
            result << "<%= render #{component_class_name}.new(#{render_params_str}) do %>#{content}<% end %>"

          else
            result << source[pos..-1] # Append remaining text
            break
          end
        end

        # Handle unclosed tags
        raise ArgumentError, "Unclosed tag <#{stack.last[0]}> in template #{template.identifier}" unless stack.empty?

        result
      end
    end
  end
end
