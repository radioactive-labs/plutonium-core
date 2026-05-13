# Displays

The show page's record rendering. Override the `Display` nested class in your definition for custom layouts.

## Custom display template

```ruby
class PostDefinition < ResourceDefinition
  class Display < Display
    def display_template
      div(class: "bg-gradient-to-r from-primary-500 to-secondary-600 p-8 rounded-lg text-white mb-6") do
        h1(class: "text-3xl font-bold") { object.title }
        p(class: "mt-2 opacity-90") { object.excerpt }
      end

      Block do
        fields_wrapper do
          render_resource_field :author
          render_resource_field :published_at
        end
      end

      Block do
        div(class: "prose max-w-none") { raw object.content }
      end

      render_associations if present_associations?
    end
  end
end
```

## Methods

| Method | Purpose |
|---|---|
| `render_fields` | All permitted fields |
| `render_resource_field(name)` | One field |
| `render_associations` | Association tabs (driven by `permitted_associations` — see [Behavior › Policy](/reference/behavior/policies#association-permissions)) |
| `object` | The record |
| `resource_fields`, `resource_associations` | Permitted lists |

## Custom rendering per field

For per-field custom rendering, prefer declaring it in the **definition** rather than overriding the entire `Display`:

```ruby
class PostDefinition < ResourceDefinition
  # Block — returns any Phlex component
  display :status do |field|
    StatusBadgeComponent.new(value: field.value, class: field.dom.css_class)
  end

  # phlexi_tag — proc whose body is rendered inside a Phlex context
  display :priority, as: :phlexi_tag, with: ->(value, attrs) {
    case value
    when 'high'   then span(class: "badge badge-danger")  { "High" }
    when 'medium' then span(class: "badge badge-warning") { "Medium" }
    else span(class: "badge badge-info") { "Low" }
    end
  }

  # Custom component class
  display :chart, as: ChartComponent
end
```

See [Resource › Definition › Custom rendering](/reference/resource/definition#custom-rendering) for the full per-field rendering surface.

## Theming

Override the theme via a nested `Theme` class:

```ruby
class PostDefinition < ResourceDefinition
  class Display < Display
    class Theme < Plutonium::UI::Display::Theme
      def self.theme
        super.merge(
          fields_wrapper: "grid grid-cols-3 gap-8",
          label:          "text-sm font-bold text-[var(--pu-text-muted)] mb-1",
          string:         "text-lg text-[var(--pu-text)]",
          markdown:       "prose dark:prose-invert max-w-none"
        )
      end
    end
  end
end
```

### Theme keys

`fields_wrapper`, `label`, `description`, `string`, `text`, `link`, `email`, `phone`, `markdown`, `json`.

## Metadata panel

A right-side aside on the show page. Configured at the definition level, not the Display class — see [Resource › Definition › Metadata panel](/reference/resource/definition#metadata-panel-show-page).

## Related

- [Pages](./pages) — `ShowPage` render hooks (often a lighter alternative to overriding `Display`)
- [Components](./components) — building reusable Phlex display components
- [Resource › Definition](/reference/resource/definition) — field-level display configuration (`as:`, `condition:`, blocks)
- [Behavior › Policy](/reference/behavior/policies) — `permitted_associations` drives the show-page tablist
