---
title: Display Module
---

# Display Module

The Display module provides a comprehensive system for rendering and displaying data values in Plutonium applications. Built on top of `Phlexi::Display`, it offers specialized components for different data types, consistent theming, and intelligent value rendering.

::: tip
The Display module is located in `lib/plutonium/ui/display/`.
:::

## Overview

- **Value Rendering**: Intelligent rendering of different data types.
- **Specialized Components**: Purpose-built components for associations, attachments, markdown, etc.
- **Theme System**: Consistent styling across all display components.
- **Type Inference**: Automatic component selection based on data types.
- **Resource Integration**: Seamless integration with resource definitions.
- **Responsive Design**: Mobile-first responsive display layouts.

## Core Components

### Base Display (`lib/plutonium/ui/display/base.rb`)

This is the foundation that all display components inherit from. It extends `Phlexi::Display::Base` with Plutonium's specific behaviors and custom display components.

::: details Base Display Implementation
```ruby
class Plutonium::UI::Display::Base < Phlexi::Display::Base
  include Plutonium::UI::Component::Behaviour

  # Enhanced builder with Plutonium-specific components
  class Builder < Builder
    include Plutonium::UI::Display::Options::InferredTypes

    def association_tag(**options, &block)
      create_component(Plutonium::UI::Display::Components::Association, :association, **options, &block)
    end

    def markdown_tag(**options, &block)
      create_component(Plutonium::UI::Display::Components::Markdown, :markdown, **options, &block)
    end

    def attachment_tag(**options, &block)
      create_component(Plutonium::UI::Display::Components::Attachment, :attachment, **options, &block)
    end

    def phlexi_render_tag(**options, &block)
      create_component(Plutonium::UI::Display::Components::PhlexiRender, :phlexi_render, **options, &block)
    end
  end
end
```
:::

### Resource Display (`lib/plutonium/ui/display/resource.rb`)

This is a specialized component for displaying resource objects, automatically rendering fields and associations based on the resource's definition.

```ruby
class PostDisplay < Plutonium::UI::Display::Resource
  def initialize(post, resource_fields:, resource_associations:, resource_definition:)
    super(
      post,
      resource_fields: resource_fields,
      resource_associations: resource_associations,
      resource_definition: resource_definition
    )
  end

  def display_template
    render_fields      # Render configured fields
    render_associations if present_associations?  # Render associations
  end
end
```

## Display Components

### Association Component

Renders associated objects with automatic linking to the resource's show page if it's a registered resource.

::: code-group
```ruby [Usage]
# Automatically used for association fields
field(:author).association_tag
```
```ruby [Implementation]
class Plutonium::UI::Display::Components::Association
  def render_value(value)
    if registered_resources.include?(value.class)
      # Create link to resource
      href = resource_url_for(value, parent: appropriate_parent)
      a(class: themed(:link), href: href) { display_name_of(value) }
    else
      # Plain text display
      display_name_of(value)
    end
  end
end
```
:::

### Attachment Component

Provides a rich display for file attachments with thumbnails for images and icons for other file types.

::: code-group
```ruby [Basic Usage]
# Automatically used for attachment fields
field(:featured_image).attachment_tag
```
```ruby [With Options]
field(:documents).attachment_tag(caption: false)
field(:gallery).attachment_tag(
  caption: ->(attachment) { attachment.description }
)
```
:::

::: details Attachment Component Implementation
```ruby
class Plutonium::UI::Display::Components::Attachment
  def render_value(attachment)
    div(
      class: "attachment-preview",
      data: {
        controller: "attachment-preview",
        attachment_preview_mime_type_value: attachment.content_type,
        attachment_preview_thumbnail_url_value: attachment_thumbnail_url(attachment)
      }
    ) do
      render_thumbnail(attachment)    # Image or file type icon
      render_caption(attachment)      # Filename or custom caption
    end
  end

  private

  def render_thumbnail(attachment)
    if attachment.representable?
      img(src: attachment_thumbnail_url(attachment), class: "w-full h-full object-cover")
    else
      # File type icon
      div(class: "file-icon") { ".#{attachment_extension(attachment)}" }
    end
  end
end
```
:::

### Markdown Component

Securely renders markdown content with syntax highlighting for code blocks.

::: code-group
```ruby [Usage]
# Automatically used for :markdown fields
field(:description).markdown_tag
```
```ruby [Implementation]
class Plutonium::UI::Display::Components::Markdown
  RENDERER = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(
      safe_links_only: true,
      with_toc_data: true,
      hard_wrap: true,
      link_attributes: { rel: :nofollow, target: :_blank }
    ),
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    footnotes: true
  )

  def render_value(value)
    article(class: themed(:markdown)) do
      raw(safe(render_markdown(value)))
    end
  end
end
```
:::

### PhlexiRender Component

Renders a given value using a custom Phlex component, allowing for complex, specialized displays.

::: code-group
```ruby [Usage]
# Render with a new component instance
field(:chart_data).phlexi_render_tag(with: ->(data, attrs) {
  ChartComponent.new(data: data, **attrs)
})

# Render with a component class
field(:status_badge).phlexi_render_tag(with: StatusBadgeComponent)
```
```ruby [Implementation]
class Plutonium::UI::Display::Components::PhlexiRender
  def render_value(value)
    phlexi_render(build_phlexi_component(value)) do
      # Fallback rendering if component fails
      p(class: themed(:string)) { value }
    end
  end

  private

  def build_phlexi_component(value)
    @builder.call(value, attributes)
  end
end
```
:::

## Type Inference

The display system automatically selects the appropriate component based on the field's type, but you can always override it manually.

::: code-group
```ruby [Automatic Inference]
# Based on Active Record column types or Active Storage attachments
field(:title)          # -> :string
field(:content)        # -> :text
field(:published_at)   # -> :datetime
field(:author)         # -> :association
field(:featured_image) # -> :attachment
field(:description)    # -> :markdown (if configured in definition)
```
```ruby [Manual Override]
field(:title).string_tag
field(:content).markdown_tag
field(:author).association_tag
```
:::

::: details Type Mapping Implementation
```ruby
module Plutonium::UI::Display::Options::InferredTypes
  private

  def infer_field_component
    case inferred_field_type
    when :attachment
      :attachment
    when :association
      :association
    when :boolean
      :boolean
    # ... and so on for all standard types
    else
      :string
    end
  end
end
```
:::

## Theme System

### Display Theme (`lib/plutonium/ui/display/theme.rb`)

Comprehensive theming for consistent visual appearance:

```ruby
class Plutonium::UI::Display::Theme < Phlexi::Display::Theme
  def self.theme
    super.merge({
      # Layout
      fields_wrapper: "p-6 grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-6 gap-y-10 grid-flow-row-dense",
      value_wrapper: "max-h-[300px] overflow-y-auto",

      # Typography
      label: "text-base font-bold text-gray-500 dark:text-gray-400 mb-1",
      string: "text-md text-gray-900 dark:text-white mb-1 whitespace-pre-line",
      text: "text-md text-gray-900 dark:text-white mb-1 whitespace-pre-line",

      # Interactive elements
      link: "text-primary-600 dark:text-primary-500 whitespace-pre-line",
      email: "flex items-center text-md text-primary-600 dark:text-primary-500 mb-1",
      phone: "flex items-center text-md text-primary-600 dark:text-primary-500 mb-1",

      # Special content
      markdown: "format dark:format-invert format-primary",
      json: "text-sm text-gray-900 dark:text-white mb-1 whitespace-pre font-mono shadow-inner p-4",

      # Attachments
      attachment_value_wrapper: "grid grid-cols-[repeat(auto-fill,minmax(0,180px))]",

      # Colors
      color: "flex items-center text-md text-gray-900 dark:text-white mb-1",
      color_indicator: "w-10 h-10 rounded-full mr-2"
    })
  end
end
```

### Table Display Theme (`lib/plutonium/ui/table/display_theme.rb`)

Specialized theming for table contexts:

```ruby
class Plutonium::UI::Table::DisplayTheme < Phlexi::Table::DisplayTheme
  def self.theme
    super.merge({
      # Compact display for tables
      value_wrapper: "max-h-[150px] overflow-y-auto",
      prefixed_icon: "w-4 h-4 mr-1",

      # Table-specific styles
      email: "flex items-center text-primary-600 dark:text-primary-500 whitespace-nowrap",
      phone: "flex items-center text-primary-600 dark:text-primary-500 whitespace-nowrap",
      attachment_value_wrapper: "flex flex-wrap gap-1"
    })
  end
end
```

## Usage Patterns

### Basic Display

```ruby
# Simple field display
class PostDisplay < Plutonium::UI::Display::Base
  def display_template
    field(:title).string_tag
    field(:content).text_tag
    field(:published_at).datetime_tag
    field(:author).association_tag
  end
end
```

### Resource Display

```ruby
# Automatic resource display based on definition
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])
    @display = Plutonium::UI::Display::Resource.new(
      @post,
      resource_fields: current_definition.defined_displays.keys,
      resource_associations: [],
      resource_definition: current_definition
    )
  end
end

# In view
<%= render @display %>
```

### Custom Display Components

```ruby
# Create custom display component
class StatusBadgeComponent < Plutonium::UI::Component::Base
  def initialize(status, **options)
    @status = status
    @options = options
  end

  def view_template
    span(class: badge_classes) { @status.humanize }
  end

  private

  def badge_classes
    base_classes = "px-2 py-1 text-xs font-medium rounded-full"
    case @status
    when 'active'
      "#{base_classes} bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"
    when 'inactive'
      "#{base_classes} bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"
    else
      "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300"
    end
  end
end

# Use in display
field(:status).phlexi_render_tag(with: StatusBadgeComponent)
```

### Conditional Display

You can conditionally show or hide display fields using the `:condition` option in your resource definition. This is useful for creating dynamic views that adapt to the state of your data.

**Note:** Conditional display is for cosmetic or state-based logic. For controlling data visibility based on user roles or permissions, use **policies**.

```ruby
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # Show a field only when the object is in a certain state.
  display :published_at, condition: -> { object.published? }
  display :reason_for_rejection, condition: -> { object.rejected? }
  display :scheduled_for, condition: -> { object.scheduled? }

  # Show a field based on the object's attributes.
  display :comments, condition: -> { object.comments_enabled? }

  # Show debug information only in development.
  display :debug_info, condition: -> { Rails.env.development? }
end
```

::: tip Condition Context
`condition` procs for `display` fields are evaluated in the display rendering context, which means they have access to:
- `object` - The record being displayed
- All helper methods available in the display context

This allows for dynamic field visibility based on the record's state or other contextual information.
:::

You can also implement custom conditional logic by overriding the rendering methods:

```ruby
class PostDisplay < Plutonium::UI::Display::Resource
  private

  def render_resource_field(name)
    # Only render if user has permission
    when_permitted(name) do
      # Get field and display options from definition
      field_options = resource_definition.defined_fields[name]&.dig(:options) || {}
      display_definition = resource_definition.defined_displays[name] || {}
      display_options = display_definition[:options] || {}

      # Render field with appropriate component
      field(name, **field_options).wrapped(**wrapper_options) do |f|
        render_field_component(f, display_options)
      end
    end
  end

  def when_permitted(name, &block)
    return unless @resource_fields.include?(name)
    return unless policy_allows_field?(name)

    yield
  end
end
```

### Responsive Layouts

```ruby
# Grid layout with responsive columns
class PostDisplay < Plutonium::UI::Display::Base
  private

  def fields_wrapper(&block)
    div(class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6") do
      yield
    end
  end
end

# Full-width fields
field(:description).wrapped(class: "col-span-full") do |f|
  f.markdown_tag
end

# Compact display
field(:tags).wrapped(class: "col-span-1") do |f|
  f.collection_tag
end
```

## Helper Integration

### Display Helpers (`lib/plutonium/helpers/display_helper.rb`)

Rich helper methods for value formatting:

```ruby
module Plutonium::Helpers::DisplayHelper
  # Generic field display with helper support
  def display_field(value:, helper: nil, **options)
    return "-" unless value.present?

    if value.respond_to?(:each) && stack_multiple
      # Handle collections
      tag.ul(class: "list-unstyled") do
        value.each do |val|
          concat tag.li(display_field_value(value: val, helper: helper))
        end
      end
    else
      display_field_value(value: value, helper: helper, **options)
    end
  end

  # Specialized display methods
  def display_association_value(association)
    display_name = display_name_of(association)
    if registered_resources.include?(association.class)
      link_to display_name, resource_url_for(association),
              class: "font-medium text-primary-600 dark:text-primary-500"
    else
      display_name
    end
  end

  def display_datetime_value(value)
    timeago(value)
  end

  def display_boolean_value(value)
    tag.input(type: :checkbox, checked: value, disabled: true)
  end

  def display_name_of(obj, separator: ", ")
    return unless obj.present?
    return obj.map { |i| display_name_of(i) }.join(separator) if obj.is_a?(Array)

    # Try common display methods
    %i[to_label name title].each do |method|
      name = obj.public_send(method) if obj.respond_to?(method)
      return name if name.present?
    end

    # Fallback for Active Record objects
    return "#{resource_name(obj.class)} ##{obj.id}" if obj.respond_to?(:id)

    obj.to_s
  end
end
```

## Advanced Features

### Attachment Previews

```ruby
# Automatic attachment preview with JavaScript enhancement
field(:documents).attachment_tag

# Generates:
# - Thumbnail images for representable files
# - File type indicators for non-representable files
# - Click-to-preview functionality
# - Download links
# - Responsive grid layout

# JavaScript controller provides:
# - Preview modal/lightbox
# - Keyboard navigation
# - Touch/swipe support
# - Loading states
```

### Markdown Processing

```ruby
# Secure markdown with custom renderer
class CustomMarkdownRenderer < Redcarpet::Render::HTML
  def initialize(options = {})
    super(options.merge(
      safe_links_only: true,
      with_toc_data: true,
      hard_wrap: true,
      link_attributes: { rel: :nofollow, target: :_blank }
    ))
  end

  def block_code(code, language)
    # Custom syntax highlighting
    "<pre><code class=\"language-#{language}\">#{highlight_code(code, language)}</code></pre>"
  end
end

# Use custom renderer
CUSTOM_RENDERER = Redcarpet::Markdown.new(
  CustomMarkdownRenderer.new,
  autolink: true,
  tables: true,
  fenced_code_blocks: true
)
```

### Performance Optimizations

```ruby
# Lazy loading for expensive displays
class PostDisplay < Plutonium::UI::Display::Base
  def display_template
    field(:title).string_tag

    # Only render associations if not in turbo frame
    if current_turbo_frame.nil?
      field(:comments_count).number_tag
      field(:recent_comments).collection_tag
    end
  end
end

# Conditional rendering based on permissions
def render_resource_field(name)
  return unless authorized_to_view_field?(name)

  # Cache expensive field computations
  @field_cache ||= {}
  @field_cache[name] ||= compute_field_display(name)

  render @field_cache[name]
end
```

## Testing

### Component Testing

```ruby
RSpec.describe Plutonium::UI::Display::Components::Association do
  let(:user) { create(:user, name: "John Doe") }
  let(:component) { described_class.new(field_for(user, :author)) }

  context "when association is a registered resource" do
    before { allow(component).to receive(:registered_resources).and_return([User]) }

    it "renders a link to the resource" do
      html = render(component)
      expect(html).to include('href="/users/')
      expect(html).to include("John Doe")
    end
  end

  context "when association is not registered" do
    before { allow(component).to receive(:registered_resources).and_return([]) }

    it "renders plain text" do
      html = render(component)
      expect(html).not_to include('href=')
      expect(html).to include("John Doe")
    end
  end
end
```

### Integration Testing

```ruby
RSpec.describe "Display Integration", type: :system do
  let(:post) { create(:post, :with_attachments, :with_author) }

  it "displays all field types correctly" do
    visit post_path(post)

    # Text fields
    expect(page).to have_content(post.title)
    expect(page).to have_content(post.content)

    # Associations
    expect(page).to have_link(post.author.name, href: user_path(post.author))

    # Attachments
    expect(page).to have_css(".attachment-preview")
    expect(page).to have_link(href: rails_blob_path(post.featured_image))

    # Timestamps
    expect(page).to have_content("ago") # timeago formatting
  end

  it "handles responsive layout" do
    visit post_path(post)

    # Desktop layout
    expect(page).to have_css(".md\\:grid-cols-2")

    # Mobile layout (resize viewport)
    page.driver.browser.manage.window.resize_to(375, 667)
    expect(page).to have_css(".grid-cols-1")
  end
end
```

## Best Practices

### Component Design

1. **Single Responsibility**: Each component should handle one display type
2. **Consistent API**: Follow the same patterns for all display components
3. **Theme Integration**: Use themed classes for consistent styling
4. **Accessibility**: Include proper ARIA attributes and semantic HTML
5. **Performance**: Avoid expensive operations in render methods

### Value Processing

1. **Null Safety**: Always handle nil/empty values gracefully
2. **Type Checking**: Verify value types before processing
3. **Sanitization**: Sanitize user-generated content (especially HTML/markdown)
4. **Formatting**: Use consistent formatting for dates, numbers, etc.
5. **Localization**: Support internationalization for display text

### Responsive Design

1. **Mobile First**: Design for mobile, enhance for desktop
2. **Flexible Layouts**: Use CSS Grid/Flexbox for adaptive layouts
3. **Content Priority**: Show most important content first on small screens
4. **Touch Friendly**: Ensure interactive elements are touch-accessible
5. **Performance**: Optimize images and assets for different screen sizes

### Security

1. **Input Sanitization**: Always sanitize user-generated content
2. **XSS Prevention**: Use safe HTML rendering methods
3. **Link Security**: Add `rel="nofollow"` to user-generated links
4. **File Security**: Validate file types and sizes for attachments
5. **Permission Checks**: Verify user permissions before displaying sensitive data
