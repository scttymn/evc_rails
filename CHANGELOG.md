# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2024-12-19

### Added

- **Kebab-case attribute support**: Support for HTML-style kebab-case attributes in addition to snake_case
  - `<Button data-test-id="value" />` converts to `data_test_id: "value"`
  - `<Button aria-label="Click me" />` converts to `aria_label: "Click me"`
  - Works with boolean attributes: `<Button data-disabled aria-hidden />`
  - Supports Ruby expressions: `<Button data-user-id={@user.id} />`
  - Fully backward compatible with existing snake_case attributes
  - Automatically converts kebab-case to snake_case for Ruby compatibility

## [0.3.1] - 2024-12-19

### Fixed

- **Robust attribute parsing**: Fixed a bug where complex or nested Ruby expressions (e.g., arrays or hashes with nested braces) in attribute values could cause parsing errors or incorrect output. The attribute parser is now fully robust and handles any valid Ruby expression inside `{...}` for both component and slot attributes.

## [0.3.0] - 2024-12-19

### Added

- **Enhanced slot nesting support**: Improved handling of deeply nested slots within components
- **Self-closing slot optimization**: Self-closing slots now render as method calls without blocks for better performance
- **Stack-based nesting logic**: More robust handling of complex nested component and slot structures

### Changed

- **Slot variable naming**: Improved slot variable naming by stripping `with_` prefix for cleaner block variables
- **Nested slot context**: Enhanced logic to ensure slots use the nearest component variable unless directly nested inside another slot

### Fixed

- **Block variable syntax**: Fixed Ruby block variable syntax to use `do |var|` instead of `|var| do`
- **Block variable yielding**: Corrected block variable yielding for complex nested structures
- **Slot method compatibility**: Ensured proper compatibility with ViewComponent's generated slot methods
- **Test suite improvements**: Updated all tests to reflect the new behavior and added comprehensive test coverage

## [0.2.3] - 2024-12-19

### Changed

- **Block variable yielding with `as`**: The block variable is now always yielded if the `as` attribute is present on a component tag, even if no `<With...>` slot tags are used inside the block. This makes advanced usage (such as calling plural slot methods directly) more ergonomic and predictable.
- **Documentation improvements**: Clarified the need for the `as` attribute when using plural slot methods with block variables, and improved wording for advanced usage in the README.
- **Test suite**: Added and updated tests to verify block variable yielding with `as` and to match the new behavior.

## [0.2.2] - 2024-12-19

### Added

- **Boolean attribute shorthand**: Support for HTML-style boolean attributes without values
  - `<Button disabled required />` now converts to `disabled: true, required: true`
  - Makes templates more concise and readable for boolean parameters
  - Works with any boolean parameter your component defines

### Changed

- Updated test suite to use new snake_case variable naming convention
- Improved block variable syntax consistency across all examples

## [0.2.1] - 2024-12-19

### Added

- **Custom block variable naming**: Support for `as` attribute to customize yielded variable names
  - `<Card as="my_card">` yields `|my_card|` instead of `|card|`
  - Helps avoid variable name collisions in nested components
  - Useful for accessing parent component context from nested components

### Changed

- **Block variable naming**: Components now yield snake_case variable names by default
  - `<Card>` now yields `|card|` instead of `|c|`
  - More descriptive and consistent with Ruby naming conventions
  - Only yields variables when slots are present in the component

### Fixed

- Improved slot method naming to match ViewComponent conventions
  - `<WithHeader>` maps to `with_header` method (not `header`)
  - `<WithItem>` maps to `with_item` method for both `renders_one` and `renders_many`
  - Ensures compatibility with ViewComponent's generated method names

## [0.2.0] - 2024-12-19

### Added

- **Slot support**: Full support for ViewComponent slots with `<With...>` syntax
  - `<WithHeader>` for `renders_one :header`
  - `<WithItem>` for `renders_many :items` (uses singular method name)
  - Support for slot attributes and Ruby expressions
  - Automatic block variable yielding when slots are present
- **Namespaced component support**: Components in subdirectories
  - `<UI::Button />` maps to `app/components/ui/button_component.rb`
  - `<Forms::Fields::TextField />` for deeply nested components
- **Enhanced error messages**: Line numbers and column positions for better debugging
- **Production caching**: Automatic template caching using Rails.cache
- **Cache management**: Methods to clear and inspect template cache

### Changed

- **Template handler architecture**: Improved performance and reliability
- **Error handling**: More descriptive error messages with context

## [0.1.0] - 2024-12-19

### Added

- **Initial release**: Basic JSX-like syntax for ViewComponent
- **Self-closing components**: `<Button />` syntax
- **Block components**: `<Card>content</Card>` syntax
- **Attribute support**: String, Ruby expressions, and multiple attributes
- **ERB integration**: Full support for ERB tags and Ruby expressions
- **Drop-in replacement**: Works as a replacement for `.erb` files
- **Basic caching**: Template compilation caching for performance

## Version History Notes

- **0.1.0**: Initial release with core functionality
- **0.2.0**: Major feature addition with slots and namespaced components
- **0.2.1**: Improved variable naming and slot method compatibility
- **0.2.2**: Added boolean attribute shorthand for cleaner templates
- **0.2.3**: Added block variable yielding with `as` attribute for more ergonomic advanced usage
- **0.3.0**: Enhanced slot nesting support and improved block variable handling for complex component structures
