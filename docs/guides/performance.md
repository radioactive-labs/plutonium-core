# Performance: N+1 Queries

Plutonium renders association values for you: a `display :author`, a table `column :organization`, a grid or kanban card showing a related name. Reading an association off a record that wasn't loaded with it costs a query, so an index page runs one query for the page plus one per row per association.

## Spotting it

Tail the log and reload an index. A run of near-identical `SELECT * FROM users WHERE id = ?` lines, one per row, is the signature.

```bash
tail -f log/development.log
```

[`bullet`](https://github.com/flyerhzm/bullet) reports them in development if you'd rather be told than look.

The cost matters most where each query is a network round trip. On Postgres or MySQL an index page can spend most of its time waiting; on SQLite the same page is cheaper, though the query count is identical. Either way the count grows with page size, so a listing that is fine at 20 rows may not be at 200.

## Collections preload themselves

Index pages, kanban boards and CSV exports already eager-load the associations and attachments they render. The field set comes from the policy, so the framework knows it before the collection loads and can preload exactly those. Nothing to declare, and nothing to keep in step when a field is added or removed.

Each rendering passes its own field set, because they differ: the index renders its permitted attributes, an export renders `permitted_attributes_for_export`, and a kanban card renders its `card_fields`.

It covers `belongs_to` and `has_one`, and attachments on both ActiveStorage and Shrine. `has_many` is excluded: preloading one to render a count loads every child row, which loses to a counter cache.

Turn it off globally:

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.auto_eager_load_index = false
end
```

Or per resource:

```ruby
class PostsController < ::ResourceController
  private

  def auto_eager_load_index? = false
end
```

## Eager loading by hand

Anything the framework can't see still needs declaring: an association read inside a custom column block, or one rendered on a show page.

### One listing

Override `filtered_resource_collection`. `super` keeps authorization scoping, search, filters, scopes and sorting:

```ruby
class PostsController < ::ResourceController
  private

  def filtered_resource_collection = super.includes(:author, :category)
end
```

See [Behavior › Controllers](/reference/behavior/controllers#index-query-hook).

### Everywhere

When an association is read on a show page, an export or a typeahead, put it in the policy's `relation_scope`:

```ruby
class PostPolicy < ResourcePolicy
  relation_scope do |relation|
    default_relation_scope(relation).includes(:author, :category)
  end
end
```

A custom `relation_scope` must still call `default_relation_scope`, or scoping is dropped. See [Behavior › Policies](/reference/behavior/policies).

## Automatic eager loading

For the cases above that the framework can't resolve for you, [Goldiloader](https://github.com/salsify/goldiloader) removes the bookkeeping. It hooks association traversal: reading `post.author` on a record from a collection loads that association for the whole collection in one query. No `includes` anywhere.

```ruby
# Gemfile
gem "goldiloader"
```

It works without per-model configuration. Before adding it:

- It assumes uniform access. Reading an association on one record loads it for every record, which over-fetches when only one row needed it.
- `has_one` with an order and a limit is a sharp edge: eager loading applies `LIMIT 1` to the whole query rather than per parent.
- It disables itself for associations declared with `limit`, `offset` or `finder_sql`.
- Opt out per query (`Post.all.auto_include(false)`), per association (`has_many :comments, -> { auto_include(false) }`) or globally (`Goldiloader.globally_enabled = false`).

[`ar_lazy_preload`](https://github.com/DmitryTsepelev/ar_lazy_preload) takes the same idea from the other end, preloading lazily on first access, with `ArLazyPreload.config.auto_preload = true` for automatic behaviour everywhere. Its docs warn that enabling it on an existing app can surface edge cases.

## Related

- **Search fallback.** A resource with no `search` block falls back to a leading-wildcard `LIKE`, which cannot use a b-tree index. Write an explicit `search` block for large tables — see [Resource › Query](/reference/resource/query#search).
- **Page size.** Query cost scales with rows per page.
