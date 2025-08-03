---
title: Table Module
---

# Table Module

The Table module is a powerful system for creating data tables in Plutonium. It leverages `Phlexi::Table` to provide a rich set of features including smart column rendering, pagination, sorting, filtering, and search. It's designed to work seamlessly with Plutonium's resource definitions to help you build complex data displays with minimal effort.

::: tip Architecture
The Table module lives in `lib/plutonium/ui/table/` and is composed of several key parts:
- **`Plutonium::UI::Table::Resource`**: The primary component for rendering resource-based tables.
- **Components**: UI elements like search bars, scope selectors, and pagination controls.
- **Themes**: Centralized styling for a consistent look and feel.
:::

## Getting Started: Defining a Table

Everything about a table—its columns, filters, and behaviors—is defined within a resource definition file. You can use `display`, `column`, or `field` to define what data to show.

Here's a basic example for a `Post` resource:

```ruby
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # Use `display` or `column` to define table columns.
  display :author, as: :association
  display :published_at, as: :datetime
  display :status, as: :badge
  display :actions, as: :actions, align: :right

  # Define sorting
  sort :title
  sort :published_at
  
  # Define default sort (newest first)
  default_sort :created_at, :desc

  # Enable search
  search do |scope, query|
    scope.where("title ILIKE ?", "%#{query}%")
  end

  # Define filters
  filter :published, with: Plutonium::Query::Filters::Text, predicate: :eq
  filter :author, with: Plutonium::Query::Filters::Text, predicate: :eq

  # Define query scopes
  scope :published
  scope :draft
end
```

This configuration is all you need to render a feature-rich table for your posts.

## Configuring Columns

Columns are the heart of your table. Plutonium offers flexible ways to configure them.

### Column Types

You can render data in various formats using the `as:` option:

```ruby
column :name, as: :string
column :email, as: :email
column :website, as: :link
column :published_at, as: :datetime
column :is_active, as: :boolean
column :priority, as: :badge
column :profile_picture, as: :attachment
column :metadata, as: :key_value_store
```

### Alignment

Control column alignment with the `align:` option.

```ruby
column :title, align: :start      # Left-aligned (default)
column :price, align: :end        # Right-aligned
column :status, align: :center    # Center-aligned
```

### Custom Column Rendering

For complete control over a column's output, provide a block. The block receives a wrapped record object.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Basic custom rendering with a block
  column :full_name do |wrapped_record|
    # `unwrapped` gives you the original AR record
    record = wrapped_record.unwrapped
    "#{record.first_name} #{record.last_name}"
  end

  # Render a custom component for more complex UI
  column :status do |wrapped_record|
    # The `field` method provides access to the field's value and definition
    field = wrapped_record.field(:status)
    render StatusBadgeComponent.new(field.value)
  end
end
```

### Conditional Columns

You can show or hide columns dynamically using the `condition` option. It accepts a lambda that is evaluated in the view context.

```ruby
# Show a column only in the development environment
column :debug_info, condition: -> { Rails.env.development? }

# Show a column based on user permissions
column :admin_notes, condition: -> { current_user.admin? }
```

::: warning Security
Use `condition` for display logic, not for security. To control data visibility, you should filter `permitted_attributes_for_read` within your authorization policies.
:::

## Searching and Filtering

Plutonium makes it easy to add powerful search and filtering capabilities to your tables.

### Search

Define your search logic with the `search` method in your resource definition. The search bar will appear automatically.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Simple search on a single field
  search do |scope, search_term|
    scope.where("title ILIKE ?", "%#{search_term}%")
  end

  # More complex search across multiple fields and associations
  search do |scope, search_term|
    scope.joins(:author)
         .where(
           "posts.title ILIKE :q OR posts.content ILIKE :q OR users.name ILIKE :q",
           q: "%#{search_term}%"
         )
  end
end
```

### Filters

Declare filters using the `filter` method. Currently, Plutonium provides the Text filter with various predicates.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Text filter with exact match
  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq

  # Text filter with contains matching
  filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains

  # Text filter with starts_with matching
  filter :category, with: Plutonium::Query::Filters::Text, predicate: :starts_with

  # Custom filter with lambda
  filter :published, with: ->(scope, value) {
    value ? scope.where.not(published_at: nil) : scope.where(published_at: nil)
  }
end
```

Available Text filter predicates include: `:eq`, `:not_eq`, `:matches`, `:not_matches`, `:starts_with`, `:ends_with`, `:contains`, `:not_contains`.

## Query Scopes

Scopes allow users to apply predefined queries with a single click. Define them using the `scope` method, which can reference an existing model scope or a new lambda.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Reference existing scopes from the Post model
  scope :published
  scope :featured

  # Define a custom scope with a lambda
  scope :recent, -> { where("created_at > ?", 1.week.ago) }

  # Set a default scope
  scope :active, default: true
end
```
A scopes bar will automatically be displayed above the table.

## Sorting

Enable sorting on columns by defining a `sort` rule. Columns automatically become sortable when a sort definition exists for them.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Define sort rules for columns
  sort :title
  sort :created_at
  sort :updated_at

  # Custom sorting logic
  sort :author_name, using: "users.name" do |scope, direction:|
    scope.joins(:author).order("users.name #{direction}")
  end
  
  # Default sort when no user sorting is applied
  default_sort :created_at, :desc  # Simple form
  # or with a block for complex sorting:
  # default_sort { |scope| scope.order(featured: :desc, created_at: :desc) }
end
```

Plutonium's tables support both tri-state and multi-column sorting, providing flexible data exploration.

*   **Tri-state Sorting**: Clicking a column header cycles through ascending (`ASC`), descending (`DESC`), and unsorted states for that column.
*   **Multi-column Sorting**: You can apply sorting to multiple columns. Simply click on the headers of the columns you wish to sort by. The order in which you select them determines their priority. An indicator next to the column title shows the sort order and priority.

## Pagination

Pagination is handled automatically by the excellent [Pagy](https://github.com/ddnexus/pagy) gem. In your controller, the `pagy` helper method prepares your records for pagination.

```ruby
# In your controller (usually handled by Plutonium::Controller::CrudActions)
@pagy, @resource_records = pagy(current_authorized_scope)
```

The table component renders pagination controls and an info bar, allowing users to navigate through pages and change the number of items per page.

## Actions

Actions defined on your resource will automatically appear in the `actions` column for each row.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Standard CRUD actions are available by default
  # action :show
  # action :edit
  # action :destroy

  # Add custom actions
  action :publish, interaction: PublishPostInteraction
  action :archive, interaction: ArchivePostInteraction
end
```

Plutonium checks the user's permissions for each action and only displays the ones they are allowed to perform.

## Customization

### Overriding the Table View

For deep customization, you can define a nested `Table` class within your resource definition. This allows you to override any part of the table rendering process.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Define a custom table class
  class Table < Plutonium::UI::Table::Resource
    private

    # Customize the footer
    def render_footer
      div(class: "custom-footer") do
        super # Render the original footer (pagination, etc.)
        render_custom_stats
      end
    end

    def render_custom_stats
      div(class: "mt-4 text-sm text-gray-500") do
        "Total Posts: #{collection.size}"
      end
    end
  end
end
```

### Empty State

When a query returns no results, the table displays a helpful message. You can customize this by overriding `render_empty_card`.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  class Table < Plutonium::UI::Table::Resource
    private

    def render_empty_card
      EmptyCard("No posts were found.") {
        # Optionally, add a call to action
        if current_policy.allowed_to?(:create?)
          # ... render a "Create Post" button
        end
      }
    end
  end
end
```

### Theming

The table's appearance is controlled by a central theme. You can inspect `lib/plutonium/ui/table/theme.rb` and `lib/plutonium/ui/table/display_theme.rb` to see the default Tailwind CSS classes and override them if needed.
