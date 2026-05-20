# Tables

The index page's table rendering. Override the `Table` nested class in your definition for custom layouts (e.g. card grids).

## Custom table template

```ruby
class PostDefinition < ResourceDefinition
  class Table < Table
    def view_template
      render_toolbar         # search + view toggle + filter buttons
      render_scopes_pills    # scope chips (if any scopes defined)
      render_filter_pills    # active-filter chips

      if collection.empty?
        render_empty_card
      else
        # Replace the table with a card grid
        div(class: "grid grid-cols-3 gap-4") do
          collection.each { |post| render PostCardComponent.new(post:) }
        end
      end

      render_bulk_actions_toolbar
      render_footer
    end
  end
end
```

## Methods

| Method | Purpose |
|---|---|
| `render_toolbar` | Search input + view toggle + filter button |
| `render_scopes_pills` | Quick-filter scope chips (only renders if scopes defined) |
| `render_filter_pills` | Active-filter chips |
| `render_bulk_actions_toolbar` | Bulk action bar (only renders when rows selected) |
| `render_table` | Default table rendering |
| `render_empty_card` | Empty state |
| `render_footer` | Pagination |
| `collection` | Paginated records |
| `resource_fields` | Column field names |

## Per-column customization

Prefer declaring column behavior in the **definition** rather than overriding the entire `Table`:

```ruby
class PostDefinition < ResourceDefinition
  column :title,  align: :start    # default
  column :status, align: :center
  column :amount, align: :end

  # formatter — receives just the value
  column :description, formatter: ->(value) { value&.truncate(30) }
  column :price,       formatter: ->(value) { "$%.2f" % value if value }

  # block — receives the full record
  column :full_name do |record|
    "#{record.first_name} #{record.last_name}"
  end
end
```

See [Resource › Definition › Column options](/reference/resource/definition#column-options).

## Grid view

For card-based layouts as a switchable alternative to the table, use the built-in Grid view — declare `grid_fields` in the definition:

```ruby
class UserDefinition < ResourceDefinition
  grid_fields(
    image:     :avatar,
    header:    :name,
    subheader: :email,
    body:      :bio,
    meta:      [:role, :status],
    footer:    :last_seen_at
  )

  default_index_view :grid
end
```

See [Resource › Definition › Index views](/reference/resource/definition#index-views-table-grid). You only need a custom `Table` class when you want something neither Table nor Grid covers.

## Theming

Override the theme via a nested `Theme` class:

```ruby
class PostDefinition < ResourceDefinition
  class Table < Table
    class Theme < Plutonium::UI::Table::Theme
      def self.theme
        super.merge(
          wrapper:     "pu-table-wrapper",
          base:        "pu-table",
          header:      "pu-table-header",
          header_cell: "pu-table-header-cell",
          body_row:    "pu-table-body-row",
          body_cell:   "pu-table-body-cell"
        )
      end
    end
  end
end
```

### Theme keys

`wrapper`, `base`, `header`, `header_cell`, `body_row`, `body_cell`, `sort_icon`.

## Related

- [Pages](./pages) — `IndexPage` render hooks (a lighter alternative for top/bottom chrome)
- [Components](./components) — `PostCardComponent` and other reusable Phlex pieces
- [Resource › Definition](/reference/resource/definition) — column configuration, grid view
- [Resource › Query](/reference/resource/query) — search, filters, scopes, sort
