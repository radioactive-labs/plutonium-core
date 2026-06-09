# Query

Search, filters, scopes, and sorting for a resource's index page. All declared in the definition.

## Overview

```ruby
class PostDefinition < Plutonium::Resource::Definition
  search do |scope, query|
    scope.where("title ILIKE ?", "%#{query}%")
  end

  filter :title,      with: :text,        predicate: :contains
  filter :status,     with: :select,      choices: %w[draft published archived]
  filter :published,  with: :boolean
  filter :created_at, with: :date_range

  scope :published
  default_scope :published

  sort :title
  sort :created_at
  default_sort :created_at, :desc
end
```

## Search

`search` defines global free-text search. The block receives the scope and the query string; return a filtered relation.

```ruby
search do |scope, query|
  scope.where("title ILIKE ?", "%#{query}%")
end
```

### Multi-field

```ruby
search do |scope, query|
  scope.where(
    "title ILIKE :q OR content ILIKE :q OR author_name ILIKE :q",
    q: "%#{query}%"
  )
end
```

### Across associations

```ruby
search do |scope, query|
  scope.joins(:author).where(
    "posts.title ILIKE :q OR users.name ILIKE :q",
    q: "%#{query}%"
  ).distinct
end
```

### Split terms

```ruby
search do |scope, query|
  query.split(/\s+/).reduce(scope) do |s, term|
    s.where("title ILIKE ?", "%#{term}%")
  end
end
```

### Search powers typeahead too

The same `search` block drives **typeahead lookups** on association inputs that target this resource — when you write `input :author, …` for an association, the dropdown's autocomplete calls the target resource's `search` block.

::: tip Typeahead fallback when there's no search block
A resource without a `search` block still gets typeahead — the framework runs a case-insensitive `LIKE` against the first column that exists, in priority order:

1. The input's `label_method:` option, if it names a real column on the model.
2. Otherwise the first match from `[name, title, label, slug, display_name, email]`.
3. If none exist, the relation is returned unfiltered (capped).

For large tables, write an explicit `search` block backed by a trigram or full-text index. The fallback's leading-wildcard `LIKE '%q%'` can't use a b-tree index and gets slow past a few thousand rows.
:::

## Filters

Six built-in filter types. Use the shorthand symbol or the full class name.

| Type | Symbol | Params in URL | Options |
|---|---|---|---|
| Text | `:text` | `query` | `predicate:` |
| Boolean | `:boolean` | `value` | `true_label:`, `false_label:` |
| Date | `:date` | `value` | `predicate:` |
| Date range | `:date_range` | `from`, `to` | `from_label:`, `to_label:` |
| Select | `:select` | `value` | `choices:`, `multiple:` |
| Association | `:association` | `value` | `class_name:`, `multiple:` |

### Text predicates

`:eq`, `:not_eq`, `:contains`, `:not_contains`, `:starts_with`, `:ends_with`, `:matches`, `:not_matches`

```ruby
filter :title,  with: :text, predicate: :contains
filter :status, with: :text, predicate: :eq
filter :title,  with: Plutonium::Query::Filters::Text, predicate: :contains   # full class form
```

### Boolean

```ruby
filter :active,    with: :boolean
filter :published, with: :boolean, true_label: "Published", false_label: "Draft"
```

### Date

Predicates: `:eq`, `:not_eq`, `:lt`, `:lteq`, `:gt`, `:gteq`.

```ruby
filter :created_at,   with: :date, predicate: :gteq
filter :due_date,     with: :date, predicate: :lt
filter :published_at, with: :date, predicate: :eq
```

### Date range

Two inputs (`from` + `to`):

```ruby
filter :created_at,   with: :date_range
filter :published_at, with: :date_range,
  from_label: "Published from",
  to_label:   "Published to"
```

### Select

```ruby
filter :status,   with: :select, choices: %w[draft published archived]
filter :category, with: :select, choices: -> { Category.pluck(:name) }
filter :tags,     with: :select, choices: %w[ruby rails js], multiple: true
```

### Association

```ruby
filter :category, with: :association
filter :author,   with: :association, class_name: User
filter :tags,     with: :association, class_name: Tag, multiple: true
```

### Custom filter (lambda)

For simple one-offs:

```ruby
filter :published, with: ->(scope, value) {
  value == "true" ? scope.where.not(published_at: nil) : scope.where(published_at: nil)
}
```

### Custom filter class

For anything reusable or with multiple inputs:

```ruby
class PriceRangeFilter < Plutonium::Query::Filter
  def apply(scope, min: nil, max: nil)
    scope = scope.where("price >= ?", min) if min.present?
    scope = scope.where("price <= ?", max) if max.present?
    scope
  end

  def customize_inputs
    input :min, as: :number
    input :max, as: :number
    field :min, placeholder: "Min price..."
    field :max, placeholder: "Max price..."
  end
end

filter :price, with: PriceRangeFilter
```

## Scopes

Scopes appear as quick-filter buttons across the top of the table.

```ruby
class PostDefinition < ResourceDefinition
  scope :published    # uses Post.published
  scope :draft        # uses Post.draft

  # Inline scope — block runs with the scope as argument
  scope(:recent)   { |s| s.where('created_at > ?', 1.week.ago) }
  scope(:this_month) { |s| s.where(created_at: Time.current.all_month) }
end
```

Named scopes reference a model scope of the same name. Inline (block) scopes have access to controller context (`current_user`, `current_parent`, etc.):

```ruby
scope(:mine)    { |s| s.where(author: current_user) }
scope(:my_team) { |s| s.where(team: current_user.team) }
```

### Default scope

```ruby
default_scope :published
```

When a default is set:

- It applies on initial page load.
- The default scope button is highlighted (not "All").
- Clicking "All" shows the unscoped collection.

### Conditional visibility — `condition:`

Like `condition:` on [actions](./actions), a scope can be **defined but only render its button when a runtime proc is truthy**. The scope (and its URL) stays live either way — `condition:` only toggles the button.

```ruby
scope :admin_only,   condition: -> { current_user.admin? }
scope :beta_feature, condition: -> { params[:beta] == "1" }

# Expose a scope's URL (API/programmatic) without surfacing a button
scope :internal, condition: -> { false }
```

The proc is evaluated against the view context so `current_user`, `params`, `request`, and `allowed_to?` are all available directly. There is no `object`/`record` — scopes have no single-record context.

::: danger `condition:` is NOT authorization
A hidden scope button still has a **live URL** anyone can navigate to. `condition:` decides whether the *button renders*, not whether the *records are accessible*.

Use `condition:` for UI relevance ("show this tab to admins only"). Use the policy's `relation_scope` to restrict which records a user can see at all.
:::

## Sorting

```ruby
sort :title
sort :created_at

sorts :title, :created_at, :view_count    # shorthand for several at once

default_sort :created_at, :desc

# Complex default sort with a block
default_sort { |scope| scope.order(featured: :desc, created_at: :desc) }
```

The framework default (no `default_sort` declared, no user sort) is `id DESC`.

## URL parameters

Query parameters are namespaced under `q`:

```
/posts?q[search]=rails
/posts?q[title][query]=widget
/posts?q[status][value]=published
/posts?q[created_at][from]=2024-01-01&q[created_at][to]=2024-12-31
/posts?q[scope]=recent
/posts?q[sort_fields][]=created_at&q[sort_directions][created_at]=desc
```

Combined:

```
/posts?q[search]=rails&q[scope]=published&q[sort_fields][]=created_at&q[sort_directions][created_at]=desc
```

## Common patterns

### Full-text search with `pg_search`

```ruby
# Model
class Post < ResourceRecord
  include PgSearch::Model
  pg_search_scope :search_content, against: %i[title content]
end

# Definition
search do |scope, query|
  scope.search_content(query)
end
```

### Status filter + scopes

```ruby
filter :status, with: :select, choices: %w[draft published archived]
scope :draft
scope :published
scope :archived
```

### Date-based scopes

```ruby
# Model
scope :today,      -> { where(created_at: Time.current.all_day) }
scope :this_week,  -> { where(created_at: Time.current.all_week) }
scope :this_month, -> { where(created_at: Time.current.all_month) }

# Definition
scope :today
scope :this_week
scope :this_month
```

## Performance

- **Add indexes** for filtered and sorted columns.
- **Use `.distinct`** when joining associations in search to avoid duplicate rows.
- **Prefer scopes over filters** for queries used often (faster, no input parsing).
- **`pg_search` / FTS** for complex search — write an explicit `search` block.
- **`LIKE '%q%'` can't use a b-tree index** — the typeahead fallback and naive search blocks get slow on large tables. Plan a trigram or full-text index when scaling.

## Related

- [Definition](./definition) — field/input/display configuration
- [Actions](./actions) — custom and bulk actions
- [Behavior › Policy](/reference/behavior/policies) — `relation_scope` (filters records to what the user can see)
- [Tenancy › Entity scoping](/reference/tenancy/entity-scoping) — multi-tenant filtering
