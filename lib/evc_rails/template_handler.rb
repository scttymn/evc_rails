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
      # Updated to support namespaced components like UI::Button
      TAG_REGEX = %r{<([A-Z][a-zA-Z_]*(::[A-Z][a-zA-Z_]*)*)([^>]*)/?>}

      # Regex to match closing PascalCase component tags
      # Updated to support namespaced components like UI::Button
      CLOSE_TAG_REGEX = %r{</([A-Z][a-zA-Z_]*(::[A-Z][a-zA-Z_]*)*)>}

      # Regex for attributes: Supports string literals (key="value", key='value')
      # and Ruby expressions (key={@variable}).
      # Group 1: Attribute key, Group 2: Double-quoted value, Group 3: Single-quoted value,
      # Group 4: Ruby expression.
      ATTRIBUTE_REGEX = /(\w+)=(?:"([^"]*)"|'([^']*)'|\{([^}]*)\})/

      # Cache for compiled templates to improve performance.
      # @cache will store { identifier: { source: original_source, result: compiled_result } }
      # Note: In a production environment, a more robust cache store (e.g., Rails.cache)
      # might be preferred for persistence and memory management, especially for large applications.
      # This simple in-memory cache is effective for a single process.
      @cache = {}

      def self.clear_cache # Class method to allow clearing cache manually, if needed
        @cache = {}
      end

      def call(template, source = nil)
        identifier = template.identifier

        # Only use cache in non-development environments
        # Check if cache exists for this template and if the source hasn't changed.
        # This prevents recompilation of unchanged templates.
        if !Rails.env.development? && self.class.instance_variable_get(:@cache)[identifier] &&
           source == self.class.instance_variable_get(:@cache)[identifier][:source]
          return self.class.instance_variable_get(:@cache)[identifier][:result]
        end

        # Process the template source into an ERB-compatible string
        processed_source = process_template(source, template)

        # Get the standard ERB handler and pass the processed source to it
        erb_handler = ActionView::Template.registered_template_handler(:erb)
        result = erb_handler.call(template, processed_source)

        # Cache the result for future requests, but only in non-development environments.
        # In development, templates change frequently, so caching would hinder development flow.
        unless Rails.env.development?
          self.class.instance_variable_set(:@cache, self.class.instance_variable_get(:@cache).merge({
                                                                                                      identifier => { source: source, result: result }
                                                                                                    }))
        end
        result
      end

      private

      # A memoization cache for resolved component classes within a single template processing.
      # This prevents repeated `constantize` calls for the same component name within `process_template`.
      attr_reader :component_class_memo

      def initialize
        @component_class_memo = {}
      end

      # Processes the .evc template source, converting custom tags into Rails View Component render calls.
      # This method is recursive to handle nested components.
      def process_template(source, template)
        # Using an array for `parts` and then joining at the end is generally more efficient
        # for building strings in Ruby than repeated string concatenations (`<<`).
        parts = []
        pos = 0
        stack = [] # Track [component_class_name, render_params_str, start_pos_in_source]

        # Initialize memoization cache for this processing run
        @component_class_memo = {}

        while pos < source.length
          # Try to match an opening or self-closing tag
          if (match = TAG_REGEX.match(source, pos))
            # Append text before the current tag to the result parts
            parts << source[pos...match.begin(0)]
            pos = match.end(0) # Move position past the matched tag

            is_self_closing = match[0].end_with?("/>")
            tag_name = match[1]
            attributes_str = match[3].strip

            # Determine the full component class name
            # Handle both namespaced (UI::Button) and non-namespaced (Button) components
            component_class_name = if tag_name.include?("::")
                                     # For namespaced components, just append Component
                                     "#{tag_name}Component"
                                   elsif tag_name.end_with?("Component")
                                     tag_name
                                   else
                                     "#{tag_name}Component"
                                   end

            # Validate if the component class exists using memoization.
            # The component class will only be constantized once per unique class name
            # within a single template processing call.
            component_class = @component_class_memo[component_class_name] ||= begin
              component_class_name.constantize
            rescue NameError
              raise ArgumentError, "Component #{component_class_name} not found in template #{template.identifier}"
            end

            # Parse attributes and format them for the render call
            params = []
            attributes_str.scan(ATTRIBUTE_REGEX) do |key, quoted_value, single_quoted_value, ruby_expression|
              # Basic validation for attribute keys
              unless key =~ /\A[a-z_][a-z0-9_]*\z/i
                raise ArgumentError, "Invalid attribute key '#{key}' in template #{template.identifier}"
              end

              formatted_key = "#{key}:"
              if ruby_expression
                # For Ruby expressions, directly embed the expression.
                params << "#{formatted_key} #{ruby_expression}"
              elsif quoted_value
                # For double-quoted string literals, escape double quotes within the value.
                params << "#{formatted_key} \"#{quoted_value.gsub('"', '\"')}\""
              elsif single_quoted_value
                # For single-quoted string literals, escape single quotes within the value
                # and wrap in double quotes for Ruby string literal syntax.
                params << "#{formatted_key} \"#{single_quoted_value.gsub("'", "\\'")}\""
              end
            end

            render_params_str = params.join(", ")

            if is_self_closing
              # If it's a self-closing tag, generate a simple render call.
              parts << "<%= render #{component_class_name}.new(#{render_params_str}) %>"
            else
              # If it's an opening tag, push it onto the stack to await its closing tag.
              stack << [component_class_name, render_params_str, pos]
            end

          # Try to match a closing tag
          elsif (match = CLOSE_TAG_REGEX.match(source, pos))
            # Append text before the closing tag to the result parts
            parts << source[pos...match.begin(0)]
            pos = match.end(0) # Move position past the matched tag

            closing_tag_name = match[1]

            # Check for unmatched closing tags
            if stack.empty?
              raise ArgumentError, "Unmatched closing tag </#{closing_tag_name}> in template #{template.identifier}"
            end

            # Pop the corresponding opening tag from the stack
            component_class_name, render_params_str, start_pos = stack.pop

            # Check for mismatched tags (e.g., <div></p>)
            if component_class_name != closing_tag_name
              raise ArgumentError,
                    "Mismatched tags: expected </#{component_class_name}>, got </#{closing_tag_name}> in template #{template.identifier}"
            end

            # Recursively process the content between the opening and closing tags.
            # This is where nested components are handled.
            content = process_template(source[start_pos...match.begin(0)], template)

            # Generate the render call with a block for the content.
            parts << "<%= render #{component_class_name}.new(#{render_params_str}) do %>#{content}<% end %>"

          else
            # If no tags are matched, append the rest of the source and break the loop.
            parts << source[pos..-1]
            break
          end
        end

        # After parsing, if the stack is not empty, it means there are unclosed tags.
        raise ArgumentError, "Unclosed tag <#{stack.last[0]}> in template #{template.identifier}" unless stack.empty?

        # Join all the collected parts to form the final ERB string.
        parts.join("")
      end
    end
  end
end
