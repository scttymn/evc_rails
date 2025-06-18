# EvcRails

EvcRails is a Rails gem that introduces a custom .evc template handler, allowing you to define your Rails View Components using a concise, HTML-like PascalCase tag syntax, reminiscent of React or other modern component-based UI frameworks. This gem seamlessly integrates your custom tags with Rails View Components, enabling a more declarative and readable approach to building UIs in Rails.

## Features

PascalCase Component Tags: Define and use your View Components with <MyComponent> or self-closing <MyComponent /> syntax directly in your .evc templates.

Attribute Handling: Pass attributes to your components using standard HTML-like key="value", key='value', or Ruby expressions key={@variable}.

Content Blocks: Components can accept content blocks (<MyComponent>content</MyComponent>) which are passed to the View Component via a block.

Automatic Component Resolution: Automatically appends "Component" to your tag name if it's not already present (e.g., <Button> resolves to ButtonComponent).

Performance Optimized: Includes in-memory caching of compiled templates and memoization of component class lookups for efficient rendering in production.

## Installation

Add this line to your application's Gemfile:

```
gem 'evc_rails'
```

And then execute:

```
bundle install
```

Or install it yourself as:

```
gem install evc_rails
```

## Usage

1. Create a View Component
   First, ensure you have a Rails View Component. For example, create app/components/my_component_component.rb:

```ruby
# app/components/my_component_component.rb
class MyComponentComponent < ViewComponent::Base
  def initialize(title:)
    @title = title
  end

  def call
    tag.div(class: "my-component") do
      concat tag.h2(@title)
      concat content # This renders the block content
    end
  end
end
```

And its associated template app/components/my_component_component.html.erb (if you're using separate templates):

```erb
<!-- app/components/my_component_component.html.erb -->
<div class="my-component">
  <h2><%= @title %></h2>
  <%= content %>
</div>
```

2. Create an .evc Template
   Now, create a template file with the .evc extension. For instance, app/views/pages/home.html.evc:

```erb
<!-- app/views/pages/home.html.evc -->
<h1>Welcome to My App</h1>

<MyComponent title="Hello World">
  <p>This is some content passed to the component.</p>
  <button text="Click Me" />
</MyComponent>

<%# A more concise way to render your DoughnutChartComponent %>
<DoughnutChart rings={@progress_data} />

<%# You can still use standard ERB within .evc files %>
<p><%= link_to "Go somewhere", some_path %></p>
```

3. Ensure Components are Autoloaded
   Make sure your app/components directory is eager-loaded in production. In config/application.rb or an initializer:

```ruby
# config/application.rb
config.eager_load_paths << Rails.root.join("app/components")
```

## How it Works

When Rails processes an .evc template, EvcRails intercepts it and performs the following transformations:

```erb
<MyComponent title="Hello World">... </MyComponent>
```

becomes:

```ruby
<%= render MyComponentComponent.new(title: "Hello World") do %>
  ... (processed content) ...
<% end %>
```

```erb
<%=<button text="Click Me" />
```

becomes:

```ruby
<%= render ButtonComponent.new(text: "Click Me") %>
```

```erb
<DoughnutChart rings={@progress_data} />
```

becomes:

```ruby
<%= render DoughnutChartComponent.new(rings: @progress_data) %>
```

`attr={@variable}` becomes `attr: @variable` in the new() call.

The transformed content is then passed to the standard ERB handler for final rendering.

## Configuration

Currently, EvcRails requires no specific configuration. Future versions might include options for:

Customizing the component suffix (e.g., if you don't want "Component" appended).

Defining custom component lookup paths.

## Contributing

Bug reports and pull requests are welcome on GitHub at [your-gem-repo-link]. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the MIT License

```

```
