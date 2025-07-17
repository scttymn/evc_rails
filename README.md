# EVC Rails

Embedded ViewComponents (EVC) is a Rails template handler that brings JSX-like syntax to ViewComponent, allowing you to write PascalCase component tags directly in your `.evc` templates.

## Table of Contents

- [Drop-in ERB Replacement](#drop-in-erb-replacement)
- [Works with Existing ViewComponents](#works-with-existing-viewcomponents)
- [Features](#features)
- [Installation](#installation)
- [Syntax Highlighting](#syntax-highlighting)
- [Usage](#usage)
  - [Basic Components](#basic-components)
  - [Self-Closing Components](#self-closing-components)
  - [Attributes](#attributes)
    - [String Attributes](#string-attributes)
    - [Ruby Expressions](#ruby-expressions)
    - [Multiple Attributes](#multiple-attributes)
    - [Kebab-case Attributes](#kebab-case-attributes)
  - [Namespaced Components](#namespaced-components)
  - [Slot Support](#slot-support)
    - [Slot Naming Convention](#slot-naming-convention)
    - [Attributes vs. Slots](#attributes-vs-slots)
    - [Boolean Attribute Shorthand](#boolean-attribute-shorthand)
    - [When a Block Variable is Yielded](#when-a-block-variable-is-yielded)
    - [Single Slots (`renders_one`)](#single-slots-renders_one)
    - [Self-Closing Slots](#self-closing-slots)
    - [Slot Attributes with Ruby Expressions](#slot-attributes-with-ruby-expressions)
    - [Multiple Slots (`renders_many`)](#multiple-slots-renders_many)
    - [Custom Variable Naming with `as`](#custom-variable-naming-with-as)
    - [Passing a Collection to a Plural Slot (Array Notation)](#passing-a-collection-to-a-plural-slot-array-notation)
    - [Complex Nested Slot Structures](#complex-nested-slot-structures)
  - [Mixed Content](#mixed-content)
- [Error Handling](#error-handling)
- [Caching](#caching)
  - [Cache Management](#cache-management)
- [Development](#development)
  - [Running Tests](#running-tests)
  - [Building the Gem](#building-the-gem)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [License](#license)

## Drop-in ERB Replacement

EVC templates are a **drop-in replacement** for `.erb` files. All ERB features are fully supported:

- `<%= %>` and `<% %>` tags
- Ruby expressions and control flow
- Helper methods (`link_to`, `form_with`, etc.)
- Partials (`<%= render 'partial' %>`)
- Layouts and content_for blocks

The template handler processes EVC syntax first, then passes the result to the standard ERB handler for final rendering.

[↑ Back to Table of Contents](#table-of-contents)

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

[↑ Back to Table of Contents](#table-of-contents)

## Features

- **JSX-like syntax** for ViewComponent tags
- **Self-closing components**: `<Button />`
- **Block components**: `<Container>content</Container>`
- **Attributes**: String, Ruby expressions, multiple attributes, and kebab-case support
- **Namespaced components**: `<UI::Button />`, `<Forms::Fields::TextField />`
- **Advanced slot support**: `<WithHeader>...</WithHeader>` with `renders_one` and `renders_many`, including complex nesting
- **Deep nesting**: Complex component hierarchies with proper block variable handling
- **Production-ready caching** with Rails.cache integration
- **Better error messages** with line numbers and column positions
- **Boolean attribute shorthand** for cleaner templates

[↑ Back to Table of Contents](#table-of-contents)

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

[↑ Back to Table of Contents](#table-of-contents)

## Syntax Highlighting

For the best development experience with EVC files, install the [EVC Language Support](https://github.com/senordelaflor/evc-language-support) extension for VS Code. This extension provides:

- **Syntax highlighting** for ERB tags (`<% %>`, `<%= %>`, `<%# %>`)
- **JSX-like attribute syntax** support (`prop={value}`)
- **Nested bracket matching** for arrays and hashes
- **HTML tag completion** via Emmet
- **Auto-closing pairs** for brackets and ERB tags
- **Proper folding** for ERB blocks

[↑ Back to Table of Contents](#table-of-contents)

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
<Card class="shadow-lg" data-test-id="featured-card" user={@user}>
  Content here
</Card>
```

#### Kebab-case Attributes

EVC supports both snake_case and kebab-case (hyphenated) attributes. Kebab-case attributes are automatically converted to snake_case for Ruby compatibility:

```erb
<Button data-test-id="my-button" aria-label="Click me" />
<Container data-test-container="wrapper" class="main">Hello World</Container>
```

Becomes:

```erb
<%= render ButtonComponent.new(data_test_id: "my-button", aria_label: "Click me") %>
<%= render ContainerComponent.new(data_test_container: "wrapper", class: "main") do %>
  Hello World
<% end %>
```

This works with:

- **String attributes**: `data-test-id="value"` → `data_test_id: "value"`
- **Boolean attributes**: `data-disabled aria-hidden` → `data_disabled: true, aria_hidden: true`
- **Ruby expressions**: `data-user-id={@user.id}` → `data_user_id: @user.id`
- **Mixed attributes**: `size="lg" data-test-id="value"` → `size: "lg", data_test_id: "value"`

Kebab-case attributes are fully backward compatible with existing snake_case attributes.

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

EVC provides a powerful and intuitive way to work with ViewComponent slots. To populate a slot, you use a corresponding `<With...>` tag that matches the **method name** provided by `renders_one` or `renders_many`.

When you use slots, EVC automatically makes the component's instance available in a block variable. By default, this variable is named after the component itself in snake_case (e.g., `<Accordion>` yields an `accordion` variable). This allows you to easily call component methods like `<%= accordion.arrow %>` from within the block. This variable is even available in deeply nested components, and you can provide a custom name to avoid ambiguity when nesting components of the same type.

#### Slot Naming Convention

The key to understanding slot tags in `evc_rails` is that they map directly to the **methods** generated by ViewComponent, not the `renders_...` declaration itself.

For both `renders_one` and `renders_many`, ViewComponent always generates a singular `with_*` method.

- `renders_one :header` provides a `with_header` method. You use `<WithHeader>`.
- `renders_many :items` provides a singular `with_item` method. You use the singular `<WithItem>` tag for each item you want to render.

This design provides maximum flexibility, allowing you to pass content as a block or make multiple self-closing calls, just like you would in standard ERB.

#### Attributes vs. Slots

There are two ways to pass information to a component:

- **As attributes:** Data passed as attributes on the main component tag (e.g. `<Card title="...">`) is sent to its `initialize` method.
- **As slot content:** Rich content passed via `<With...>` tags is used to populate the component's named slots.

#### Boolean Attribute Shorthand

You can use HTML-style boolean attributes in EVC. If you specify an attribute with no value, it will be passed as `true` to your component initializer. This makes templates more concise and readable:

```erb
<Button disabled required />
```

is equivalent to:

```erb
<%= render ButtonComponent.new(disabled: true, required: true) %>
```

This works for any boolean parameter your component defines.

#### When a Block Variable is Yielded

The contextual variable (e.g., `|card|`) is only yielded if one or more `<With...>` slot tags are present inside the component block. If you render a component like `<Card></Card>` with no slots inside, `evc_rails` is smart enough to render it without the `do |card|` part.

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
<%= render CardComponent.new do |card| %>
  <% card.with_header do %>
    <h1>Welcome</h1>
  <% end %>
  <% card.with_body do %>
    <p>This is the body content.</p>
  <% end %>
<% end %>
```

#### Self-Closing Slots

You can also use self-closing slot tags when you don't need to pass content:

```erb
<Card>
  <WithHeader />
  <WithBody>
    <p>This is the body content.</p>
  </WithBody>
</Card>
```

Becomes:

```erb
<%= render CardComponent.new do |card| %>
  <% card.with_header %>
  <% card.with_body do %>
    <p>This is the body content.</p>
  <% end %>
<% end %>
```

#### Slot Attributes with Ruby Expressions

Slots can accept attributes and Ruby expressions:

```erb
<Card>
  <WithHeader user={@current_user} class="welcome-header">
    Welcome, <%= @current_user.name %>
  </WithHeader>
</Card>
```

Becomes:

```erb
<%= render CardComponent.new do |card| %>
  <% card.with_header(user: @current_user, class: "welcome-header") do %>
    Welcome, <%= @current_user.name %>
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
  <% @todo_items.each do |item| %>
    <WithItem>
      <span class="<%= item.completed? ? 'line-through' : '' %>">
        <%= item.title %>
      </span>
    </WithItem>
  <% end %>
</List>
```

Becomes:

```erb
<%= render ListComponent.new do |list| %>
  <% @todo_items.each do |item| %>
    <% list.with_item do %>
      <span class="<%= item.completed? ? 'line-through' : '' %>">
        <%= item.title %>
      </span>
    <% end %>
  <% end %>
<% end %>
```

#### Custom Variable Naming with `as`

For clarity or to resolve ambiguity when nesting components of the same type, you can provide a custom variable name with the `as` attribute.

```ruby
# app/components/card_component.rb
class CardComponent < ViewComponent::Base
  renders_one :header

  attr_reader :title

  def initialize(title: "Default Title")
    @title = title
  end
end
```

```erb
<Card as="outer_card" title="Outer Card">
  <WithHeader>
    <h2><%= outer_card.title %></h2>
    <Card as="inner_card" title="Inner Card">
      <WithHeader>
        <h3><%= inner_card.title %></h3>
        <p>Outer card title from inner scope: <%= outer_card.title %></p>
      </WithHeader>
    </Card>
  </WithHeader>
</Card>
```

This generates distinct variables, `outer_card` and `inner_card`, allowing you to access the context of each component without collision.

#### Passing a Collection to a Plural Slot (Array Notation)

You can also pass an array directly to a plural slot method using embedded Ruby inside your EVC template. For this advanced use case, block variables are not inferred automatically and it is necessary to define block variables with the `as` attribute.

```erb
<Navigation as="navigation">
  <% navigation.with_links([
    { name: "Home", href: "/" },
    { name: "Pricing", href: "/pricing" },
    { name: "Sign Up", href: "/sign-up" }
  ]) %>
</Navigation>
```

This is equivalent to the ERB version:

```erb
<%= render NavigationComponent.new do |navigation| %>
  <% navigation.with_links([
    { name: "Home", href: "/" },
    { name: "Pricing", href: "/pricing" },
    { name: "Sign Up", href: "/sign-up" }
  ]) %>
<% end %>
```

You can use this approach for any plural slot method generated by `renders_many`. The block variable (e.g., `navigation`) is always available inside the component block when you use the `as` attribute, even if there are no `<With...>` slot tags present.

#### Complex Nested Slot Structures

EVC handles complex nested slot structures with proper block variable scoping:

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

Becomes:

```erb
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
```

This demonstrates how EVC properly handles nested slots with correct block variable scoping - the inner `WithSublink` slots use the `link` variable from their parent `WithLink` slot.

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

[↑ Back to Table of Contents](#table-of-contents)

## Error Handling

The template handler provides detailed error messages with line numbers and column positions:

```

ArgumentError: Unmatched closing tag </Button> at line 15, column 8
ArgumentError: Unclosed tag <Card> at line 10, column 1
ArgumentError: No matching opening tag for </Container> at line 20, column 5

```

[↑ Back to Table of Contents](#table-of-contents)

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

[↑ Back to Table of Contents](#table-of-contents)

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

[↑ Back to Table of Contents](#table-of-contents)
