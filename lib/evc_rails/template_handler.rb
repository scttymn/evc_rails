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

      # Helper method to determine the full component class name
      def resolve_component_class_name(tag_name)
        if tag_name.include?("::")
          # For namespaced components, just append Component
          "#{tag_name}Component"
        elsif tag_name.end_with?("Component")
          tag_name
        else
          "#{tag_name}Component"
        end
      end

      # Processes the .evc template source, converting custom tags into Rails View Component render calls.
      # This method uses a single-pass parser with a revised strategy for handling nesting.
      def process_template(source, template)
        parts = []
        pos = 0
        # Stack tracks [tag_name, component_class_name, render_params_str, content_start_pos_in_source]
        stack = []
      
        # Initialize memoization cache for this processing run
        @component_class_memo = {}
      
        # Debugging: Log the source template
        Rails.logger.debug "Processing template: #{template.identifier}\nSource:\n#{source}"
      
        while pos < source.length
          # Try to match an opening or self-closing tag
          if (match = TAG_REGEX.match(source, pos))
            # Append text before the tag to parts
            parts << source[pos...match.begin(0)] if pos < match.begin(0)
            pos = match.end(0) # Move past the matched tag
      
            is_self_closing = match[0].end_with?("/>")
            tag_name = match[1]
            attributes_str = match[3].strip
      
            # Debugging: Log the matched tag
            Rails.logger.debug "Matched tag: #{match[0]} at position #{match.begin(0)}"
      
            # Resolve component class name
            component_class_name = resolve_component_class_name(tag_name)
      
            # Validate component class
            component_class = @component_class_memo[component_class_name] ||= begin
              component_class_name.constantize
            rescue NameError
              raise ArgumentError, "Component #{component_class_name} not found in template #{template.identifier}"
            end
      
            # Parse attributes
            params = []
            attributes_str.scan(ATTRIBUTE_REGEX) do |key, quoted_value, single_quoted_value, ruby_expression|
              unless key =~ /\A[a-z_][a-z0-9_]*\z/i
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
              # Self-closing tag: render immediately
              parts << "<%= render #{component_class_name}.new(#{render_params_str}) %>"
              Rails.logger.debug "Rendered self-closing tag: #{tag_name}"
            else
              # Opening tag: push to stack with source position
              stack << [tag_name, component_class_name, render_params_str, pos]
              Rails.logger.debug "Pushed opening tag: #{tag_name}, Stack: #{stack.inspect}"
            end
      
          # Try to match a closing tag
          elsif (match = CLOSE_TAG_REGEX.match(source, pos))
            # Append text before the closing tag
            parts << source[pos...match.begin(0)] if pos < match.begin(0)
            pos = match.end(0) # Move past the matched tag
      
            closing_tag_name = match[1]
            line_number = source[0...match.begin(0)].count("\n") + 1
      
            # Debugging: Log the closing tag
            Rails.logger.debug "Matched closing tag: </#{closing_tag_name}> at position #{match.begin(0)}, line #{line_number}"
      
            # Check for unmatched closing tags
            if stack.empty?
              raise ArgumentError, "Unmatched closing tag </#{closing_tag_name}> at line #{line_number} in template #{template.identifier}"
            end
      
            # Find the matching opening tag in the stack
            matching_index = stack.rindex { |(tag_name, _, _, _)| tag_name == closing_tag_name }
            unless matching_index
              raise ArgumentError, "No matching opening tag for </#{closing_tag_name}> at line #{line_number} in template #{template.identifier}"
            end
      
            # Pop all entries up to and including the matching tag
            popped = stack.slice!(matching_index..-1)
            original_tag_name, component_class_name, render_params_str, content_start_pos = popped.last
      
            # Debugging: Log stack state
            Rails.logger.debug "Popped tag: #{original_tag_name}, Stack: #{stack.inspect}"
      
            # Collect content from content_start_pos to current position
            block_content = source[content_start_pos...match.begin(0)]
      
            # Process nested content recursively to handle any components within
            processed_block_content = process_template(block_content, template)
      
            # Construct the render call with block
            full_render_call = "<%= render #{component_class_name}.new(#{render_params_str}) do %>#{processed_block_content}<% end %>"
            parts << full_render_call
      
            Rails.logger.debug "Rendered component: #{original_tag_name} with content:\n#{processed_block_content}"
      
          else
            # No tags matched; append remaining source and break
            parts << source[pos..-1] if pos < source.length
            break
          end
        end
      
        # Check for unclosed tags
        unless stack.empty?
          line_number = source[0...pos].count("\n") + 1
          raise ArgumentError, "Unclosed tag <#{stack.last[0]}> at line #{line_number} in template #{template.identifier}"
        end
      
        # Debugging: Log final output
        Rails.logger.debug "Final processed template:\n#{parts.join('')}"
      
        parts.join("")
      end
    end
  end
end
