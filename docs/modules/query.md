---
title: Query Module
---

# Query Module

The Query module provides a powerful and flexible system for filtering, searching, and sorting resources in Plutonium applications. It enables declarative query configuration and automatic UI generation for data exploration.

::: tip
The Query module is located in `lib/plutonium/query/`. Query logic is typically defined inside a resource's Definition file.
:::

## Overview

- **Declarative Configuration**: Define filters, scopes, and sorters declaratively in your resource definition.
- **Type-Safe Filtering**: Built-in filters for different data types (currently Text filter with various predicates).
- **Search Integration**: Full-text search across multiple fields.
- **Sorting Support**: Multi-field sorting with configurable directions.
- **UI Integration**: Seamlessly powers search bars, filter forms, and sortable table headers.

## Defining a Query

All query logic—search, filters, scopes, and sorting—is defined inside a resource definition file. This configuration is then used to build a `QueryObject` in the controller.

```ruby
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # Define the global search logic.
  search do |scope, search|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{search}%", "%#{search}%")
  end

  # Define available filters (currently only Text filter is implemented).
  filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains
  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq
  filter :category, with: Plutonium::Query::Filters::Text, predicate: :eq

  # Define named scopes that appear as buttons.
  scope :published
  scope :recent, -> { where('created_at > ?', 1.week.ago) }

  # Define which columns are sortable.
  sort :title
  sort :created_at
  sort :view_count
  
  # Define default sort (when no sort params are provided)
  default_sort :created_at, :desc  # or default_sort { |scope| scope.order(featured: :desc, created_at: :desc) }
end
```

## Built-in Filters

Currently, Plutonium provides the **Text filter** with various predicates for different matching behaviors.

::: code-group
```ruby [Text Filter with Predicates]
# Exact match (default)
filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq

# Contains (LIKE with wildcards)
filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains

# Starts with
filter :slug, with: Plutonium::Query::Filters::Text, predicate: :starts_with

# Ends with
filter :email, with: Plutonium::Query::Filters::Text, predicate: :ends_with

# Not equal
filter :status, with: Plutonium::Query::Filters::Text, predicate: :not_eq

# Not contains
filter :content, with: Plutonium::Query::Filters::Text, predicate: :not_contains

# Pattern matching with wildcards (* becomes %)
filter :title, with: Plutonium::Query::Filters::Text, predicate: :matches

# Not matching pattern
filter :title, with: Plutonium::Query::Filters::Text, predicate: :not_matches
```
:::

### Available Text Filter Predicates
- `:eq` - Equal (exact match)
- `:not_eq` - Not equal
- `:contains` - LIKE with wildcards on both sides
- `:not_contains` - NOT LIKE with wildcards on both sides
- `:starts_with` - LIKE with suffix wildcard
- `:ends_with` - LIKE with prefix wildcard
- `:matches` - LIKE with user-provided wildcards (* becomes %)
- `:not_matches` - NOT LIKE with user-provided wildcards

## Controller Integration

The `QueryObject` is automatically created in your resource controllers and applied to the base collection.

::: code-group
```ruby [Controller]
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  def index
    # `filtered_resource_collection` applies the query object.
    # The results are then paginated.
    @pagy, @resource_records = pagy(filtered_resource_collection)
  end

  private

  # This helper method shows how the query is applied.
  def filtered_resource_collection
    # 1. Start with the authorized base scope (from the policy).
    base_query = current_authorized_scope
    # 2. Apply the filters, search, sort, and scope from the query object.
    current_query_object.apply(base_query, raw_resource_query_params)
  end
end
```
```ruby [QueryObject]
# The `current_query_object` is built automatically.
# This is a simplified view of what happens behind the scenes.
query_object = Plutonium::Resource::QueryObject.new(Post, params[:q] || {}) do |query|
  # Definitions from PostDefinition are added here.
  query.define_search(...)
  query.define_filter(:title, ...)
  query.define_scope(:recent, ...)
  query.define_sorter(:title, ...)
end

# The `apply` method executes the query.
filtered_scope = query_object.apply(Post.all, params[:q])
```
:::

## URL Parameters

Query parameters are structured under the `q` key in the URL.

::: details URL Parameter Format
- **Search**: `?q[search]=rails`
- **Filters**: `?q[title][query]=rails&q[status][query]=published`
- **Scope**: `?q[scope]=recent`
- **Sorting**: `?q[sort_fields][]=created_at&q[sort_directions][created_at]=desc`

A combined example:
`/posts?q[search]=rails&q[title][query]=tutorial&q[scope]=recent&q[sort_fields][]=created_at&q[sort_directions][created_at]=desc`
:::

## Advanced Usage

::: details Custom Filter Classes
You can create custom filter classes for complex logic.
```ruby
# 1. Define your custom filter class.
class CustomRangeFilter < Plutonium::Query::Filter
  def initialize(key:, **options)
    super
    @key = key
  end

  # This method applies the filter to the scope.
  def apply(scope, min: nil, max: nil)
    scope = scope.where("#{@key} >= ?", min) if min.present?
    scope = scope.where("#{@key} <= ?", max) if max.present?
    scope
  end

  # This defines the inputs for the filter form.
  def customize_inputs
    input :min, as: :number
    input :max, as: :number
  end
end

# 2. Use it in your resource definition.
class PostDefinition < Plutonium::Resource::Definition
  filter :view_count, with: CustomRangeFilter
end
```
:::

::: details Complex Search Examples
```ruby
# Multi-field search with associations
search do |scope, search|
  scope.joins(:author, :tags).where(
    "posts.title ILIKE :search OR posts.content ILIKE :search OR users.name ILIKE :search",
    search: "%#{search}%"
  ).distinct
end

# Search with term splitting
search do |scope, search|
  terms = search.split(/\s+/)
  terms.reduce(scope) do |current_scope, term|
    current_scope.where(
      "title ILIKE ? OR content ILIKE ?",
      "%#{term}%", "%#{term}%"
    )
  end
end
```
:::

## Query Object API

The QueryObject provides methods for building URLs and applying filters programmatically.

### Key Methods

- `define_filter(name, body)` - Define a custom filter
- `define_scope(name, body)` - Define a scope filter
- `define_sorter(name, body)` - Define a custom sorter
- `define_search(body)` - Define search functionality
- `apply(scope, params)` - Apply filters and sorting to a scope
- `build_url(**options)` - Build URLs with query parameters

### Usage Example

```ruby
# Automatic usage through controllers
GET /posts?q[search]=rails&q[title][query]=tutorial&q[sort_fields][]=created_at&q[sort_directions][created_at]=desc

# Manual usage in controller
query_object = current_query_object
@resource_records = query_object.apply(current_authorized_scope, params[:q])

# Building URLs for links
next_page_url = query_object.build_url(search: "new search term")
sorted_url = query_object.build_url(sort: :title)
```

## Advanced Query Object Examples

**Custom Date Range Filter**
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

# Usage in definition
filter :created_at, with: DateRangeFilter
```

**Conditional Scoping with User Context**
```ruby
class PostDefinition < Plutonium::Resource::Definition
  scope :my_posts, -> { where(author: current_user) }
  scope :drafts, -> { where(published: false) }
  scope :published_last_week, -> {
    where(published: true, created_at: 1.week.ago..Time.current)
  }
end
```

## Best Practices

### Filter Design
- Use Text filters with appropriate predicates for most use cases
- Create custom filter classes for complex multi-input filters (date ranges, number ranges)
- Keep filter logic focused and single-responsibility

### Search Implementation
- Include commonly searched fields in your search scope
- Use ILIKE for case-insensitive matching
- Consider performance impact of JOINs in search queries
- Use `.distinct` when searching across associations

### Default Sorting
- Define a default sort to show newest items first by default: `default_sort :id, :desc`
- Use field and direction: `default_sort :created_at, :desc`
- Or use a block for complex sorting: `default_sort { |scope| scope.order(featured: :desc, created_at: :desc) }`
- The default sort is only applied when no sort parameters are provided by the user
- Child definitions inherit the default sort from parent definitions

### URL Structure
- The `q` parameter namespace keeps query params organized
- All filter inputs are nested under their filter name
- Sort parameters are arrays to support multi-column sorting

The Query module provides a powerful foundation for building searchable, filterable interfaces while maintaining clean separation of concerns and consistent URL patterns.

## Related Modules

- **[Definition](./definition.md)** - Resource definitions and DSL
- **[Resource Record](./resource_record.md)** - Resource controllers and CRUD operations
- **[UI](./ui.md)** - User interface components
