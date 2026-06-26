# Forms

Built on [Phlexi::Form](https://github.com/radioactive-labs/phlexi-form). Override the `Form` nested class in your definition to customize templates, layouts, and field rendering.

## 🚨 Critical

- **`render_actions` is mandatory in custom `form_template`** — without it, the form has no submit button.
- **Configure inputs in the definition, render them with `render_resource_field`** in the form template. Don't reimplement field widgets from scratch.
- **Override via nested classes** (`class Form < Form; end`) inside the definition. Don't replace the root `Plutonium::UI::Form::Resource` class.

## Hierarchy

```
Phlexi::Form::Base
└── Plutonium::UI::Form::Base
    ├── Plutonium::UI::Form::Resource          # CRUD
    │   └── Plutonium::UI::Form::Interaction   # action forms
    └── Plutonium::UI::Form::Query             # search/filter
```

## Override the form

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    def form_template
      render_fields       # render every permitted field
      render_actions      # submit buttons — REQUIRED
    end
  end
end
```

### Form methods

| Method | Purpose |
|---|---|
| `form_template` | Main override point |
| `render_fields` | All permitted fields in default layout |
| `render_resource_field(name)` | One field, using the definition's `input` config |
| `render_actions` | Submit + secondary buttons |
| `fields_wrapper { ... }` | Grid wrapper div (themeable) |
| `actions_wrapper { ... }` | Button wrapper div (themeable) |
| `object` / `record` | The form record |
| `resource_fields` | Array of permitted field names |
| `resource_definition` | The definition instance |

## Custom layouts

### Sectioned form (declarative — preferred)

Declare sections in the **definition** using `form_layout`. The form picks up the layout automatically — no `Form` subclass needed for common cases.

```ruby
class PostDefinition < ResourceDefinition
  form_layout do
    section :basics, :title, :slug,
      label: "Basic information"

    section :content, :body, :excerpt,
      label: "Content", columns: 1

    section :publishing, :published_at, :category,
      label: "Publishing", collapsible: true, collapsed: true
  end
end
```

This handles headings, collapsible panels, per-section column counts, and `condition:`-based visibility — all with no view code. See [Resource › Definition › Form layout](/reference/resource/definition#form-layout) for the full DSL reference, including `ungrouped`, `condition:`, `columns:`, and the "On interactions" note.

### Full control: override `render_fields`

When the declarative DSL doesn't cover your use case — asymmetric multi-column layouts, embedding a panel widget between sections, etc. — override `render_fields` in a nested `Form` class:

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    def form_template
      render_fields   # replaced below
      render_actions
    end

    def render_fields
      div(class: "mb-8") do
        h3(class: "text-lg font-semibold mb-4 text-[var(--pu-text)]") { "Basic Information" }
        fields_wrapper do
          render_resource_field :title
          render_resource_field :slug
        end
      end

      div(class: "mb-8") do
        h3(class: "text-lg font-semibold mb-4 text-[var(--pu-text)]") { "Content" }
        fields_wrapper do
          render_resource_field :content
          render_resource_field :excerpt
        end
      end

      div(class: "mb-8") do
        h3(class: "text-lg font-semibold mb-4 text-[var(--pu-text)]") { "Publishing" }
        fields_wrapper do
          render_resource_field :published_at
          render_resource_field :category
        end
      end
    end
  end
end
```

Prefer `form_layout` in the definition — it keeps layout config out of view code and works for interactions too.

### Two-column layout

```ruby
def form_template
  div(class: "grid grid-cols-1 lg:grid-cols-3 gap-6") do
    div(class: "lg:col-span-2") do
      fields_wrapper do
        render_resource_field :title
        render_resource_field :content
      end
    end

    div(class: "space-y-4") do
      Panel do
        h4(class: "font-medium mb-2") { "Settings" }
        render_resource_field :status
        render_resource_field :visibility
      end
    end
  end
  render_actions
end
```

## Field builder (`field(:foo).input_tag`)

`render_resource_field` uses the input config from the definition. For ad-hoc rendering — when you want fine-grained control over a specific field — use `field(...)` directly:

```ruby
render field(:title).wrapped { |f| f.input_tag }                # wrapped: label + hint + errors
render field(:title).input_tag                                  # bare element only
render field(:title).wrapped(class: "col-span-full") { |f| f.input_tag }
```

### Tag methods (standard)

| Tag | Input |
|---|---|
| `input_tag` | text (auto-detected type) |
| `string_tag`, `text_tag`, `number_tag`, `email_tag`, `password_tag`, `url_tag`, `tel_tag`, `hidden_tag` | standard HTML inputs |
| `checkbox_tag`, `select_tag`, `radio_button_tag` | standard |
| `toggle_tag` / `switch_tag` | switch-styled boolean (`as: :toggle` / `:switch`) — the **default** for boolean columns; same behavior as a checkbox. Use `checkbox_tag` (`as: :boolean`) for a plain checkbox. |

### Plutonium-enhanced tags

| Tag | Component |
|---|---|
| `easymde_tag` / `markdown_tag` | EasyMDE markdown editor |
| `slim_select_tag` | Slim Select (enhanced dropdown) |
| `flatpickr_tag` | Flatpickr date/time picker |
| `phone_tag` / `int_tel_input_tag` | intl-tel-input phone field |
| `uppy_tag` / `file_tag` | Uppy file upload |
| `secure_association_tag` | Association with policy-checked options (inline `+` add, typeahead) |
| `belongs_to_tag` / `has_many_tag` / `has_one_tag` | Association selects |
| `key_value_store_tag` | Key/value pairs editor |

```ruby
render field(:published_at).wrapped { |f| f.flatpickr_tag(min_date: Date.today, enable_time: true) }

render field(:avatar).wrapped do |f|
  f.uppy_tag(allowed_file_types: %w[.jpg .png], max_file_size: 5.megabytes)
end
```

### Password & secret fields {#password-fields}

`password_tag` renders a masking input that **never emits the stored value** into the DOM. A stored secret renders a fixed sentinel (masking both the value and its length); on submit:

| field state | result |
|---|---|
| untouched (sentinel) | kept — the stored secret is left unchanged |
| edited to a new value, then failed re-render | comes back **blank + `required`** so the user re-types it (a submitted secret is never echoed back) |
| cleared, then failed re-render | comes back blank, **not** `required` — the clear may be intentional, so it's allowed to stand |
| emptied | explicit clear (clear-by-blank) — the `required` guard only prevents an *accidental* blank submit |
| typed | set as the new value |

The sentinel is guarded client-side by the `password-sentinel` Stimulus controller: the first edit (a keystroke, paste, or **backspace**) wipes the whole field, so a partial edit can't corrupt the sentinel into a literal new password. New records and interaction forms (set-password, reset-password) render an honest empty field.

**Automatic detection.** A field is masked automatically when its name:

- equals `password`, `token`, or `salt`;
- starts with `encrypted_`;
- ends with `_password`, `_digest`, `_hash`, `_token`, `_key`, or `_salt`;
- contains `secret`.

This is a naming convenience, **not** a security guarantee — tune it per field:

```ruby
# Opt OUT: render the value as a normal, readable text input
field :api_token,   as: :string      # a token the admin needs to copy
field :content_hash, as: :string     # a checksum, not a secret
field :public_key,  as: :string      # *_key matches, but a public key is not secret

# Opt IN: mask a secret the heuristic still misses (e.g. no telltale name)
field :recovery_phrase, as: :password
```

> [!WARNING]
> The heuristic is name-based and best-effort. A secret column with an unconventional name (e.g. `recovery_phrase`, `pin`) still renders its value into the page unless you set `as: :password`. Audit secret-bearing columns explicitly.

### Wrapped vs unwrapped

- `wrapped` — includes label, hint, and error rendering. Use for normal form fields.
- Bare tag — just the input element. Use when you're laying out custom wrappers.
- `wrapped(class: "...")` — pass classes to the wrapper div.

## Association inputs (`secure_association_tag`) {#association-inputs}

Association inputs render with two affordances out of the box:

- **Inline `+` add** — a button next to the select opens the target resource's `:new` action. Inherits the target's modal mode. If the parent form is already in a modal, the `+` opens a **stacked secondary modal** (see [Pages › Stacked modals](./pages#stacked-modals-secondary-frame)) so the in-progress form isn't lost — on success the secondary closes and the parent reloads.
- **Typeahead** — server-side autocomplete is on by default. Uses the target's `search` block if defined; otherwise falls back to a `LIKE` on the input's `label_method:` column or the first match from `[name, title, label, slug, display_name, email]`. See [Resource › Query › Search](/reference/resource/query#search) for the typeahead fallback details.

```ruby
# Opt out of the + button
input :author, add_action: false

# Custom add URL
input :author, add_action: "/internal/users/new"

# Opt out of typeahead (use slim-select's client filter only)
input :author, typeahead: false

# Pick a non-default searchable column
input :author, label_method: :email
```

::: tip Large association tables
For large target tables, write an explicit `search` block on the target resource definition — the fallback's leading-wildcard `LIKE` can't use a b-tree index.
:::

## Submit buttons

Default `render_actions` produces the primary submit, plus an optional "Save and add another" / "Update and continue editing" secondary button.

Control the secondary button via the definition:

```ruby
class PostDefinition < ResourceDefinition
  submit_and_continue false   # nil (default — auto), true (always show), false (always hide)
end
```

Singular resources auto-hide it (creating "another" doesn't make sense for `/profile`).

### Custom action strip

```ruby
def render_actions
  actions_wrapper do
    a(href: resource_url_for(resource_class), class: "pu-btn pu-btn-md pu-btn-secondary") { "Cancel" }
    button(type: :submit, name: "draft", value: "1", class: "pu-btn pu-btn-md") { "Save Draft" }
    render submit_button
  end
end
```

## Pre-submit, nested inputs, interaction forms

These all live in the definition layer:

- **Pre-submit / dynamic forms** — see [Resource › Definition › Dynamic forms](/reference/resource/definition#dynamic-forms-pre-submit)
- **Nested inputs** (`nested_input :variants`) — see [Resource › Definition › Nested inputs](/reference/resource/definition#nested-inputs)
- **Interaction forms** — interactions define their own `attribute` / `input` and inherit `Plutonium::UI::Form::Interaction`; see [Behavior › Interactions](/reference/behavior/interactions)

## Theming

Forms use a theme system for consistent styling. Override per-resource by nesting a `Theme` class inside `Form`:

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    class Theme < Plutonium::UI::Form::Theme
      def self.theme
        super.merge(
          base:            "bg-[var(--pu-card-bg)] shadow-md rounded-lg p-6",
          fields_wrapper:  "grid grid-cols-2 gap-6",
          actions_wrapper: "flex justify-end mt-6 space-x-2",
          label:           "block mb-2 text-base font-bold",
          input:           "pu-input",
          error:           "pu-error",
          button:          "pu-btn pu-btn-md pu-btn-primary"
        )
      end
    end
  end
end
```

::: warning Always `super.merge(...)`
Don't replace the theme wholesale — Plutonium's defaults handle invalid states, focus rings, and dark mode. `super.merge` keeps them.
:::

### Theme keys

`base`, `fields_wrapper`, `actions_wrapper`, `wrapper`, `inner_wrapper`, `label`, `invalid_label`, `valid_label`, `neutral_label`, `input`, `invalid_input`, `valid_input`, `neutral_input`, `hint`, `error`, `button`, `checkbox`, `toggle`, `select`.

See [Assets › Phlexi component themes](./assets#phlexi-component-themes) for the underlying theme system.

## Context inside form templates

```ruby
class Form < Form
  def form_template
    # Form object
    object              # the record
    record              # alias for object
    object.new_record?  # check if creating

    # Request context
    current_user
    current_parent
    current_scoped_entity
    request
    params

    # Definition
    resource_definition
    resource_fields     # permitted fields

    # URL helpers
    resource_url_for(object)
    resource_url_for(Post, action: :new)

    # Rails helpers
    helpers.link_to(...)
  end
end
```

## Related

- [Pages](./pages) — `NewPage` / `EditPage` page hooks
- [Components](./components) — building reusable Phlex components for forms
- [Assets](./assets) — `.pu-*` classes, design tokens, dark mode
- [Resource › Definition](/reference/resource/definition) — input configuration (`as:`, `hint:`, `condition:`, blocks)
- [Behavior › Interactions](/reference/behavior/interactions) — interaction forms (`Plutonium::UI::Form::Interaction`)
- [Tenancy › Nested resources](/reference/tenancy/nested-resources) — parent fields hidden by URL
