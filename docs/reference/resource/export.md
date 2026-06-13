# CSV Export

Every resource ships with a streamed CSV export, **disabled by default**. It is *not* an
[action](./actions.md) — it streams a file and opens in a new tab — so it is enabled
through the policy rather than declared with `action :export_csv`. The route
(`GET /<resources>/export_csv`) is auto-mounted on every resource; a split "Export"
button appears on the index page once the policy permits it.

## Enabling

Override one policy method:

```ruby
class PostPolicy < ResourcePolicy
  def export_csv? = true   # or `index?` to mirror list access
end
```

`export_csv?` defaults to `false`, so export is strictly opt-in. While it returns false
the button is hidden and the route returns `403`.

## The two exports

The control is a split button with two behaviours:

| | Source | Filename |
|---|---|---|
| **Export** (primary) | The current view — selected scope + filters + search (the index's `?q`), **all** matching rows (not just the visible page) | `posts_<date>.csv` |
| **Export all** (dropdown) | The entire authorized scope — ignores scope, filters, search, and default scope | `posts_all_<date>.csv` |

"Export all" always exports everything the user is authorized to read, regardless of the
current scope/filters.

Both stream via `find_each`, so memory stays flat regardless of row count. `find_each`
iterates in **primary-key order**, so the file does not preserve the index's current
sort (filters/search/scope still apply to the primary export).

## Columns

The exported columns come from `permitted_attributes_for_export` on the policy (defaults
to `permitted_attributes_for_index`), with the **primary key always prepended as the
first column**.

```ruby
class PostPolicy < ResourcePolicy
  def export_csv? = true
  def permitted_attributes_for_export = [:title, :author, :total, :created_at]
end
```

The method is named `_export` (not `_export_csv`) on purpose, so a future export format
could reuse the same column set.

## Customizing a field's output

The `export` definition DSL parallels `display` and `column`. The block receives the
record and returns the cell value; `label:` overrides the header (default: the humanized
attribute name).

```ruby
class PostDefinition < ResourceDefinition
  export :author, label: "Author email", &->(post) { post.author.email }
  export :total,                          &->(post) { post.total.format }
end
```

The column *set* still comes from `permitted_attributes_for_export`; `export` only
customizes how a listed column is rendered.

## Value resolution

For a column **without** an `export` block, the value is read straight off the record
(`record.public_send(name)`):

- **Scalars** (strings, numbers, booleans, dates) are written as-is.
- **Associations** render as their display label — the same `display_name_of` the index
  uses (e.g. `User #5`, or the record's `to_label`/`name`/`title` if defined) — never
  `#<User:0x…>`. Add an `export` block to export a specific field instead (e.g. the email).
- A name that is **neither** an `export` block **nor** a real method on the record renders
  the placeholder `<<invalid column>>` rather than aborting the (already-streaming) download.
  To export a computed or virtual column, give it an `export` block — a `label:`-only
  `export` does **not** supply a value, so it too renders the placeholder.

## Notes & limits

- Exports run **synchronously** and hold the request (and a DB connection) while
  streaming. A background job that emails a download link is intentionally out of scope
  for now.
- The export button opens in a new tab (`target="_blank"`), which also keeps Turbo from
  intercepting the streamed download.
- **CSV/formula injection** is neutralized: any cell whose value begins with `=`, `+`,
  `-`, `@`, or a leading tab/CR is prefixed with a single quote so spreadsheet apps import
  it as literal text instead of executing it as a formula.
- `csv` is a runtime dependency of Plutonium (it is no longer a Ruby default gem on 3.4+).
