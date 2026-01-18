# Search and Filtering

This guide covers implementing search, filters, scopes, and sorting.

## Overview

Plutonium provides built-in support for:
- **Search** - Full-text search across fields
- **Filters** - Input filters for specific fields
- **Scopes** - Predefined query shortcuts (quick filter buttons)
- **Sorting** - Column-based ordering

## Search

Define global search in the definition:

```ruby
class PostDefinition < ResourceDefinition
  search do |scope, query|
    scope.where("title ILIKE ?", "%#{query}%")
  end
end
```

### Multi-Field Search

```ruby
search do |scope, query|
  scope.where(
    "title ILIKE :q OR content ILIKE :q OR author_name ILIKE :q",
    q: "%#{query}%"
  )
end
```

### Search with Associations

```ruby
search do |scope, query|
  scope.joins(:author).where(
    "posts.title ILIKE :q OR users.name ILIKE :q",
    q: "%#{query}%"
  ).distinct
end
```

### Split Search Terms

```ruby
search do |scope, query|
  terms = query.split(/\s+/)
  terms.reduce(scope) do |current_scope, term|
    current_scope.where("title ILIKE ?", "%#{term}%")
  end
end
```

### Full-Text Search (PostgreSQL)

```ruby
search do |scope, query|
  scope.where(
    "to_tsvector('english', title || ' ' || body) @@ plainto_tsquery('english', ?)",
    query
  )
end
```

## Filters

Filters provide UI controls for narrowing results.

### Text Filter

The built-in `Text` filter supports various predicates:

```ruby
class PostDefinition < ResourceDefinition
  # Exact match
  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq

  # Contains (LIKE %value%)
  filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains

  # Starts with
  filter :slug, with: Plutonium::Query::Filters::Text, predicate: :starts_with

  # Ends with
  filter :email, with: Plutonium::Query::Filters::Text, predicate: :ends_with
end
```

### Available Predicates

| Predicate | SQL | Description |
|-----------|-----|-------------|
| `:eq` | `= value` | Exact match |
| `:not_eq` | `!= value` | Not equal |
| `:contains` | `LIKE %value%` | Contains text |
| `:not_contains` | `NOT LIKE %value%` | Does not contain |
| `:starts_with` | `LIKE value%` | Starts with |
| `:ends_with` | `LIKE %value` | Ends with |
| `:matches` | `LIKE value` | Pattern match (`*` becomes `%`) |
| `:not_matches` | `NOT LIKE value` | Does not match pattern |

### Custom Filter with Lambda

```ruby
filter :published, with: ->(scope, value) {
  value == "true" ? scope.where.not(published_at: nil) : scope.where(published_at: nil)
}

filter :has_comments, with: ->(scope, value) {
  if value == "true"
    scope.joins(:comments).distinct
  else
    scope.left_joins(:comments).where(comments: { id: nil })
  end
}
```

### Custom Filter Class

```ruby
class DateRangeFilter < Plutonium::Query::Filter
  def apply(scope, start_date: nil, end_date: nil)
    scope = scope.where("#{key} >= ?", start_date.beginning_of_day) if start_date.present?
    scope = scope.where("#{key} <= ?", end_date.end_of_day) if end_date.present?
    scope
  end

  def customize_inputs
    input :start_date, as: :date
    input :end_date, as: :date
  end
end

# Use in definition
filter :created_at, with: DateRangeFilter
```

## Scopes

Scopes appear as quick filter buttons. They reference model scopes or use inline blocks.

### Basic Scopes

Reference existing model scopes:

```ruby
class PostDefinition < ResourceDefinition
  scope :published    # Uses Post.published
  scope :draft        # Uses Post.draft
  scope :featured     # Uses Post.featured
end
```

### Inline Scopes

Use block syntax with the scope passed as an argument:

```ruby
scope(:recent) { |scope| scope.where("created_at > ?", 1.week.ago) }
scope(:this_month) { |scope| scope.where(created_at: Time.current.all_month) }
```

### With Controller Context

Inline scopes have access to controller context like `current_user`:

```ruby
scope(:mine) { |scope| scope.where(author: current_user) }
scope(:my_team) { |scope| scope.where(team: current_user.team) }
```

### Default Scope

Set a scope as default:

```ruby
class PostDefinition < ResourceDefinition
  scope :published, default: true  # Applied by default
  scope :draft
  scope :archived
end
```

When a default scope is set:
- The default scope is applied on initial page load
- The default scope button is highlighted (not "All")
- Clicking "All" shows all records without any scope filter

## Sorting

### Define Sortable Fields

```ruby
class PostDefinition < ResourceDefinition
  sort :title
  sort :created_at
  sort :view_count

  # Multiple at once
  sorts :title, :created_at, :view_count
end
```

### Default Sort Order

```ruby
# Field and direction
default_sort :created_at, :desc
default_sort :title, :asc

# Complex sorting with block
default_sort { |scope| scope.order(featured: :desc, created_at: :desc) }
```

**Note:** Default sort only applies when no sort params are provided. The system default is `:id, :desc`.

## URL Parameters

Query parameters are structured under `q`:

```
/posts?q[search]=rails
/posts?q[status][query]=published
/posts?q[scope]=recent
/posts?q[sort_fields][]=created_at&q[sort_directions][created_at]=desc
```

## Complete Example

```ruby
class PostDefinition < ResourceDefinition
  # Full-text search
  search do |scope, query|
    scope.where(
      "title ILIKE :q OR content ILIKE :q",
      q: "%#{query}%"
    )
  end

  # Filters
  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq
  filter :category, with: Plutonium::Query::Filters::Text, predicate: :eq
  filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains

  # Quick scopes (reference model scopes)
  scope :published
  scope :draft
  scope :featured
  scope(:recent) { |scope| scope.where("created_at > ?", 1.week.ago) }

  # Sortable columns
  sorts :title, :created_at, :view_count, :published_at

  # Default: newest first
  default_sort :created_at, :desc
end
```

## Related

- [Custom Actions](./custom-actions)
- [Authorization](./authorization)
