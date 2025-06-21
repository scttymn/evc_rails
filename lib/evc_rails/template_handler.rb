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
            is_self_closing = match[0].end_with?("/>")

            # Add content before the tag
            result << source[pos...match.begin(0)] if pos < match.begin(0)

            # Determine if this is a slot (e.g., WithHeader, WithPost, or Card::Header inside Card)
            parent = stack.last
            is_slot = false
            slot_name = nil
            slot_parent = nil
            if parent
              parent_tag = parent[0]

              # Check for WithSlotName syntax (e.g., WithHeader, WithPost)
              if tag_name.start_with?("With")
                is_slot = true
                slot_name = tag_name[4..-1].downcase # Remove "With" prefix and convert to lowercase
                slot_parent = parent_tag
                # Mark parent as having a slot
                parent[6] = true
              # Check for Component::slotname syntax (backward compatibility)
              elsif tag_name.start_with?("#{parent_tag}::")
                is_slot = true
                slot_name = tag_name.split("::").last.downcase
                slot_parent = parent_tag
                # Mark parent as having a slot
                parent[6] = true
              end
            end

            if is_self_closing
              if is_slot
                params = parse_attributes(attributes_str, attribute_regex)
                param_str = params.join(", ")
                result << if param_str.empty?
                            "<% c.#{slot_name} do %><% end %>"
                          else
                            "<% c.#{slot_name}(#{param_str}) do %><% end %>"
                          end
              else
                component_class = "#{tag_name}Component"
                params = parse_attributes(attributes_str, attribute_regex)
                param_str = params.join(", ")
                result << if param_str.empty?
                            "<%= render #{component_class}.new %>"
                          else
                            "<%= render #{component_class}.new(#{param_str}) %>"
                          end
              end
            elsif is_slot
              params = parse_attributes(attributes_str, attribute_regex)
              param_str = params.join(", ")
              stack << [tag_name, nil, param_str, result.length, :slot, slot_name, false, match.begin(0)]
              result << if param_str.empty?
                          "<% c.#{slot_name} do %>"
                        else
                          "<% c.#{slot_name}(#{param_str}) do %>"
                        end
            else
              component_class = "#{tag_name}Component"
              params = parse_attributes(attributes_str, attribute_regex)
              param_str = params.join(", ")
              # If this is the outermost component, add |c| for slot support only if a slot is used
              if stack.empty?
                stack << [tag_name, component_class, param_str, result.length, :component, nil, false, match.begin(0)] # [tag_name, class, params, pos, type, slot_name, slot_used, open_pos]
                # We'll patch in |c| at close if needed
                result << if param_str.empty?
                            "<%= render #{component_class}.new do %>"
                          else
                            "<%= render #{component_class}.new(#{param_str}) do %>"
                          end
              else
                stack << [tag_name, component_class, param_str, result.length, :component, nil, false, match.begin(0)]
                result << if param_str.empty?
                            "<%= render #{component_class}.new do %>"
                          else
                            "<%= render #{component_class}.new(#{param_str}) do %>"
                          end
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
            matching_index = stack.rindex { |(tag_name, _, _, _, _, _, _, _)| tag_name == closing_tag_name }
            if matching_index.nil?
              line = line_number_at_position(source, match.begin(0))
              col = column_number_at_position(source, match.begin(0))
              raise ArgumentError, "No matching opening tag for </#{closing_tag_name}> at line #{line}, column #{col}"
            end

            # Pop the matching opening tag
            tag_name, component_class, param_str, start_pos, type, slot_name, slot_used, open_pos = stack.delete_at(matching_index)

            # Patch in |c| for top-level component if a slot was used
            if type == :component && stack.empty? && slot_used
              # Find the opening block and insert |c|
              open_block_regex = /(<%= render #{component_class}\.new(?:\(.*?\))? do)( %>)/
              result.sub!(open_block_regex) { "#{::Regexp.last_match(1)} |c|#{::Regexp.last_match(2)}" }
            end

            # Add closing block
            result << (type == :slot ? "<% end %>" : "<% end %>")

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

      def parse_attributes(attributes_str, attribute_regex = ATTRIBUTE_REGEX)
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
        params
      end
    end
  end
end
