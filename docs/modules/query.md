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
- **Type-Safe Filtering**: Built-in filters for different data types (text, boolean, select, date range).
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

  # Define available filters.
  filter :published, with: Plutonium::Query::Filters::Boolean
  filter :category, with: Plutonium::Query::Filters::Select, choices: %w[Tech Business]
  filter :created_at, with: Plutonium::Query::Filters::DateRange

  # Define named scopes that appear as buttons.
  scope :published
  scope :recent, -> { where('created_at > ?', 1.week.ago) }

  # Define which columns are sortable.
  sort :title
  sort :created_at
  sort :view_count
end
```

## Built-in Filters

Plutonium provides several built-in filter types that you can use with the `filter` method.

::: code-group
```ruby [BooleanFilter]
# Renders a dropdown with "Yes", "No", "Any".
filter :published, with: Plutonium::Query::Filters::Boolean
```
```ruby [SelectFilter]
# Renders a select dropdown.
# Choices can be a static array...
filter :category, with: Plutonium::Query::Filters::Select,
       choices: %w[Tech Business Lifestyle]

# ...or a dynamic lambda.
filter :author, with: Plutonium::Query::Filters::Select,
       choices: -> { User.pluck(:name, :id) }
```
```ruby [DateRangeFilter]
# Renders two date inputs for a start and end date.
filter :created_at, with: Plutonium::Query::Filters::DateRange
```
```ruby [TextFilter]
# Provides various text-matching predicates.
filter :title, with: Plutonium::Query::Filters::Text,
       predicate: :contains # :eq, :starts_with, :ends_with, etc.
```
:::

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
  query.define_filter(:published, ...)
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
- **Filters**: `?q[filters][published]=true&q[filters][category]=tech`
- **Scope**: `?q[scope]=recent`
- **Sorting**: `?q[s]=created_at+desc`

A combined example:
`/posts?q[search]=rails&q[filters][published]=true&q[scope]=recent&q[s]=created_at+desc`
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
