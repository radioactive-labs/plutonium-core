# Performance: N+1 Queries

Plutonium renders association values for you — a `display :author`, a table `column :organization`, a grid or kanban card that shows a related name. Each of those reads an association off a record, and if the collection wasn't loaded with that association, Rails fetches it one record at a time.

That is the N+1 problem, and index pages are where it shows up first: one query for the page of records, then one more per row per association.

## Seeing it

It is not subtle once you count. This is a real Plutonium index (`Blogging::Post`, whose table shows `user` and `organization`), counting `sql.active_record` events per request:

| Rows on the page | Total queries | Queries against `users` |
|---|---|---|
| 1 | 8 | 4 |
| 5 | 12 | 8 |
| 15 | 22 | 18 |

Queries grow **one per row**. At the default page size that is a few dozen; raise the page size and it grows with it.

The cheapest way to watch this in your own app is the query log — `tail -f log/development.log` and reload an index. A wall of near-identical `SELECT * FROM users WHERE id = ?` lines is the signature. [`bullet`](https://github.com/flyerhzm/bullet) will flag them for you in development if you'd rather be told than look.

## Does it actually matter on SQLite?

Less than the folklore says, but not nothing — and "SQLite makes N+1 free" is not what the numbers show. Measured against this repo's own dummy app on SQLite, timing only the query layer (fetch N posts, read `post.user` on each):

| Rows | N+1 | `includes` | Ratio |
|---|---|---|---|
| 20 | 2.78 ms | 0.64 ms | **4.4×** |
| 100 | 14.97 ms | 1.40 ms | **10.7×** |
| 200 | 24.83 ms | 2.41 ms | **10.3×** |

An order of magnitude, with no network anywhere. The reason is that most of the per-query cost isn't the database at all — it's ActiveRecord's Ruby-side work: building the relation, dispatching, instantiating objects, type-casting columns. That cost is adapter-independent, which is why removing the round trip doesn't rescue you.

What SQLite *does* change is whether that difference is worth your attention, because the query layer is a small slice of a real request. The same pages, timed end to end through the full stack:

| Rows | N+1 | `includes` |
|---|---|---|
| 20 | 48.2 ms | 42.3 ms |
| 100 | 161.3 ms | 132.5 ms |

At 20 rows the win is a couple of milliseconds out of ~45 — at or below run-to-run noise, and invisible to a user. At 100 rows it is ~18% of the request. Rendering dominates either way.

So a fair reading:

- **N+1 on SQLite is not a crisis.** The advice that it is comes from network-attached databases, where each of those N queries is a round trip and the same page falls off a cliff. Carrying that alarm over to SQLite is miscalibrated.
- **It is still ~10× the query cost**, and it grows with page size while eager loading stays flat. It is a real cost that happens to be small at small N.
- **It is not "recommended".** There is no upside to the extra queries; there is only a threshold below which the upside of fixing them is too small to chase.

::: tip A usable rule
Don't hunt N+1s on a 20-row admin listing backed by SQLite — you will spend more time maintaining `includes` lists than you save. Do fix them when page size is large, when several associations render per row, or when you deploy on Postgres/MySQL, where the same access pattern costs a round trip each and the numbers above get much worse.

And don't read a local SQLite timing as proof a page is fast on a networked database — the query count is identical, only the per-query cost changed.
:::

## Fixing it: eager-load the collection

### For an index page — `filtered_resource_collection`

The index collection goes through the [`filtered_resource_collection`](/reference/behavior/controllers#index-query-hook) controller hook. Override it and add the associations the page renders:

```ruby
class Blogging::PostsController < ::ResourceController
  private

  def filtered_resource_collection
    super.includes(:user, :organization)
  end
end
```

`super` keeps authorization scoping, search, filters, scopes and sorting intact — you are only adding the eager load.

Same measurement as above, with that override in place:

| Rows on the page | Total queries | Queries against `users` |
|---|---|---|
| 1 | 9 | 4 |
| 5 | 9 | 4 |
| 15 | 9 | 4 |

**Flat.** One extra query up front buys a constant, and the page stops caring how many rows it shows.

### For every read — `relation_scope`

`filtered_resource_collection` only covers the index. If a show page renders a `has_many`, or an association is read in several places, put the eager load in the policy's [`relation_scope`](/reference/behavior/policies) instead so every authorized read gets it:

```ruby
class Blogging::PostPolicy < ResourcePolicy
  relation_scope do |relation|
    default_relation_scope(relation).includes(:user, :organization)
  end
end
```

Remember the rule from [Behavior › Policies](/reference/behavior/policies): a custom `relation_scope` **must** end up calling `default_relation_scope`, or scoping is silently dropped.

::: tip Which one?
`filtered_resource_collection` is the surgical choice — it eager-loads only for the listing that needs it. `relation_scope` is broader and will also eager-load for a single-record `show`, a typeahead lookup, or an export, where the join may be wasted. Start with the controller hook; reach for the policy when the same association is read from several actions.
:::

## Fixing it: let a gem do it

Hand-maintained `includes` lists rot. A column gets added to a definition, nobody updates the controller, and the N+1 comes back silently — nothing fails, the page just gets slower.

[**Goldiloader**](https://github.com/salsify/goldiloader) removes the bookkeeping. It hooks association traversal: the first time you read `post.user` on a record that came from a collection, it loads that association for *every* record in the collection with a single `WHERE id IN (…)`, instead of one query per record. No `includes` anywhere.

```ruby
# Gemfile
gem "goldiloader"
```

That is usually all of it — it works out of the box and needs no per-model configuration. It suits Plutonium well, because the associations a page reads are decided by the definition at render time, which is exactly the thing an up-front `includes` list has to guess.

Know the trade-offs before you add it:

- **It assumes uniform access.** Reading an association on one record eager-loads it for the whole collection. When only one row actually needs it, that is over-fetching.
- **`has_one` with an order and a limit is a sharp edge.** Eager loading makes `LIMIT 1` apply to the whole query rather than per parent, so it can pull far more rows than expected.
- **It disables itself** for associations declared with `limit`, `offset`, or `finder_sql`.
- **Opting out** is per-query (`Post.all.auto_include(false)`), per-association (`has_many :comments, -> { auto_include(false) }`), or globally (`Goldiloader.globally_enabled = false`, then re-enable in `Goldiloader.enabled { }` blocks).

[`ar_lazy_preload`](https://github.com/DmitryTsepelev/ar_lazy_preload) is the alternative, with the same idea reached differently — it preloads lazily on first access, and `ArLazyPreload.config.auto_preload = true` makes it automatic everywhere. Its own docs warn that enabling `auto_preload` on an existing app can surface edge cases, so introduce it deliberately rather than as a default.

Neither gem is a substitute for knowing what your page queries. They are a good default that stops the common case from regressing; a genuinely hot page still deserves an explicit `includes` and a look at the log.

## Beyond eager loading

- **Page size.** N+1 cost scales with rows per page. See [Resource › Query](/reference/resource/query) for pagination options.
- **Search fallback.** A resource with no `search` block falls back to a leading-wildcard `LIKE`, which cannot use a b-tree index and degrades past a few thousand rows. Write an explicit `search` block backed by a trigram or full-text index — see [Query › Search](/reference/resource/query#search).
- **`count` on large tables.** Pagination needs a count; on very large Postgres tables an exact `COUNT(*)` is itself a slow query.
