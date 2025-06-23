# lib/evc_rails/template_handler.rb
#
# Simple template handler for .evc files
# Converts PascalCase tags into Rails View Component renders

module EvcRails
  module TemplateHandlers
    class Evc
      # Simple regex to match PascalCase component tags
      TAG_REGEX = %r{<([A-Z][a-zA-Z0-9_]*(?:::[A-Z][a-zA-Z0-9_]*)*)([^>]*)/?>}

      # Regex to match closing tags
      CLOSE_TAG_REGEX = %r{</([A-Z][a-zA-Z0-9_]*(?:::[A-Z][a-zA-Z0-9_]*)*)>}

      # Regex for attributes
      ATTRIBUTE_REGEX = /(\w+)=(?:"([^"]*)"|'([^']*)'|\{([^}]*)\})/

      # Cache for compiled templates
      @template_cache = {}
      @cache_mutex = Mutex.new

      require "active_support/cache"

      def self.clear_cache
        @cache_mutex.synchronize do
          @template_cache.clear
        end
      end

      def self.cache_stats
        @cache_mutex.synchronize do
          {
            size: @template_cache.size,
            keys: @template_cache.keys
          }
        end
      end

      def cache_store
        if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
          Rails.cache
        else
          @fallback_cache ||= ActiveSupport::Cache::MemoryStore.new
        end
      end

      def call(template, source = nil)
        source ||= template.source

        # Check cache first (only in non-development environments)
        unless Rails.env.development?
          cache_key = "evc_rails_template:#{template.identifier}:#{Digest::MD5.hexdigest(source)}"
          cached_result = cache_store.read(cache_key)
          return cached_result if cached_result
        end

        # Process the template and convert to ERB
        processed_source = process_template(source, template)

        # Use the standard ERB handler to compile the processed source
        erb_handler = ActionView::Template.registered_template_handler(:erb)
        result = erb_handler.call(template, processed_source)

        # Cache the result (only in non-development environments)
        unless Rails.env.development?
          cache_key = "evc_rails_template:#{template.identifier}:#{Digest::MD5.hexdigest(source)}"
          cache_store.write(cache_key, result)
        end

        normalize_whitespace(result)
      end

      private

      def process_template(source, template)
        # Pre-compile regexes for better performance
        tag_regex = TAG_REGEX
        close_tag_regex = CLOSE_TAG_REGEX
        attribute_regex = ATTRIBUTE_REGEX

        # Use String buffer for better performance
        result = String.new
        stack = []
        pos = 0
        source_length = source.length

        # Track line numbers for better error messages
        def line_number_at_position(source, pos)
          source[0...pos].count("\n") + 1
        end

        def column_number_at_position(source, pos)
          last_newline = source[0...pos].rindex("\n")
          last_newline ? pos - last_newline : pos + 1
        end

        while pos < source_length
          # Find next opening or closing tag
          next_open = tag_regex.match(source, pos)
          next_close = close_tag_regex.match(source, pos)

          if next_open && (!next_close || next_open.begin(0) < next_close.begin(0))
            # Found opening tag
            match = next_open
            tag_name = match[1]
            attributes_str = match[2].to_s.strip
            params, as_variable = parse_attributes(attributes_str, attribute_regex)
            param_str = params.join(", ")
            is_self_closing = match[0].end_with?("/>")

            # Add content before the tag
            result << source[pos...match.begin(0)] if pos < match.begin(0)

            # Determine if this is a slot (e.g., WithHeader, WithPost)
            parent_component = stack.reverse.find { |item| item[4] == :component }
            is_slot = false
            slot_name = nil

            if parent_component && tag_name.start_with?("With")
              is_slot = true
              # Convert CamelCase slot name to snake_case
              slot_name = tag_name[4..].gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
              parent_component[6] = true # Mark parent as having a slot
            end

            if is_self_closing
              if is_slot
                parent_variable = parent_component[8]
                result << if param_str.empty?
                            "<% #{parent_variable}.with_#{slot_name} do %><% end %>"
                          else
                            "<% #{parent_variable}.with_#{slot_name}(#{param_str}) do %><% end %>"
                          end
              else
                component_class = "#{tag_name}Component"
                result << if param_str.empty?
                            "<%= render #{component_class}.new %>"
                          else
                            "<%= render #{component_class}.new(#{param_str}) %>"
                          end
              end
            elsif is_slot
              parent_variable = parent_component[8]
              stack << [tag_name, nil, param_str, result.length, :slot, slot_name, false, match.begin(0), nil]
              result << if param_str.empty?
                          "<% #{parent_variable}.with_#{slot_name} do %>"
                        else
                          "<% #{parent_variable}.with_#{slot_name}(#{param_str}) do %>"
                        end
            else
              component_class = "#{tag_name}Component"
              variable_name = as_variable || component_variable_name(tag_name)
              stack << [tag_name, component_class, param_str, result.length, :component, nil, false, match.begin(0),
                        variable_name]
              result << if param_str.empty?
                          "<%= render #{component_class}.new do %>"
                        else
                          "<%= render #{component_class}.new(#{param_str}) do %>"
                        end
            end

            pos = match.end(0)
          elsif next_close
            # Found closing tag
            match = next_close
            closing_tag_name = match[1]

            # Add content before the closing tag
            result << source[pos...match.begin(0)] if pos < match.begin(0)

            # Find matching opening tag
            if stack.empty?
              line = line_number_at_position(source, match.begin(0))
              col = column_number_at_position(source, match.begin(0))
              raise ArgumentError, "Unmatched closing tag </#{closing_tag_name}> at line #{line}, column #{col}"
            end

            # Find the matching opening tag (from the end)
            matching_index = stack.rindex { |(tag_name, *)| tag_name == closing_tag_name }
            if matching_index.nil?
              line = line_number_at_position(source, match.begin(0))
              col = column_number_at_position(source, match.begin(0))
              raise ArgumentError, "No matching opening tag for </#{closing_tag_name}> at line #{line}, column #{col}"
            end

            # Pop the matching opening tag
            open_tag_data = stack.delete_at(matching_index)
            tag_type = open_tag_data[4]

            if tag_type == :component
              _tag_name, component_class, param_str, start_pos, _type, _slot_name, slot_used, _open_pos, variable_name = open_tag_data

              # Patch in |variable_name| for component if a slot was used
              if slot_used
                # More robustly find the end of the `do` block to insert the variable.
                # This avoids faulty regex matching on complex parameters.
                relevant_part = result[start_pos..-1]
                match_for_insertion = /( do)( %>)/.match(relevant_part)
                if match_for_insertion
                  # Insert the variable name just before the ` do`
                  insertion_point = start_pos + match_for_insertion.begin(1)
                  result.insert(insertion_point, " |#{variable_name}|")
                end
              end

              result << "<% end %>"
            else # It's a slot
              result << "<% end %>"
            end

            pos = match.end(0)
          else
            # No more tags, add remaining content
            result << source[pos..-1] if pos < source_length
            break
          end
        end

        # Check for unclosed tags
        unless stack.empty?
          unclosed_tag = stack.last
          open_pos = unclosed_tag[7]
          line = line_number_at_position(source, open_pos)
          col = column_number_at_position(source, open_pos)
          raise ArgumentError, "Unclosed tag <#{unclosed_tag[0]}> at line #{line}, column #{col}"
        end

        result
      end

      def normalize_whitespace(erb_string)
        # For now, return the string as-is to avoid breaking existing functionality
        # We can add proper whitespace normalization later if needed
        erb_string
      end

      def component_variable_name(tag_name)
        # Simplified version of ActiveSupport's underscore
        name = tag_name.gsub(/::/, "_")
        name.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
        name.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
        name.tr!("-", "_")
        name.downcase!
        name
      end

      def parse_attributes(attributes_str, attribute_regex = ATTRIBUTE_REGEX)
        as_variable = nil
        # Find and remove the `as` attribute, storing its value.
        attributes_str = attributes_str.gsub(/\bas=(?:"([^"]*)"|'([^']*)')/) do |_match|
          as_variable = Regexp.last_match(1) || Regexp.last_match(2)
          ""
        end.strip

        params = []
        attributes_str.scan(attribute_regex) do |key, quoted_value, single_quoted_value, ruby_expression|
          if ruby_expression
            params << "#{key}: #{ruby_expression}"
          elsif quoted_value
            params << "#{key}: \"#{quoted_value.gsub('"', '\\"')}\""
          elsif single_quoted_value
            params << "#{key}: \"#{single_quoted_value.gsub("'", "\\'")}\""
          end
        end
        [params, as_variable]
      end
    end
  end
end
