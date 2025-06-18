---
title: Table Module
---

# Table Module

The Table module provides a comprehensive data table system for Plutonium applications. Built on top of `Phlexi::Table`, it offers pagination, sorting, filtering, search, and scoped queries for displaying and interacting with resource collections.

::: tip
The Table module is located in `lib/plutonium/ui/table/`. Tables are primarily configured within a resource's Definition file.
:::

## Overview

- **Resource-Aware Tables**: Automatically generated tables based on resource definitions.
- **Pagination**: Pagy-powered pagination with configurable page sizes.
- **Sorting & Filtering**: Multi-column sorting and advanced filtering.
- **Search & Scopes**: Full-text search and predefined query scopes.
- **Actions**: Row-level and bulk actions for resource manipulation.
- **Responsive Design**: Mobile-friendly tables with horizontal scrolling.

## Defining a Table

Table columns and behaviors are defined within a resource definition file.

```ruby
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # Define which columns to display and their properties.
  # The `display` method is an alias for `column`.
  display :title, sortable: true
  display :author, as: :association
  display :published_at, as: :datetime
  display :status, as: :badge
  display :actions, as: :actions, align: :right

  # Define sorting rules.
  sort :title
  sort :published_at

  # Define search logic.
  search do |scope, search|
    scope.where("title ILIKE ?", "%#{search}%")
  end

  # Define filters.
  filter :published, with: Plutonium::Query::Filters::Boolean
  filter :author, with: Plutonium::Query::Filters::Select,
         choices: -> { User.pluck(:name, :id) }

  # Define scopes.
  scope :published
  scope :draft
end
```

## Core Components

### Resource Table

The `Plutonium::UI::Table::Resource` component is the main entry point for rendering a resource table. It's used automatically on resource index pages.

::: details Resource Table Implementation
```ruby
# lib/plutonium/ui/table/resource.rb
class Plutonium::UI::Table::Resource < Plutonium::UI::Component::Base
  def initialize(records:, pagy:, **)
    @records = records
    @pagy = pagy
    # ... and other options
  end

  def view_template
    # Renders the search bar and filter form
    render_query_form

    # Renders the scope buttons (e.g., "All", "Published", "Draft")
    render_scopes_bar

    # Renders the main table or an empty state card
    @records.empty? ? render_empty_card : render_table

    # Renders pagination controls
    render_footer
  end

  private

  def render_table
    # Uses Phlexi::Table::Base to build the table
    render Plutonium::UI::Table::Base.new(@records) do |table|
      # Iterates through the columns defined in the resource definition
      resource_fields.each do |name|
        table.column name,
          sort_params: current_query_object.sort_params_for(name),
          &column_renderer(name)
      end
    end
  end
end
```
:::

### Theming

The table's appearance is controlled by a theme file, which you can customize.

```ruby
# lib/plutonium/ui/table/theme.rb
class Plutonium::UI::Table::Theme < Phlexi::Table::Theme
  def self.theme
    super.merge({
      wrapper: "relative overflow-x-auto shadow-md sm:rounded-lg",
      base: "w-full text-sm text-left text-gray-500 dark:text-gray-400",
      header: "text-xs text-gray-700 uppercase bg-gray-200 dark:bg-gray-700",
      body_row: "bg-white border-b dark:bg-gray-800 dark:border-gray-700",
      # ... and many more theme options
    })
  end
end
```

## Key Features

### Sorting

Enable sorting by defining `sort` rules in your resource definition.

::: code-group
```ruby [Simple Sort]
# Enable sorting on a database column.
sort :title
sort :created_at
```
```ruby [Custom Sort Logic]
# Provide a block for complex sorting, e.g., to handle NULLs.
sort :priority do |scope, direction|
  scope.order(Arel.sql("priority #{direction} NULLS LAST"))
end
```
```ruby [Association Sort]
# Sort by a column on a joined table.
sort :author_name, on: "users.name" do |scope, direction|
  scope.joins(:author).order("users.name #{direction}")
end
```
:::

### Empty State

When a query returns no results, a helpful "empty card" is displayed, which can include a call to action.

::: details Empty State Implementation
```ruby
# Part of Plutonium::UI::Table::Resource
def render_empty_card
  # Renders a card with a message like "No Posts match your query"
  EmptyCard("No #{resource_name_plural} match your query") do
    # Optionally, renders the "New" action button if permitted.
    action = resource_definition.defined_actions[:new]
    if action&.permitted_by?(current_policy)
      url = # ... build URL for new action
      ActionButton(action, url: url)
    end
  end
end
```
:::
