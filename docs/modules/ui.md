---
title: UI Module
---

# UI Module

The UI module provides a comprehensive set of user interface components and layouts for Plutonium applications. Built on top of Phlex, it offers a component-based architecture with consistent theming, responsive design, and modern web interactions.

::: tip
The UI module is located in `lib/plutonium/ui/`.
:::

## Overview

- **Component-Based Architecture**: Phlex-powered components with automatic rendering.
- **Responsive Layouts**: Mobile-first responsive design patterns.
- **Theme System**: Consistent styling with dark mode support.
- **Modern Interactions**: Hotwire/Turbo integration for dynamic experiences.

## Core Architecture

### Component Base & Behaviour

All UI components inherit from `Plutonium::UI::Component::Base`, which is built on Phlex. It automatically includes `Plutonium::UI::Component::Behaviour`, providing shared functionality.

::: code-group
```ruby [Component Base]
# lib/plutonium/ui/component/base.rb
# All components inherit from this base class.
class Plutonium::UI::Component::Base < Phlex::HTML
  include Plutonium::UI::Component::Behaviour
end
```
```ruby [Component Behaviour]
# lib/plutonium/ui/component/behaviour.rb
# This concern provides shared logic.
module Plutonium::UI::Component::Behaviour
  extend ActiveSupport::Concern
  include Plutonium::UI::Component::Methods # Helper methods
  include Plutonium::UI::Component::Kit     # `render ComponentName(...)` syntax
  # ... and more
end
```
```ruby [Example Component]
class MyComponent < Plutonium::UI::Component::Base
  def initialize(title:)
    @title = title
  end

  def view_template
    div(class: "my-component") do
      h2 { @title }
    end
  end
end
```
:::

### Component Kit

The `ComponentKit` allows you to render components using a conventional `ComponentName(...)` syntax from within another component, which automatically builds and renders the component.

::: code-group
```ruby [Usage]
class MyView < Plutonium::UI::Component::Base
  def view_template
    # These methods automatically instantiate and render components
    # defined in the Kit.
    PageHeader(title: "Dashboard")
    Panel { "My panel content" }
  end
end
```
```ruby [Implementation]
# lib/plutonium/ui/component/kit.rb
module Plutonium::UI::Component::Kit
  # Uses method_missing to find a corresponding Build* method.
  def method_missing(method_name, *args, **kwargs, &block)
    build_method = "Build#{method_name}"
    if self.class.method_defined?(build_method)
      render send(build_method, *args, **kwargs, &block)
    else
      super
    end
  end

  # Builders are defined for all core UI components.
  def BuildPageHeader(...) = Plutonium::UI::PageHeader.new(...)
  def BuildPanel(...) = Plutonium::UI::Panel.new(...)
  # ... and many more
end
```
:::

## Layout System

Plutonium provides a flexible layout system built on Phlex components.

### Base Layout

The `Plutonium::UI::Layout::Base` class is the foundation for all layouts. It renders the `<html>`, `<head>`, and `<body>` tags and provides hooks for customization.

::: details Base Layout Structure
```ruby
class Plutonium::UI::Layout::Base < Plutonium::UI::Component::Base
  def view_template(&block)
    doctype
    html do
      render_head
      render_body(&block)
    end
  end

  def render_head
    head do
      render_title
      render_metatags # CSRF, CSP, Turbo
      render_assets   # CSS, JS, favicon
    end
  end

  def render_body(&block)
    body do
      render_before_main
      render_main(&block)
      render_after_main
    end
  end

  def render_main(&block)
    main do
      render_flash
      render_content(&block)
    end
  end
end
```
:::

### Specialized Layouts

Plutonium provides specialized layouts for different contexts.

::: code-group
```ruby [Resource Layout]
# lib/plutonium/ui/layout/resource_layout.rb
# Used for resource CRUD pages.
# Includes a fixed header and a sidebar.
class Plutonium::UI::Layout::ResourceLayout < Base
  def render_before_main
    render partial("resource_header")
    render partial("resource_sidebar")
  end
end
```
```ruby [Rodauth Layout]
# lib/plutonium/ui/layout/rodauth_layout.rb
# A centered layout for authentication pages (login, signup, etc.).
class Plutonium::UI::Layout::RodauthLayout < Base
  def render_main(&block)
    main(class: "flex flex-col items-center justify-center") do
      render_logo
      div(class: "w-full sm:max-w-md", &block)
    end
  end
end
```
:::

## Page Components

Page components structure the content within a layout.

::: code-group
```ruby [Base Page]
# lib/plutonium/ui/page/base.rb
# The foundation for all page components.
class Plutonium::UI::Page::Base < Plutonium::UI::Component::Base
  def initialize(page_title: nil, page_description: nil, page_actions: nil)
    # ...
  end

  def view_template(&block)
    PageHeader(
      title: -> { page_title },
      description: -> { page_description },
      actions: -> { page_actions }
    )
    render_default_content(&block)
  end
end
```
```ruby [Resource Index Page]
# lib/plutonium/ui/page/resource/index.rb
# Renders the main table for a resource index.
class Plutonium::UI::Page::Resource::Index < Base
  def render_default_content
    ResourceTable(
      records: @resource_records,
      pagy: @pagy
    )
  end
end
```
```ruby [Resource Form Page]
# lib/plutonium/ui/page/resource/form.rb
# Renders the form for a new/edit resource page.
class Plutonium::UI::Page::Resource::Form < Base
  def render_default_content
    ResourceForm(
      current_record,
      resource_definition: current_definition
    )
  end
end
```
:::

## Navigation Components

### Header (`lib/plutonium/ui/layout/header.rb`)

Responsive application header with brand and actions using Phlex::Slotable:

```ruby
class Plutonium::UI::Layout::Header < Base
  include Phlex::Slotable
  include Phlex::Rails::Helpers::Routes

  # Define slots for flexible content
  slot :brand_name
  slot :brand_logo
  slot :action, collection: true

  def view_template
    nav(
      class: "bg-white border-b border-gray-200 px-4 py-2.5 dark:bg-gray-800 dark:border-gray-700 fixed left-0 right-0 top-0 z-50",
      data: {
        controller: "resource-header",
        resource_header_sidebar_outlet: "#sidebar-navigation"
      }
    ) do
      div(class: "flex flex-wrap justify-between items-center") do
        render_brand_section
        render_actions if action_slots?
      end
    end
  end
end

# Usage
Header.new do |header|
  header.with_brand_logo { resource_logo_tag(classname: "h-10") }

  header.with_action do
    NavGridMenu.new(label: "Apps", icon: Phlex::TablerIcons::Apps) do |menu|
      menu.with_item(name: "Dashboard", icon: Phlex::TablerIcons::Dashboard, href: "/")
      menu.with_item(name: "Settings", icon: Phlex::TablerIcons::Settings, href: "/settings")
    end
  end

  header.with_action do
    NavUser.new(name: current_user.name, email: current_user.email) do |nav|
      nav.with_section do |section|
        section.with_link(label: "Profile", href: "/profile")
        section.with_link(label: "Sign out", href: logout_url)
      end
    end
  end
end
```

### Sidebar Menu (`lib/plutonium/ui/sidebar_menu.rb`)

Collapsible sidebar navigation with nested items:

```ruby
SidebarMenu.new(
  Phlexi::Menu::Builder.new do |m|
    m.item "Dashboard", url: root_path, icon: Phlex::TablerIcons::Home

    m.item "Resources", icon: Phlex::TablerIcons::GridDots do |submenu|
      registered_resources.each do |resource|
        submenu.item resource.model_name.human.pluralize,
                    url: resource_url_for(resource)
      end
    end

    m.item "Settings", icon: Phlex::TablerIcons::Settings do |submenu|
      submenu.item "General", url: "/settings"
      submenu.item "Users", url: "/settings/users"
    end
  end
)
```

### Breadcrumbs (`lib/plutonium/ui/breadcrumbs.rb`)

Hierarchical navigation breadcrumbs:

```ruby
# Automatic breadcrumb generation
class PostDefinition < Plutonium::Resource::Definition
  # Enable breadcrumbs globally
  breadcrumbs true

  # Or configure per-page
  show_page_breadcrumbs true
  edit_page_breadcrumbs false
end

# Manual breadcrumb usage
Breadcrumbs() # Automatically generates based on current context
```

### Tab List (`lib/plutonium/ui/tab_list.rb`)

Interactive tabbed interfaces:

```ruby
TabList(tabs: [
  { identifier: :details, title: "Details", block: -> { render_details } },
  { identifier: :settings, title: "Settings", block: -> { render_settings } },
  { identifier: :history, title: "History", block: -> { render_history } }
])
```

## Interactive Components

### DynaFrame Content (`lib/plutonium/ui/dyna_frame/content.rb`)

Turbo Frame wrapper for dynamic content updates:

```ruby
class Plutonium::UI::DynaFrame::Content < Plutonium::UI::Component::Base
  include Phlex::Rails::Helpers::TurboFrameTag

  def view_template
    if current_turbo_frame.present?
      turbo_frame_tag(current_turbo_frame) do
        render partial("flash")
        yield
      end
    else
      yield
    end
  end
end

# Usage
DynaFrameContent do
  # Content that can be dynamically updated
  render_form_or_content
end
```

### DynaFrame Host (`lib/plutonium/ui/dyna_frame/host.rb`)

Turbo Frame host component for lazy loading:

```ruby
class Plutonium::UI::DynaFrame::Host < Plutonium::UI::Component::Base
  include Phlex::Rails::Helpers::TurboFrameTag

  def initialize(src:, loading:, **attributes)
    @id = attributes.delete(:id) || SecureRandom.alphanumeric(8, chars: [*"a".."z"])
    @src = src
    @loading = loading
    @attributes = attributes
  end

  def view_template(&block)
    turbo_frame_tag(@id, src: @src, loading: @loading, **@attributes, class: "dyna", refresh: "morph", &block)
  end
end
```

### Action Button (`lib/plutonium/ui/action_button.rb`)

Consistent button styling for actions:

```ruby
ActionButton(action, url: post_path(@post), variant: :default)
ActionButton(action, url: edit_post_path(@post), variant: :table)

# Automatically handles:
# - GET vs POST requests
# - Confirmation dialogs
# - Turbo frame targeting
# - Icon and label rendering
```

## Form Components

### Enhanced Form Controls

Plutonium extends Phlexi forms with additional components:

```ruby
# International telephone input
field(:phone).int_tel_input_tag

# Rich text editor (EasyMDE)
field(:content).easymde_tag

# Date/time picker
field(:published_at).flatpickr_tag

# File upload with Uppy
field(:avatar).uppy_tag
```

### Form Integration

```ruby
class PostForm < Plutonium::UI::Form::Resource
  def form_template
    field(:title).input_tag(as: :string)
    field(:content).input_tag(as: :easymde)
    field(:published_at).input_tag(as: :flatpickr)
    field(:featured_image).input_tag(as: :uppy)
    field(:author_phone).input_tag(as: :int_tel_input)
  end
end
```

## Display Components

### Base Display (`lib/plutonium/ui/display/base.rb`)

Enhanced display components for showing data:

```ruby
class PostDisplay < Plutonium::UI::Display::Base
  def display_template
    field(:title).string_tag
    field(:content).markdown_tag
    field(:author).association_tag
    field(:attachments).attachment_tag

    # Custom component with block syntax
    field(:chart_data) do |f|
      if f.value.present?
        render ChartComponent.new(data: f.value, class: f.dom.css_class)
      else
        span(class: "text-gray-500") { "No chart data" }
      end
    end
  end
end
```

### Specialized Display Components

```ruby
# Markdown rendering
field(:description).markdown_tag

# Association display with links
field(:author).association_tag

# File attachment display
field(:documents).attachment_tag

# Custom component with conditional logic
field(:status) do |f|
  case f.value
  when 'active'
    span(class: "badge bg-green-100 text-green-800") { "Active" }
  when 'pending'
    span(class: "badge bg-yellow-100 text-yellow-800") { "Pending" }
  else
    render f.string_tag
  end
end
```

## Table Components

### Resource Tables

Tables with built-in pagination, sorting, and filtering:

```ruby
class PostTable < Plutonium::UI::Table::Resource
  def table_template
    column(:title).sortable
    column(:author).association
    column(:published_at).datetime.sortable
    column(:status).badge
    column(:actions).actions
  end
end
```

### Pagination (`lib/plutonium/ui/table/components/pagy_pagination.rb`)

Responsive pagination with Pagy integration:

```ruby
class Plutonium::UI::Table::Components::PagyPagination < Plutonium::UI::Component::Base
  include Pagy::Frontend

  def initialize(pagy)
    @pagy = pagy
  end

  def view_template
    nav(aria_label: "Page navigation", class: "flex justify-center mt-4") do
      ul(class: "inline-flex -space-x-px text-sm") do
        prev_link
        page_links
        next_link
      end
    end
  end
end

# Usage
PagyPagination.new(@pagy)
```

## Theme System

### Display Theme (`lib/plutonium/ui/display/theme.rb`)

Consistent styling across display components:

```ruby
class Plutonium::UI::Display::Theme < Phlexi::Display::Theme
  def self.theme
    super.merge({
      fields_wrapper: "p-6 grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-6 gap-y-10 grid-flow-row-dense",
      label: "text-base font-bold text-gray-500 dark:text-gray-400 mb-1",
      string: "text-md text-gray-900 dark:text-white mb-1 whitespace-pre-line",
      link: "text-primary-600 dark:text-primary-500 whitespace-pre-line",
      markdown: "format dark:format-invert format-primary",
      color_indicator: "w-10 h-10 rounded-full mr-2",
      json: "text-sm text-gray-900 dark:text-white mb-1 whitespace-pre font-mono shadow-inner p-4"
      # ... more theme definitions
    })
  end
end
```

### Component Theming

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def view_template
    div(class: themed(:wrapper)) do
      h2(class: themed(:title)) { @title }
      p(class: themed(:content)) { @content }
    end
  end

  private

  def theme
    {
      wrapper: "bg-white dark:bg-gray-800 p-6 rounded-lg shadow",
      title: "text-xl font-semibold text-gray-900 dark:text-white",
      content: "text-gray-600 dark:text-gray-300"
    }
  end
end
```

## Custom Components

### Creating Custom Components

```ruby
class CustomCard < Plutonium::UI::Component::Base
  def initialize(title:, variant: :default, **options)
    @title = title
    @variant = variant
    @options = options
  end

  def view_template(&block)
    div(class: card_classes) do
      header(class: "p-4 border-b") do
        h3(class: "text-lg font-semibold") { @title }
      end

      div(class: "p-4", &block)
    end
  end

  private

  def card_classes
    tokens(
      "bg-white dark:bg-gray-800 rounded-lg shadow",
      variant_classes
    )
  end

  def variant_classes
    case @variant
    when :success then "border-green-200 dark:border-green-700"
    when :warning then "border-yellow-200 dark:border-yellow-700"
    when :error then "border-red-200 dark:border-red-700"
    else "border-gray-200 dark:border-gray-700"
    end
  end
end

# Usage
CustomCard(title: "Success", variant: :success) do
  p { "Operation completed successfully!" }
end
```

### Component Registration

```ruby
# Register component for automatic rendering
class MyView < Plutonium::UI::Component::Base
  def BuildCustomCard(title:, **options)
    CustomCard.new(title: title, **options)
  end

  def view_template
    CustomCard(title: "Auto-rendered") do
      content
    end
  end
end
```
