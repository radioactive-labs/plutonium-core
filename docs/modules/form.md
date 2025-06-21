---
title: Form Module
---

# Form Module

The Form module provides a comprehensive form building system for Plutonium applications. Built on top of `Phlexi::Form`, it offers enhanced input components, automatic field inference, secure associations, and modern UI interactions for creating rich, accessible forms.

::: tip
The Form module is located in `lib/plutonium/ui/form/`.
:::

## Overview

- **Enhanced Input Components**: Rich input types with JavaScript integration.
- **Secure Associations**: SGID-based association handling with authorization.
- **Type Inference**: Automatic component selection based on field types.
- **Resource Integration**: Seamless integration with resource definitions.
- **Modern UI**: File uploads, date pickers, rich text editors, and more.
- **Accessibility**: ARIA-compliant forms with keyboard navigation.

## Core Components

### Base Form (`lib/plutonium/ui/form/base.rb`)

This is the foundation that all Plutonium form components inherit from. It extends `Phlexi::Form::Base` with Plutonium's specific behaviors and custom input components.

::: details Base Form Implementation
```ruby
class Plutonium::UI::Form::Base < Phlexi::Form::Base
  include Plutonium::UI::Component::Behaviour

  # Enhanced builder with Plutonium-specific components
  class Builder < Builder
    include Plutonium::UI::Form::Options::InferredTypes

    def easymde_tag(**options, &block)
      create_component(Plutonium::UI::Form::Components::Easymde, :easymde, **options, &block)
    end
    alias_method :markdown_tag, :easymde_tag

    def flatpickr_tag(**options, &block)
      create_component(Components::Flatpickr, :flatpickr, **options, &block)
    end

    def uppy_tag(**options, &block)
      create_component(Components::Uppy, :uppy, **options, &block)
    end
    alias_method :file_tag, :uppy_tag
    alias_method :attachment_tag, :uppy_tag

    def secure_association_tag(**attributes, &block)
      create_component(Components::SecureAssociation, :association, **attributes, &block)
    end

    # Override default association methods to use secure versions
    alias_method :belongs_to_tag, :secure_association_tag
    alias_method :has_many_tag, :secure_association_tag
    alias_method :has_one_tag, :secure_association_tag
  end
end
```
:::

### Resource Form (`lib/plutonium/ui/form/resource.rb`)

This is a specialized form for resource objects that automatically renders fields based on the resource's definition, handling nested resources and actions gracefully.

```ruby
class PostForm < Plutonium::UI::Form::Resource
  def initialize(post, resource_definition:)
    super(post, resource_definition: resource_definition)
  end

  def form_template
    render_resource_fields    # Render configured input fields
    render_nested_resources   # Render nested associations
    render_actions           # Render submit/cancel buttons
  end
end
```

## Enhanced Input Components

### Rich Text Editor (Easymde)

A client-side markdown editor with live preview, based on [EasyMDE](https://github.com/Ionaru/easy-markdown-editor).

::: code-group
```ruby [Basic Usage]
# Automatically used for :markdown fields
render field(:content).easymde_tag
```

```ruby [With Options]
render field(:description).easymde_tag(
  toolbar: ["bold", "italic", "heading", "|", "quote"],
  spellChecker: false,
  autosave: { enabled: true, uniqueId: "post_content" }
)
```
:::

### Date/Time Picker (Flatpickr)

A powerful and lightweight date and time picker from [Flatpickr](https://flatpickr.js.org/).

::: code-group
```ruby [Date Picker]
# Automatically used for :date fields
render field(:published_at).flatpickr_tag
```
```ruby [Time Picker]
# Automatically used for :time fields
render field(:meeting_time).flatpickr_tag
```
```ruby [Datetime Picker]
# Automatically used for :datetime fields
render field(:deadline).flatpickr_tag
```
```ruby [With HTML Attributes]
render field(:event_date).flatpickr_tag(
  class: "custom-date-picker",
  placeholder: "Select date..."
)
```
:::

::: warning Flatpickr Configuration
The current implementation uses automatic configuration based on field type:
- **Date fields**: Basic date picker with `altInput: true`
- **Time fields**: Time picker with `enableTime: true, noCalendar: true`
- **Datetime fields**: Date and time picker with `enableTime: true`

Custom Flatpickr options (like `dateFormat`, `mode: "range"`) are not currently supported through tag attributes.
:::

### File Upload (Uppy)

A sleek, modern file uploader powered by [Uppy](https://uppy.io/).

::: code-group
```ruby [Single File]
# Automatically used for :file or :attachment fields
render field(:avatar).uppy_tag
```
```ruby [Multiple Files]
render field(:documents).uppy_tag(multiple: true)
```
```ruby [With Restrictions]
render field(:gallery).uppy_tag(
  multiple: true,
  allowed_file_types: ['.jpg', '.jpeg', '.png'],
  max_file_size: 5.megabytes
)
```
```ruby [Direct to Cloud]
render field(:videos).uppy_tag(
  direct_upload: true, # For S3, etc.
  max_total_size: 100.megabytes
)
```
:::

::: details Uppy Component Implementation
The Uppy component automatically handles rendering existing attachments and providing an interface to upload new ones.
```ruby
class Plutonium::UI::Form::Components::Uppy
  # Automatic features:
  # - Drag and drop upload
  # - Progress indicators
  # - Image previews and thumbnails
  # - File type and size validation
  # - Direct-to-cloud upload support
  # - Interactive preview and deletion of existing attachments

  def view_template
    div(class: "flex flex-col-reverse gap-2") do
      render_existing_attachments
      render_upload_interface
    end
  end

  private

  def render_existing_attachments
    Array(field.value).each do |attachment|
      render_attachment_preview(attachment)
    end
  end

  def render_attachment_preview(attachment)
    # Interactive preview with delete option
    div(class: "attachment-preview", data: { controller: "attachment-preview" }) do
      render_thumbnail(attachment)
      render_filename(attachment)
      render_delete_button
    end
  end
end
```
:::

### International Phone Input

A user-friendly phone number input with country code selection, using [intl-tel-input](https://github.com/jackocnr/intl-tel-input).

::: code-group
```ruby [Basic Usage]
# Automatically used for :tel fields
render field(:phone).int_tel_input_tag
```
```ruby [Phone Tag Alias]
# Alias for int_tel_input_tag
render field(:mobile).phone_tag
```
```ruby [With HTML Attributes]
render field(:contact_phone).int_tel_input_tag(
  class: "custom-phone-input",
  placeholder: "Enter phone number"
)
```
:::

::: warning Int Tel Input Configuration
The current implementation uses a fixed configuration:
- **Strict Mode**: Enabled for validation
- **Utils Loading**: Automatically loads validation utilities
- **Hidden Input**: Creates hidden field for form submission

Custom intl-tel-input options (like `onlyCountries`, `preferredCountries`) are not currently supported through tag attributes.
:::

### Secure Association Inputs

Plutonium's association inputs are secure by default, using SGIDs to prevent parameter tampering and scoping options based on user authorization.

::: code-group
```ruby [Belongs To]
# Automatically used for belongs_to associations
render field(:author).belongs_to_tag
```
```ruby [Has Many]
# Automatically used for has_many associations
render field(:tags).has_many_tag
```
```ruby [With Custom Choices]
render field(:category).belongs_to_tag(
  choices: Category.published.pluck(:name, :id)
)
```
```ruby [With Add Action]
render field(:publisher).belongs_to_tag(
  add_action: new_publisher_path
)
```
:::

::: details Secure Association Implementation
```ruby
class Plutonium::UI::Form::Components::SecureAssociation
  # Automatic features:
  # - SGID-based value encoding for security.
  # - Authorization checks before showing options.
  # - "Add new record" button with `return_to` handling.
  # - Polymorphic association support.
  # - Search and filtering (via SlimSelect).

  def choices
    collection = if @skip_authorization
      choices_from_association(association_reflection.klass)
    else
      # Only show records user is authorized to see
      authorized_resource_scope(
        association_reflection.klass,
        with: @scope_with,
        context: @scope_context
      )
    end
    # ...
  end
end
```
:::

## Type Inference

### Automatic Component Selection (`lib/plutonium/ui/form/options/inferred_types.rb`)

The system automatically selects appropriate input components:

```ruby
# Automatic inference based on Active Record column types
render field(:title).input_tag          # → input_tag (string)
render field(:content).easymde_tag        # → easymde_tag (text/rich_text)
render field(:published_at).flatpickr_tag   # → flatpickr_tag (datetime)
render field(:author).secure_association_tag         # → secure_association_tag (belongs_to)
render field(:featured_image).uppy_tag # → uppy_tag (Active Storage)
render field(:category).slim_select_tag       # → slim_select_tag (select)

# Manual override
render field(:title).input_tag(as: :string)
render field(:content).easymde_tag
render field(:published_at).flatpickr_tag
render field(:documents).uppy_tag(multiple: true)
```

### Type Mapping

```ruby
module Plutonium::UI::Form::Options::InferredTypes
  private

  def infer_field_component
    case inferred_field_type
    when :rich_text
      :markdown  # Use EasyMDE for rich text
    end

    inferred_component = super
    case inferred_component
    when :select
      :slim_select  # Enhance selects with SlimSelect
    when :date, :time, :datetime
      :flatpickr   # Use Flatpickr for date/time
    else
      inferred_component
    end
  end
end
```

## Theme System

### Form Theme (`lib/plutonium/ui/form/theme.rb`)

Comprehensive theming for consistent form appearance:

```ruby
class Plutonium::UI::Form::Theme < Phlexi::Form::Theme
  def self.theme
    super.merge({
      # Layout
      fields_wrapper: "space-y-6",
      actions_wrapper: "flex justify-end space-x-3 pt-6 border-t",

      # Input styles
      input: "w-full border rounded-md shadow-sm px-3 py-2 border-gray-300 dark:border-gray-600 focus:ring-primary-500 focus:border-primary-500",
      textarea: "w-full border rounded-md shadow-sm px-3 py-2 border-gray-300 dark:border-gray-600 focus:ring-primary-500 focus:border-primary-500",
      select: "w-full border rounded-md shadow-sm px-3 py-2 border-gray-300 dark:border-gray-600 focus:ring-primary-500 focus:border-primary-500",

      # Enhanced components
      flatpickr: :input,
      int_tel_input: :input,
      easymde: "w-full border rounded-md border-gray-300 dark:border-gray-600",
      uppy: "w-full border rounded-md border-gray-300 dark:border-gray-600",

      # Association components
      association: :select,

      # File input
      file: "w-full border rounded-md shadow-sm font-medium text-sm border-gray-300 dark:border-gray-600",

      # States
      valid_input: "border-green-500 focus:ring-green-500 focus:border-green-500",
      invalid_input: "border-red-500 focus:ring-red-500 focus:border-red-500",

      # Labels and hints
      label: "block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1",
      hint: "mt-2 text-sm text-gray-500 dark:text-gray-200",
      error: "mt-2 text-sm text-red-600 dark:text-red-500"
    })
  end
end
```

## Usage Patterns

### Basic Form

```ruby
# Simple form
class ContactForm < Plutonium::UI::Form::Base
  def form_template
    render field(:name).input_tag(as: :string)
    render field(:email).input_tag(as: :email)
    render field(:message).textarea_tag
    render field(:phone).int_tel_input_tag
  end
end
```

### Field Rendering and Wrappers

All fields must be explicitly rendered using the `render` method. Use wrappers to control layout and styling:

```ruby
class PostForm < Plutonium::UI::Form::Resource
  def form_template
    # Basic field rendering
    render field(:title).input_tag

    # Field with wrapper styling
    render field(:content).wrapped(class: "col-span-full") do |f|
      render f.easymde_tag
    end

    # Custom wrapper with data attributes
    render field(:author).wrapped(
      class: "border rounded-lg p-4",
      data: { controller: "tooltip" }
    ) do |f|
      render f.belongs_to_tag
    end
  end
end
```

### Resource Form

```ruby
# Automatic resource form based on definition
class PostsController < ApplicationController
  def new
    @post = Post.new
    @form = Plutonium::UI::Form::Resource.new(
      @post,
      resource_definition: current_definition
    )
  end

  def edit
    @post = Post.find(params[:id])
    @form = Plutonium::UI::Form::Resource.new(
      @post,
      resource_definition: current_definition
    )
  end
end

# In view
<%= render @form %>
```

### Custom Form Components

```ruby
# Create custom input component
class ColorPickerComponent < Plutonium::UI::Form::Components::Input
  def view_template
    div(data: { controller: "color-picker" }) do
      input(**attributes, type: :color)
      input(**color_text_attributes, type: :text, placeholder: "#000000")
    end
  end

  private

  def color_text_attributes
    attributes.merge(
      name: "#{attributes[:name]}_text",
      data: { color_picker_target: "text" }
    )
  end
end

# Register in form builder
class CustomFormBuilder < Plutonium::UI::Form::Base::Builder
  def color_picker_tag(**options, &block)
    create_component(ColorPickerComponent, :color_picker, **options, &block)
  end
end

# Use in form
render field(:brand_color).color_picker_tag
```

### Nested Resources

```ruby
class PostForm < Plutonium::UI::Form::Resource
  def form_template
    field(:title).input_tag
    field(:content).easymde_tag

    # Nested comments
    nested(:comments, allow_destroy: true) do |comment_form|
      comment_form.field(:content).textarea_tag
      comment_form.field(:author_name).input_tag(as: :string)
    end
  end
end
```

## JavaScript Integration

### Automatic Dependencies

Plutonium automatically includes JavaScript libraries for enhanced form components:
- **EasyMDE** for markdown editing
- **Flatpickr** for date/time picking
- **Intl-Tel-Input** for phone inputs
- **Uppy** for file uploads

### Stimulus Controllers

Each enhanced component uses a Stimulus controller for initialization and cleanup:

```javascript
// easymde_controller.js
export default class extends Controller {
  connect() {
    this.editor = new EasyMDE({
      element: this.element,
      spellChecker: false,
      toolbar: ["bold", "italic", "heading", "|", "quote"]
    });
  }

  disconnect() {
    if (this.editor) {
      this.editor.toTextArea();
      this.editor = null;
    }
  }
}

// flatpickr_controller.js
export default class extends Controller {
  connect() {
    this.picker = new flatpickr(this.element, this.#buildOptions());
  }

  disconnect() {
    if (this.picker) {
      this.picker.destroy();
      this.picker = null;
    }
  }

  #buildOptions() {
    let options = { altInput: true };
    if (this.element.attributes.type.value == "datetime-local") {
      options.enableTime = true;
    } else if (this.element.attributes.type.value == "time") {
      options.enableTime = true;
      options.noCalendar = true;
    }
    return options;
  }
}
```

## Advanced Features

### Form Validation

```ruby
class PostForm < Plutonium::UI::Form::Resource
  def form_template
    # Client-side validation attributes
    render field(:title).input_tag(
      required: true,
      minlength: 3,
      maxlength: 100
    )

    render field(:email).input_tag(
      type: :email,
      pattern: "[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$"
    )

    # Custom validation with JavaScript
    render field(:password).input_tag(
      type: :password,
      data: {
        controller: "password-validator",
        action: "input->password-validator#validate"
      }
    )
  end
end
```

### Dynamic Forms

The recommended way to create dynamic forms is by using the `condition` and `pre_submit` options in your resource definition file. This keeps the logic declarative and out of custom form classes.

```ruby
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # This input will trigger a form refresh whenever its value changes.
  input :send_notifications, as: :boolean, pre_submit: true

  # This input will only be shown if the `condition` evaluates to true.
  # The condition is re-evaluated after a pre-submit refresh.
  input :notification_channel,
        as: :select,
        collection: %w[Email SMS Push],
        condition: -> { object.send_notifications? }
end
```
::: tip
For more details on how to configure conditional inputs, see the [Definition Module documentation](./definition.md#4-add-conditional-logic).
:::
