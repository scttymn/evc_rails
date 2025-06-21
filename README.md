# EVC Rails

Embedded ViewComponents (EVC) is a Rails template handler that brings JSX-like syntax to ViewComponent, allowing you to write PascalCase component tags directly in your `.evc` templates.

## Drop-in ERB Replacement

EVC templates are a **drop-in replacement** for `.erb` files. All ERB features are fully supported:

- `<%= %>` and `<% %>` tags
- Ruby expressions and control flow
- Helper methods (`link_to`, `form_with`, etc.)
- Partials (`<%= render 'partial' %>`)
- Layouts and content_for blocks

The template handler processes EVC syntax first, then passes the result to the standard ERB handler for final rendering.

## Works with Existing ViewComponents

EVC works seamlessly with **any ViewComponents you already have** in `app/components`. Simply install the gem and start using easier syntax:

```ruby
# Your existing ViewComponent (no changes needed)
class ButtonComponent < ViewComponent::Base
  def initialize(variant: "default", size: "md")
    @variant = variant
    @size = size
  end
end
```

```erb
<!-- Now you can use it with EVC syntax -->
<Button variant="primary" size="lg">Click me</Button>
```

No component modifications required - just install and enjoy easier syntax!

## Features

- **JSX-like syntax** for ViewComponent tags
- **Self-closing components**: `<Button />`
- **Block components**: `<Container>content</Container>`
- **Attributes**: String, Ruby expressions, and multiple attributes
- **Namespaced components**: `<UI::Button />`, `<Forms::Fields::TextField />`
- **Slot support**: `<Card::Header>...</Card::Header>` with `renders_one` and `renders_many`
- **Deep nesting**: Complex component hierarchies
- **Production-ready caching** with Rails.cache integration
- **Better error messages** with line numbers and column positions

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'evc_rails'
```

And then execute:

```bash
$ bundle install
```

The template handler will be automatically registered for `.evc` files.

## Usage

### Basic Components

Create `.evc` files in your `app/views` directory:

```erb
<!-- app/views/pages/home.evc -->
<h1>Welcome to our app</h1>

<Button size="lg" variant="primary">Get Started</Button>

<Card>
  <h2>Featured Content</h2>
  <p>This is some amazing content.</p>
</Card>
```

This becomes:

```erb
<h1>Welcome to our app</h1>

<%= render ButtonComponent.new(size: "lg", variant: "primary") do %>
  Get Started
<% end %>

<%= render CardComponent.new do %>
  <h2>Featured Content</h2>
  <p>This is some amazing content.</p>
<% end %>
```

### Self-Closing Components

```erb
<Button />
<Icon name="star" />
<Spacer height="20" />
```

Becomes:

```erb
<%= render ButtonComponent.new %>
<%= render IconComponent.new(name: "star") %>
<%= render SpacerComponent.new(height: "20") %>
```

### Attributes

#### String Attributes

```erb
<Button size="lg" variant="primary" />
```

#### Ruby Expressions

```erb
<Button user={@current_user} count={@items.count} />
```

#### Multiple Attributes

```erb
<Card class="shadow-lg" data-testid="featured-card" user={@user}>
  Content here
</Card>
```

### Namespaced Components

Organize your components in subdirectories:

```erb
<UI::Button size="lg" />
<Forms::Fields::TextField value={@email} />
<Layout::Container class="max-w-4xl">
  <UI::Card>Content</UI::Card>
</Layout::Container>
```

This maps to:

- `app/components/ui/button_component.rb`
- `app/components/forms/fields/text_field_component.rb`
- `app/components/layout/container_component.rb`

### Slot Support

#### Single Slots (`renders_one`)

```ruby
# app/components/card_component.rb
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
end
```

```erb
<Card>
  <WithHeader>
    <h1>Welcome</h1>
  </WithHeader>
  <WithBody>
    <p>This is the body content.</p>
  </WithBody>
</Card>
```

Becomes:

```erb
<%= render CardComponent.new do |c| %>
  <% c.header do %>
    <h1>Welcome</h1>
  <% end %>
  <% c.body do %>
    <p>This is the body content.</p>
  <% end %>
<% end %>
```

#### Multiple Slots (`renders_many`)

```ruby
# app/components/list_component.rb
class ListComponent < ViewComponent::Base
  renders_many :items
end
```

```erb
<List>
  <WithItem>Item 1</WithItem>
  <WithItem>Item 2</WithItem>
  <WithItem>Item 3</WithItem>
</List>
```

Becomes:

```erb
<%= render ListComponent.new do |c| %>
  <% c.item do %>Item 1<% end %>
  <% c.item do %>Item 2<% end %>
  <% c.item do %>Item 3<% end %>
<% end %>
```

#### Complex Slot Examples

```erb
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
```

#### Backward Compatibility

The old `Component::slotname` syntax is still supported for backward compatibility:

```erb
<Card>
  <Card::header>Title</Card::header>
  <Card::body>Content</Card::body>
</Card>
```

### Complex Nesting

```erb
<UI::Card>
  <h2 class="text-2xl font-semibold">Dashboard</h2>

  <UI::Grid cols="3" gap="md">
    <UI::Card shadow="sm">
      <p class="text-center">Widget 1</p>
    </UI::Card>
    <UI::Card shadow="sm">
      <p class="text-center">Widget 2</p>
    </UI::Card>
    <UI::Card shadow="sm">
      <p class="text-center">Widget 3</p>
    </UI::Card>
  </UI::Grid>
</UI::Card>
```

### Mixed Content

You can mix regular HTML, ERB, and component tags:

```erb
<div class="container">
  <h1><%= @page.title %></h1>

  <% if @show_featured %>
  <FeaturedCard />
  <% end %>

  <div class="grid">
    <% @posts.each do |post| %>
    <PostCard post={post} />
    <% end %>
  </div>
</div>
```

## Error Handling

The template handler provides detailed error messages with line numbers and column positions:

```
ArgumentError: Unmatched closing tag </Button> at line 15, column 8
ArgumentError: Unclosed tag <Card> at line 10, column 1
ArgumentError: No matching opening tag for </Container> at line 20, column 5
```

## Caching

Templates are automatically cached in production environments using `Rails.cache`. The cache is keyed by template identifier and source content hash, ensuring cache invalidation when templates change.

### Cache Management

Clear the template cache:

```ruby
Rails.cache.clear
```

Or clear specific template patterns:

```ruby
Rails.cache.delete_matched("evc_rails_template:*")
```

## Development

### Running Tests

```bash
bundle exec ruby test/unit/template_handler_test.rb
```

### Building the Gem

```bash
gem build evc_rails.gemspec
```

## Requirements

- Rails 6.0+
- Ruby 3.1+
- ViewComponent 2.0+

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
