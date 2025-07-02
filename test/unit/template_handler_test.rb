# frozen_string_literal: true

require_relative "../test_helper"

class TemplateHandlerTest < Minitest::Test
  def setup
    @handler = EvcRails::TemplateHandlers::Evc.new
    @template = OpenStruct.new(source: "", identifier: "test.evc")
  end

  def test_handler_initializes
    assert_instance_of EvcRails::TemplateHandlers::Evc, @handler
  end

  def test_handler_responds_to_call
    assert_respond_to @handler, :call
  end

  def test_handler_returns_erb_compiled_result
    result = @handler.call(@template, "Hello World")
    assert_equal "ERB_COMPILED: Hello World", result
  end

  def test_handler_uses_template_source_when_no_source_provided
    @template.source = "Default source"
    result = @handler.call(@template)
    assert_equal "ERB_COMPILED: Default source", result
  end

  def test_handler_preserves_plain_html
    source = "<h1>Hello</h1><p>World</p>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{source}", result
  end

  def test_handler_preserves_erb_code
    source = "<%= @user.name %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{source}", result
  end

  def test_self_closing_pascal_case_tag
    source = "<Button />"
    expected = "<%= render ButtonComponent.new %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_self_closing_tag_with_string_attribute
    source = '<Button size="lg" />'
    expected = '<%= render ButtonComponent.new(size: "lg") %>'
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_self_closing_tag_with_object_attribute
    source = "<Button user={@user} />"
    expected = "<%= render ButtonComponent.new(user: @user) %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_self_closing_tag_with_multiple_attributes
    source = '<Button size="lg" user={@user} />'
    expected = '<%= render ButtonComponent.new(size: "lg", user: @user) %>'
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_namespaced_self_closing_tag
    source = "<UI::Button />"
    expected = "<%= render UI::ButtonComponent.new %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_deeply_namespaced_self_closing_tag
    source = "<Forms::Fields::TextField value={@value} />"
    expected = "<%= render Forms::Fields::TextFieldComponent.new(value: @value) %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_simple_block_tag
    source = "<Container>Hello World</Container>"
    expected = "<%= render ContainerComponent.new do %>Hello World<% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_block_tag_with_attributes
    source = '<Container class="wrapper">Hello World</Container>'
    expected = '<%= render ContainerComponent.new(class: "wrapper") do %>Hello World<% end %>'
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_nested_block_tags
    source = "<Container><Button>Click me</Button></Container>"
    expected = "<%= render ContainerComponent.new do %><%= render ButtonComponent.new do %>Click me<% end %><% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_namespaced_block_tag
    source = "<UI::Container>Hello World</UI::Container>"
    expected = "<%= render UI::ContainerComponent.new do %>Hello World<% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_uses_snake_case_name_for_yielded_variable
    source = <<~EVC.strip
      <Accordion>
        <WithTrigger>
          <%= accordion.arrow %>
        </WithTrigger>
      </Accordion>
    EVC
    expected = <<~ERB.strip
      <%= render AccordionComponent.new do |accordion| %>
        <% accordion.with_trigger do %>
          <%= accordion.arrow %>
        <% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_uses_as_attribute_for_yielded_variable
    source = <<~EVC.strip
      <Accordion as="my_accordion">
        <WithTrigger>
          <%= my_accordion.arrow %>
        </WithTrigger>
      </Accordion>
    EVC
    expected = <<~ERB.strip
      <%= render AccordionComponent.new do |my_accordion| %>
        <% my_accordion.with_trigger do %>
          <%= my_accordion.arrow %>
        <% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_handles_nested_components_with_yielded_variables
    source = <<~EVC.strip
      <Card as="outer_card">
        <WithContent>
          <p><%= outer_card.title %></p>
          <Card as="inner_card">
            <WithHeader><%= inner_card.title %></WithHeader>
          </Card>
        </WithContent>
      </Card>
    EVC
    expected = <<~ERB.strip
      <%= render CardComponent.new do |outer_card| %>
        <% outer_card.with_content do |content| %>
          <p><%= outer_card.title %></p>
          <%= render CardComponent.new do |inner_card| %>
            <% inner_card.with_header do %><%= inner_card.title %><% end %>
          <% end %>
        <% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_deeply_nested_and_multiple_components
    source = <<~EVC.strip
      <Ui::Card>
        <h2 class="text-2xl font-semibold">Testing Layout Components:</h2>
      #{"  "}
        <div class="mt-4">
          <h3 class="text-lg font-medium mb-4">Simple Grid:</h3>
          <Ui::Grid cols="3" gap="md">
            <Ui::Card shadow="sm">
              <p class="text-center">Item 1</p>
            </Ui::Card>
            <Ui::Card shadow="sm">
              <p class="text-center">Item 2</p>
            </Ui::Card>
            <Ui::Card shadow="sm">
              <p class="text-center">Item 3</p>
            </Ui::Card>
          </Ui::Grid>
        </div>
      </Ui::Card>
    EVC
    expected = <<~ERB.strip
      <%= render Ui::CardComponent.new do %>
        <h2 class="text-2xl font-semibold">Testing Layout Components:</h2>
      #{"  "}
        <div class="mt-4">
          <h3 class="text-lg font-medium mb-4">Simple Grid:</h3>
          <%= render Ui::GridComponent.new(cols: "3", gap: "md") do %>
            <%= render Ui::CardComponent.new(shadow: "sm") do %>
              <p class="text-center">Item 1</p>
            <% end %>
            <%= render Ui::CardComponent.new(shadow: "sm") do %>
              <p class="text-center">Item 2</p>
            <% end %>
            <%= render Ui::CardComponent.new(shadow: "sm") do %>
              <p class="text-center">Item 3</p>
            <% end %>
          <% end %>
        </div>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_mixed_self_closing_and_block_tags
    source = "<Container><Button />Hello</Container>"
    expected = "<%= render ContainerComponent.new do %><%= render ButtonComponent.new %>Hello<% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_complex_nested_structure
    source = '<Container class="main"><Header title="Welcome" /><Content>Hello <Button>Click</Button></Content></Container>'
    expected = '<%= render ContainerComponent.new(class: "main") do %><%= render HeaderComponent.new(title: "Welcome") %><%= render ContentComponent.new do %>Hello <%= render ButtonComponent.new do %>Click<% end %><% end %><% end %>'
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_unmatched_closing_tag_raises_error
    source = "</Container>"
    assert_raises(ArgumentError, "Unmatched closing tag </Container>") do
      @handler.call(@template, source)
    end
  end

  def test_unclosed_tag_raises_error
    source = "<Container>Hello"
    assert_raises(ArgumentError, "Unclosed tag <Container>") do
      @handler.call(@template, source)
    end
  end

  def test_caching_functionality
    handler = EvcRails::TemplateHandlers::Evc.new
    source = "<Button />"
    expected = "<%= render ButtonComponent.new %>"
    handler.cache_store.clear

    # First call should process and cache
    result1 = handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result1

    # Second call with same source should use cache
    result2 = handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result2

    # Verify cache hit by reading the cache directly
    cache_key = "evc_rails_template:#{@template.identifier}:#{Digest::MD5.hexdigest(source)}"
    cached = handler.cache_store.read(cache_key)
    assert_equal result1, cached
  end

  def test_cache_invalidation_on_source_change
    handler = EvcRails::TemplateHandlers::Evc.new
    handler.cache_store.clear
    source1 = "<Button />"
    source2 = "<Button size=\"lg\" />"

    # Process first source
    result1 = handler.call(@template, source1)
    assert_equal "ERB_COMPILED: <%= render ButtonComponent.new %>", result1

    # Process second source (should be cached separately)
    result2 = handler.call(@template, source2)
    assert_equal "ERB_COMPILED: <%= render ButtonComponent.new(size: \"lg\") %>", result2

    # Verify both are cached
    cache_key1 = "evc_rails_template:#{@template.identifier}:#{Digest::MD5.hexdigest(source1)}"
    cache_key2 = "evc_rails_template:#{@template.identifier}:#{Digest::MD5.hexdigest(source2)}"
    cached1 = handler.cache_store.read(cache_key1)
    cached2 = handler.cache_store.read(cache_key2)
    assert_equal result1, cached1
    assert_equal result2, cached2
  end

  def test_cache_clear_functionality
    handler = EvcRails::TemplateHandlers::Evc.new
    source = "<Button />"
    handler.cache_store.clear
    handler.call(@template, source)
    cache_key = "evc_rails_template:#{@template.identifier}:#{Digest::MD5.hexdigest(source)}"
    cached = handler.cache_store.read(cache_key)
    assert cached, "Cache should have the entry after call"
    handler.cache_store.clear
    cached_after_clear = handler.cache_store.read(cache_key)
    assert_nil cached_after_clear, "Cache should be empty after clear"
  end

  def test_performance_with_caching
    # Clear cache first
    EvcRails::TemplateHandlers::Evc.clear_cache

    # Complex template for performance testing
    source = <<~EVC.strip
      <Ui::Card>
        <h2>Performance Test</h2>
        <Ui::Grid cols="3" gap="md">
          <Ui::Card shadow="sm"><p>Item 1</p></Ui::Card>
          <Ui::Card shadow="sm"><p>Item 2</p></Ui::Card>
          <Ui::Card shadow="sm"><p>Item 3</p></Ui::Card>
        </Ui::Grid>
      </Ui::Card>
    EVC

    # First call (should process)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result1 = @handler.call(@template, source)
    first_call_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Second call (should use cache)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result2 = @handler.call(@template, source)
    second_call_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Results should be identical
    assert_equal result1, result2

    # Second call should be faster (cache hit)
    # Note: In a real environment, the difference would be more pronounced
    assert_operator second_call_time, :<=, first_call_time, "Cached call should be faster"
  end

  def test_slot_support
    source = <<~EVC.strip
      <Card>
        <WithHeader>
          <h1>Title</h1>
        </WithHeader>
        <WithBody>
          <p>Body content</p>
        </WithBody>
      </Card>
    EVC
    expected = <<~ERB.strip
      <%= render CardComponent.new do |card| %>
        <% card.with_header do %>
          <h1>Title</h1>
        <% end %>
        <% card.with_body do %>
          <p>Body content</p>
        <% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_renders_many_support
    source = <<~EVC.strip
      <List>
        <WithItem>Item 1</WithItem>
        <WithItem>Item 2</WithItem>
        <WithItem>Item 3</WithItem>
      </List>
    EVC
    expected = <<~ERB.strip
      <%= render ListComponent.new do |list| %>
        <% list.with_item do %>Item 1<% end %>
        <% list.with_item do %>Item 2<% end %>
        <% list.with_item do %>Item 3<% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_renders_many_with_attributes
    source = <<~EVC.strip
      <List>
        <WithItem class="first">Item 1</WithItem>
        <WithItem class="second">Item 2</WithItem>
        <WithItem class="third">Item 3</WithItem>
      </List>
    EVC
    expected = <<~ERB.strip
      <%= render ListComponent.new do |list| %>
        <% list.with_item(class: "first") do %>Item 1<% end %>
        <% list.with_item(class: "second") do %>Item 2<% end %>
        <% list.with_item(class: "third") do %>Item 3<% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_better_error_messages_with_line_numbers
    # Test unmatched closing tag
    source = "</Button>"
    error = assert_raises(ArgumentError) do
      @handler.call(@template, source)
    end
    assert_match(%r{Unmatched closing tag </Button> at line 1, column 1}, error.message)

    # Test unclosed tag
    source = "<Button>Hello"
    error = assert_raises(ArgumentError) do
      @handler.call(@template, source)
    end
    assert_match(/Unclosed tag <Button> at line 1, column 1/, error.message)

    # Test mismatched tags
    source = "<Button>Hello</Container>"
    error = assert_raises(ArgumentError) do
      @handler.call(@template, source)
    end
    assert_match(%r{No matching opening tag for </Container> at line 1, column 14}, error.message)
  end

  def test_whitespace_normalization
    source = "<Container><Button>Click me</Button></Container>"
    result = @handler.call(@template, source)

    # Should preserve the original structure (no normalization for now)
    expected = "<%= render ContainerComponent.new do %><%= render ButtonComponent.new do %>Click me<% end %><% end %>"

    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_whitespace_normalization_with_slots
    source = "<Card><WithHeader>Title</WithHeader></Card>"
    expected = "<%= render CardComponent.new do |card| %><% card.with_header do %>Title<% end %><% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_with_slot_syntax
    source = <<~EVC.strip
      <Card>
        <WithHeader>
          <h1>Title</h1>
        </WithHeader>
        <WithBody>
          <p>Body content</p>
        </WithBody>
      </Card>
    EVC
    expected = <<~ERB.strip
      <%= render CardComponent.new do |card| %>
        <% card.with_header do %>
          <h1>Title</h1>
        <% end %>
        <% card.with_body do %>
          <p>Body content</p>
        <% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_with_slot_syntax_renders_many
    source = <<~EVC.strip
      <List>
        <WithItem>Item 1</WithItem>
        <WithItem>Item 2</WithItem>
        <WithItem>Item 3</WithItem>
      </List>
    EVC
    expected = <<~ERB.strip
      <%= render ListComponent.new do |list| %>
        <% list.with_item do %>Item 1<% end %>
        <% list.with_item do %>Item 2<% end %>
        <% list.with_item do %>Item 3<% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_with_slot_syntax_with_attributes
    source = <<~EVC.strip
      <List>
        <WithItem class="first">Item 1</WithItem>
        <WithItem class="second">Item 2</WithItem>
        <WithItem class="third">Item 3</WithItem>
      </List>
    EVC
    expected = <<~ERB.strip
      <%= render ListComponent.new do |list| %>
        <% list.with_item(class: "first") do %>Item 1<% end %>
        <% list.with_item(class: "second") do %>Item 2<% end %>
        <% list.with_item(class: "third") do %>Item 3<% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_with_slot_syntax_self_closing
    source = "<Card><WithHeader /></Card>"
    expected = "<%= render CardComponent.new do |card| %><% card.with_header %><% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_with_slot_syntax_with_ruby_expressions
    source = "<Card><WithHeader user={@current_user}>Welcome</WithHeader></Card>"
    expected = "<%= render CardComponent.new do |card| %><% card.with_header(user: @current_user) do %>Welcome<% end %><% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_with_slot_syntax_complex_nesting
    source = <<~EVC.strip
      <Navigation>
        <WithLink href={learning_path} text="Learning Path" />
        <WithLink href={courses_path} text="All Courses" />
        <WithLink text="Reports">
          <WithSublink href={reports_users_path} text="Users" />
          <WithSublink href={reports_activity_path} text="Activity" />
        </WithLink>
        <WithFooter>
          <div>Footer content</div>
        </WithFooter>
      </Navigation>
    EVC
    expected = <<~ERB.strip
      <%= render NavigationComponent.new do |navigation| %>
        <% navigation.with_link(href: learning_path, text: "Learning Path") %>
        <% navigation.with_link(href: courses_path, text: "All Courses") %>
        <% navigation.with_link(text: "Reports") do |link| %>
          <% link.with_sublink(href: reports_users_path, text: "Users") %>
          <% link.with_sublink(href: reports_activity_path, text: "Activity") %>
        <% end %>
        <% navigation.with_footer do %>
          <div>Footer content</div>
        <% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_boolean_attribute_shorthand
    source = "<Button disabled required />"
    expected = "<%= render ButtonComponent.new(disabled: true, required: true) %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_mixed_boolean_and_regular_attributes
    source = '<Button disabled size="lg" required />'
    expected = '<%= render ButtonComponent.new(disabled: true, size: "lg", required: true) %>'
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_boolean_with_ruby_expression_attributes
    source = "<Button disabled user={@current_user} required />"
    expected = "<%= render ButtonComponent.new(disabled: true, user: @current_user, required: true) %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_boolean_attribute_in_block_component
    source = "<Button disabled>Click me</Button>"
    expected = "<%= render ButtonComponent.new(disabled: true) do %>Click me<% end %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_fallback_cache_is_used_when_rails_cache_unavailable
    # Simulate Rails.cache being unavailable
    handler = EvcRails::TemplateHandlers::Evc.new
    class << handler
      def cache_store
        @fallback_cache ||= ActiveSupport::Cache::MemoryStore.new
      end
    end

    source = "<Button />"
    expected = "<%= render ButtonComponent.new %>"
    handler.cache_store.clear

    # First call should process and cache
    result1 = handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result1
    # Second call should use fallback cache
    result2 = handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result2
    # Fallback cache should have the entry
    keys = begin
      handler.cache_store.instance_variable_get(:@data).keys
    rescue StandardError
      []
    end
    assert keys.any?, "Fallback cache should have at least one entry"
  end

  def test_nested_component_accessing_parent_context
    source = <<~EVC.strip
      <Accordion>
        <WithTrigger>
          <Button>
            Click me <%= accordion.arrow %>
          </Button>
        </WithTrigger>
      </Accordion>
    EVC
    expected = <<~ERB.strip
      <%= render AccordionComponent.new do |accordion| %>
        <% accordion.with_trigger do %>
          <%= render ButtonComponent.new do %>
            Click me <%= accordion.arrow %>
          <% end %>
        <% end %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_slot_component_without_block
    source = <<~EVC.strip
      <Navigation>
        <WithLink path="/" text="Home" />
        <WithLink path="/pricing" text="Pricing" />
        <WithLink path="/sign-up" text="Sign Up" />
      </Navigation>
    EVC
    expected = <<~ERB.strip
      <%= render NavigationComponent.new do |navigation| %>
        <% navigation.with_link(path: "/", text: "Home") %>
        <% navigation.with_link(path: "/pricing", text: "Pricing") %>
        <% navigation.with_link(path: "/sign-up", text: "Sign Up") %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_plural_slot_with_array_notation
    source = <<~EVC.strip
      <Navigation as="navigation">
        <% navigation.with_links([
          { name: "Home", href: "/" },
          { name: "Pricing", href: "/pricing" },
          { name: "Sign Up", href: "/sign-up" }
        ]) %>
      </Navigation>
    EVC
    expected = <<~ERB.strip
      <%= render NavigationComponent.new do |navigation| %>
        <% navigation.with_links([
          { name: "Home", href: "/" },
          { name: "Pricing", href: "/pricing" },
          { name: "Sign Up", href: "/sign-up" }
        ]) %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_as_attribute_yields_block_variable_without_slot
    source = <<~EVC.strip
      <Navigation as="nav">
        <% nav.with_links([
          { name: "Home", href: "/" },
          { name: "Pricing", href: "/pricing" },
          { name: "Sign Up", href: "/sign-up" }
        ]) %>
      </Navigation>
    EVC
    expected = <<~ERB.strip
      <%= render NavigationComponent.new do |nav| %>
        <% nav.with_links([
          { name: "Home", href: "/" },
          { name: "Pricing", href: "/pricing" },
          { name: "Sign Up", href: "/sign-up" }
        ]) %>
      <% end %>
    ERB
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end

  def test_complex_array_and_hash_attribute
    source = "<Table column_widths={[30, 20, 20, 20, {width: 10, min_width_rem: 5.625}]} />"
    expected = "<%= render TableComponent.new(column_widths: [30, 20, 20, 20, {width: 10, min_width_rem: 5.625}]) %>"
    result = @handler.call(@template, source)
    assert_equal "ERB_COMPILED: #{expected}", result
  end
end
