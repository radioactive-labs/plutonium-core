---
title: Form Module
---

# Form Module

The Form module is Plutonium's comprehensive system for building powerful, modern, and secure forms. It extends the `Phlexi::Form` library to provide a suite of enhanced input components, automatic field inference, secure-by-default associations, and seamless integration with your resources. This module is designed to make creating rich, accessible, and interactive forms a breeze.

::: tip
The Form module is located in `lib/plutonium/ui/form/`.
:::

## Key Features

- **Rich Input Components**: Out-of-the-box support for markdown editors, date pickers, file uploads with previews, and international phone inputs.
- **Secure by Default**: All associations use Signed Global IDs (SGIDs) to prevent parameter tampering, with automatic authorization checks.
- **Intelligent Type Inference**: Automatically selects the best input component based on Active Record column types, saving you from boilerplate.
- **Deep Resource Integration**: Generate forms automatically from your resource definitions, including support for conditional fields.
- **Modern Frontend**: A complete theme system built with Tailwind CSS, Stimulus for interactivity, and first-class dark mode support.
- **Complex Form Structures**: Easily manage associations with nested forms supporting dynamic "add" and "remove" functionality.

## Core Form Classes

Plutonium provides several base form classes, each tailored for a specific purpose.

### `Form::Base`

This is the foundation for all forms in Plutonium. It extends `Phlexi::Form::Base` and includes the core form builder with all the custom input components. You can inherit from this class to create custom, one-off forms.

::: details Builder Implementation
The `Builder` class within `Form::Base` is where all the custom input tag methods are defined. It aliases standard Rails form helpers like `belongs_to_tag` to Plutonium's secure and enhanced versions.

```ruby
class Plutonium::UI::Form::Base < Phlexi::Form::Base
  # ...
  class Builder < Builder
    include Plutonium::UI::Form::Options::InferredTypes

    # Enhanced input components
    def easymde_tag(**); end
    alias_method :markdown_tag, :easymde_tag

    def flatpickr_tag(**); end
    def int_tel_input_tag(**); end
    alias_method :phone_tag, :int_tel_input_tag

    def uppy_tag(**); end
    alias_method :file_tag, :uppy_tag
    alias_method :attachment_tag, :uppy_tag

    def slim_select_tag(**); end
    def secure_association_tag(**); end
    def secure_polymorphic_association_tag(**); end

    # Override default association methods
    alias_method :belongs_to_tag, :secure_association_tag
    alias_method :has_many_tag, :secure_association_tag
    alias_method :has_one_tag, :secure_association_tag
    alias_method :polymorphic_belongs_to_tag, :secure_polymorphic_association_tag
  end
end
```
:::

### `Form::Resource`

This is a specialized form that intelligently renders inputs based on a resource definition. It's the primary way you'll create `new` and `edit` forms for your models. It automatically handles field rendering, nested resources, and conditional logic defined in your resource class.

```ruby
class Plutonium::UI::Form::Resource < Base
  include Plutonium::UI::Form::Concerns::RendersNestedResourceFields

  def initialize(object, resource_fields:, resource_definition:, **options)
    # ...
  end

  def form_template
    render_fields    # Renders inputs from resource_definition
    render_actions   # Renders submit/cancel buttons
  end
end
```

### `Form::Query`

This form is built for search and filtering. It integrates with Plutonium's Query Objects to create search inputs, dynamic filter controls, and hidden fields for sorting and pagination, all submitted via GET requests to preserve filterable URLs.

```ruby
class Plutonium::UI::Form::Query < Base
  def initialize(object, query_object:, page_size:, **options)
    # ... configured as a GET form with Turbo integration
  end

  def form_template
    render_search_fields
    render_filter_fields
    render_sort_fields
    render_scope_fields
  end
end
```

### `Form::Interaction`

This specialized form is designed for handling user interactions and actions. It automatically configures itself based on an interaction object, setting up the appropriate fields and form behavior for interactive actions.

```ruby
class Plutonium::UI::Form::Interaction < Resource
  def initialize(interaction, **options)
    # Automatically configures fields from interaction attributes
    options[:resource_fields] = interaction.attribute_names.map(&:to_sym) - %i[resource resources]
    options[:resource_definition] = interaction
    # ...
  end

  # Form posts to the same page for interaction handling
  def form_action
    nil
  end
end
```

## Enhanced Input Components

Plutonium replaces standard form inputs with enhanced versions that provide a modern user experience.

### Markdown Editor (Easymde)

For rich text content, Plutonium integrates a client-side markdown editor based on [EasyMDE](https://github.com/Ionaru/easy-markdown-editor). It's automatically used for `rich_text` fields (like ActionText) and provides a live preview.

::: code-group
```ruby [Automatic Usage]
# Automatically used for ActionText rich_text fields
render field(:content).easymde_tag

# Or explicitly with an alias
render field(:description).markdown_tag
```
:::

::: details Component Internals
The component renders a `textarea` with a `data-controller="easymde"` attribute. It also includes logic to correctly handle ActionText objects by calling `to_plain_text` on the value.

```ruby
class Plutonium::UI::Form::Components::Easymde < Phlexi::Form::Components::Base
  def view_template
    textarea(**attributes, data_controller: "easymde") do
      normalize_value(field.value)
    end
  end
  # ...
end
```
:::

### Date/Time Picker (Flatpickr)

A beautiful and lightweight date/time picker from [Flatpickr](https://flatpickr.js.org/). It's automatically enabled for `date`, `time`, and `datetime` fields.

::: code-group
```ruby [Automatic Usage]
# Automatically used based on field type
render field(:published_at).flatpickr_tag  # datetime field
render field(:event_date).flatpickr_tag    # date field
render field(:meeting_time).flatpickr_tag  # time field
```
:::

::: details Component Internals
The component simply adds a `data-controller="flatpickr"` attribute to a standard input. The corresponding Stimulus controller then inspects the input's `type` attribute (`date`, `time`, or `datetime-local`) to initialize Flatpickr with the correct options (e.g., with or without the time picker).

```ruby
class Plutonium::UI::Form::Components::Flatpickr < Phlexi::Form::Components::Input
  private

  def build_input_attributes
    super
    attributes[:data_controller] = tokens(attributes[:data_controller], :flatpickr)
  end
end
```
:::

### International Phone Input

For phone numbers, a user-friendly input with a country-code dropdown is provided by [intl-tel-input](https://github.com/jackocnr/intl-tel-input).

::: code-group
```ruby [Usage]
# Automatically used for fields of type :tel
render field(:phone).int_tel_input_tag

# Or using its alias
render field(:mobile).phone_tag
```
:::

::: details Component Internals
This component wraps the input in a `div` with a `data-controller="intl-tel-input"` and adds a `data_intl_tel_input_target` to the input itself, allowing the Stimulus controller to initialize the library.

```ruby
class Plutonium::UI::Form::Components::IntlTelInput < Phlexi::Form::Components::Input
  def view_template
    div(data_controller: "intl-tel-input") do
      super # Renders the input with proper data targets
    end
  end

  private

  def build_input_attributes
    super
    attributes[:data_intl_tel_input_target] = tokens(attributes[:data_intl_tel_input_target], :input)
  end
end
```
:::

### File Upload (Uppy)

File uploads are handled by [Uppy](https://uppy.io/), a sleek, modern uploader. It supports drag & drop, progress indicators, direct-to-cloud uploads, and interactive previews for existing attachments.

::: code-group
```ruby [Basic Usage]
# Automatically used for file and Active Storage attachments
render field(:avatar).uppy_tag
render field(:documents).file_tag     # alias
render field(:gallery).attachment_tag # alias
```

```ruby [With Options]
render field(:documents).uppy_tag(
  multiple: true,
  direct_upload: true, # For S3, etc.
  max_file_size: 10.megabytes,
  allowed_file_types: ['.pdf', '.doc']
)
```
:::

::: details Component Internals
The Uppy component is quite sophisticated. It renders an interactive preview grid for existing attachments (each with its own `attachment-preview` Stimulus controller for deletion) and a file input managed by an `attachment-input` Stimulus controller that initializes Uppy.

```ruby
class Plutonium::UI::Form::Components::Uppy < Phlexi::Form::Components::Input
  # Automatic features:
  # - Interactive preview of existing attachments
  # - Delete buttons for removing attachments
  # - Support for direct cloud uploads
  # - File type and size validation via Uppy options
  # ...

  def view_template
    div(class: "flex flex-col-reverse gap-2") do
      render_existing_attachments
      render_upload_interface
    end
  end
end
```
:::

### Secure Association Inputs

Plutonium overrides all standard Rails association helpers (`belongs_to`, `has_many`, etc.) to use a secure, enhanced version that integrates with [SlimSelect](https://slimselectjs.com/) for a better UI.

::: code-group
```ruby [Association Types]
# Automatically used for all standard association types
render field(:author).belongs_to_tag
render field(:tags).has_many_tag
render field(:profile).has_one_tag
render field(:commentable).polymorphic_belongs_to_tag
```

```ruby [With Options]
render field(:category).belongs_to_tag(
  choices: Category.published.pluck(:name, :id),
  add_action: new_category_path, # Adds a "+" button to add new records
  skip_authorization: false      # Enforces authorization policies
)
```
:::

::: details Security & Implementation
The `SecureAssociation` component is the cornerstone of Plutonium's form security.
- **SGID Encoding**: It uses `to_signed_global_id` as the value method, so raw database IDs are never exposed to the client.
- **Authorization**: It uses `authorized_resource_scope` to ensure that the choices presented to the user are only the ones they are permitted to see.
- **Add Action**: It can render an "add new" button that automatically includes a `return_to` parameter for a smooth UX.

```ruby
class Plutonium::UI::Form::Components::SecureAssociation
  def choices
    collection = if @skip_authorization
      # ...
    else
      # Only show records user is authorized to see
      authorized_resource_scope(association_reflection.klass,
                               relation: choices_from_association(association_reflection.klass))
    end
    # ...
  end
end
```
:::

## Type Inference System

Plutonium is smart about choosing the right input for a given field, minimizing boilerplate in your forms.

### Automatic Component Selection

The `InferredTypes` module overrides the default type inference to map common types to Plutonium's enhanced components.

```ruby
module Plutonium::UI::Form::Options::InferredTypes
  private

  def infer_field_component
    case inferred_field_type
    when :rich_text
      return :markdown  # Use Easymde for ActionText fields
    end

    inferred = super
    case inferred
    when :select
      :slim_select    # Enhance selects with SlimSelect
    when :date, :time, :datetime
      :flatpickr     # Use Flatpickr for date/time fields
    else
      inferred
    end
  end
end
```

This means you often don't need to specify the input type at all.

```ruby
# These are automatically inferred:
render field(:title)          # -> input (string)
render field(:content)        # -> easymde (rich_text)
render field(:published_at)   # -> flatpickr (datetime)
render field(:phone)          # -> int_tel_input (tel)
render field(:author)         # -> secure_association (belongs_to)
render field(:avatar)         # -> uppy (Active Storage attachment)
render field(:category)       # -> slim_select (enum/select)
```

## Nested Resources

Plutonium has first-class support for `accepts_nested_attributes_for`, allowing you to build complex forms with nested records. This is handled by the `RendersNestedResourceFields` concern in `Form::Resource`.

### Defining Nested Inputs

You define nested inputs in your resource definition file. Plutonium will automatically detect the configuration from your Rails model's `accepts_nested_attributes_for` declaration—including options like `allow_destroy`, `update_only`, and `limit`—and use them to render the appropriate form controls.

You can declare a nested input with a simple block or by referencing another definition class.

::: code-group
```ruby [Block Definition]
# app/models/post.rb
class Post < ApplicationRecord
  has_many :comments
  accepts_nested_attributes_for :comments, allow_destroy: true, limit: 5
end

# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # This automatically inherits allow_destroy: true and limit: 5 from the model
  nested_input :comments do |n|
    n.input :content, as: :textarea
    n.input :author_name, as: :string
  end
end
```

```ruby [Reference Definition]
# app/models/post.rb
class Post < ApplicationRecord
  has_many :tags
  accepts_nested_attributes_for :tags, update_only: true
end

# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # This inherits update_only: true from the model
  nested_input :tags,
               using: TagDefinition,
               fields: %i[name color]
end
```
:::

### Overriding Configuration

While Plutonium automatically uses your Rails configuration, you can easily override it by passing options directly to the `nested_input` method. Explicit options always take precedence.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Explicit options override the model's configuration
  nested_input :comments,
               allow_destroy: false,  # Overrides model's allow_destroy: true
               limit: 10,             # Overrides model's limit: 5
               description: "Add up to 10 comments for this post." do |n|
    n.input :content
  end
end
```

### Automatic Rendering

The `Form::Resource` class automatically renders the nested form based on your definition:
- For `has_many` associations, it provides "Add" and "Remove" buttons, respecting the `limit`.
- For `has_one` and `belongs_to` associations, it renders inline fields for a single record.
- If `allow_destroy: true`, a "Delete" checkbox is rendered for persisted records.
- If `update_only: true`, the "Add" button is hidden.

::: details Nested Rendering Internals
The `render_nested_resource_field` method orchestrates the rendering of the nested form, including the header, existing records, the "add" button, and the template for new records. This is all managed by the `nested-resource-form-fields` Stimulus controller.
:::

## Theming

Forms are styled using a comprehensive theme system that leverages Tailwind CSS utility classes. The theme is defined in `lib/plutonium/ui/form/theme.rb`.

::: details Form Theme Configuration
The `Plutonium::UI::Form::Theme.theme` method returns a hash where keys represent form elements (like `input`, `label`, `error`) and values are the corresponding CSS classes. It includes styles for layout, inputs in different states (valid, invalid), and all custom components.

```ruby
class Plutonium::UI::Form::Theme < Phlexi::Form::Theme
  def self.theme
    super.merge({
      # Layout
      base: "relative bg-white dark:bg-gray-800 shadow-md sm:rounded-lg my-3 p-6 space-y-6",
      fields_wrapper: "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-4",
      actions_wrapper: "flex justify-end space-x-2",

      # Input styling
      input: "w-full p-2 border rounded-md shadow-sm dark:bg-gray-700 focus:ring-2",
      valid_input: "bg-green-50 border-green-500 ...",
      invalid_input: "bg-red-50 border-red-500 ...",

      # Enhanced component themes (aliases to base styles)
      flatpickr: :input,
      int_tel_input: :input,
      uppy: :file,
      association: :select,
      # ...
    })
  end
end
```
:::

## JavaScript & Stimulus

Interactivity is powered by a set of dedicated Stimulus controllers. Plutonium automatically loads these controllers and the required third-party libraries.

- **`form`**: The main controller for handling pre-submit refreshes (for conditional fields).
- **`nested-resource-form-fields`**: Manages adding and removing nested form fields dynamically.
- **`slim-select`**: Initializes the SlimSelect library on select fields.
- **`easymde`**, **`flatpickr`**, **`intl-tel-input`**: Controllers for their respective input components.
- **`attachment-input`** & **`attachment-preview`**: Work together to manage the Uppy file upload experience.
