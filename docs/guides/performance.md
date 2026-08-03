# Performance: N+1 Queries

Plutonium renders association values for you: a `display :author`, a table `column :organization`, a grid or kanban card showing a related name. Reading an association off a record that wasn't loaded with it costs a query, so an index page runs one query for the page plus one per row per association.

## Spotting it

Tail the log and reload an index. A run of near-identical `SELECT * FROM users WHERE id = ?` lines, one per row, is the signature.

```bash
tail -f log/development.log
```

[`bullet`](https://github.com/flyerhzm/bullet) reports them in development if you'd rather be told than look.

The cost matters most where each query is a network round trip. On Postgres or MySQL an index page can spend most of its time waiting; on SQLite the same page is cheaper, though the query count is identical. Either way the count grows with page size, so a listing that is fine at 20 rows may not be at 200.

## Eager loading

### One listing

Override `filtered_resource_collection` and add the associations that page renders. `super` keeps authorization scoping, search, filters, scopes and sorting:

```ruby
class PostsController < ::ResourceController
  private

  def filtered_resource_collection = super.includes(:author, :category)
end
```

See [Behavior › Controllers](/reference/behavior/controllers#index-query-hook).

### Everywhere

`filtered_resource_collection` only covers the index. When an association is also read on a show page, an export or a typeahead, put it in the policy's `relation_scope` instead:

```ruby
class PostPolicy < ResourcePolicy
  relation_scope do |relation|
    default_relation_scope(relation).includes(:author, :category)
  end
end
```

A custom `relation_scope` must still call `default_relation_scope`, or scoping is dropped. See [Behavior › Policies](/reference/behavior/policies).

## Automatic eager loading

Which associations a page renders is decided by the definition, so a hand-written `includes` list is a guess that goes stale when a column is added.

[Goldiloader](https://github.com/salsify/goldiloader) removes the bookkeeping. It hooks association traversal: reading `post.author` on a record from a collection loads that association for the whole collection in one query. No `includes` anywhere.

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
