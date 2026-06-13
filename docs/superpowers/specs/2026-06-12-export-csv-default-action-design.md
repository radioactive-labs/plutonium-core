# Built-in CSV Export — Design

**Date:** 2026-06-12
**Status:** Implemented

> **Revision (two exports, toolbar split button).** The shipped feature is a **split
> button** with two behaviours, not a single export:
> - **Export** (primary) — the current view (selected scope + filters + search via
>   `?q`). Source: `filtered_resource_collection`. Filename `…_<date>.csv`.
> - **Export all** (dropdown) — the entire authorized scope, bypassing the query object
>   (`?all=1`). Source: `current_authorized_scope`. Filename `…_all_<date>.csv`.
>
> The controller selects the source via `export_csv_collection` (keyed on `params[:all]`).
> The split button (`Plutonium::UI::ExportButton`, reusing the `resource-drop-down`
> Stimulus controller) is rendered in the **index table toolbar, just after the Filter
> button** — `Plutonium::UI::Table::Components::Toolbar` receives an `export:` config
> built by `Table::Resource#export_toolbar_config` (policy-gated; carries the current
> `?q`). It is styled with `pu-btn-outline pu-btn-sm` to match the Filter button, with
> the two halves joined via inline corner styles. A page-limited "export current page"
> variant and a scope-named primary label were both considered and dropped.

## Goal

Ship CSV export as a **built-in, auto-mounted, policy-gated capability** on every Plutonium
resource — disabled by default, enabled by a one-line policy override, surfaced through a
**custom export button** on the index page (not the action DSL — exports are special: they stream
and open in a new tab). This generalizes the `AdminPortal::Concerns::ExportCsv` pattern from the
achieve-api app into the framework, following Plutonium's existing `typeahead` design
(auto-mounted route + default policy method + controller concern).

The achieve app wired export per-resource by hand (a definition action, a controller concern,
manual `collection { get :export_csv }` per resource, raw `attribute_names` as columns). Here the
route auto-mounts, the column set comes from the policy/definition, the per-field output is
customizable via an `export` DSL, and the export **streams** so it's safe on large tables — the
only thing a user does to turn it on is enable the policy.

## How users enable it

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def export_csv? = true            # or `index?`
end
```

That's it. The route already exists, the button appears on the index page once permitted, the
column set defaults to the index columns. Optionally:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # customize a single field's output + header (column set still comes from the policy)
  export :author, label: "Author email", &->(post) { post.author.email }
  export :total, &->(post) { post.total.format }
end
```

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def export_csv? = true
  # override the exported column set (defaults to permitted_attributes_for_index)
  def permitted_attributes_for_export = [:title, :author, :total, :created_at]
end
```

## Behavior

- The export button is a plain `<a target="_blank">` to `GET /<resources>/export_csv`, carrying
  the **current query string** (`?q[...]`). So it exports **all records matching the current
  filters/search/scope** — not just the visible page (the index is paginated; export is not).
- `target="_blank"` opens the download in a new tab **and** naturally bypasses Turbo (Turbo
  ignores links with a `target`), so the streamed file download isn't intercepted/rendered.
- The response **streams** (`send_stream`) — rows are written as they're read in batches, so
  memory stays flat regardless of row count. No row cap.

## Design (5 touch-points)

### 1. Routing — auto-mount (parallels `define_collection_typeahead_actions`)

`lib/plutonium/routing/mapper_extensions.rb`. Add `define_collection_export_actions`, invoked
inside the `interactive_resource_actions` concern:

```ruby
def define_collection_export_actions
  collection do
    get "export_csv", action: :export_csv, as: :export_csv
  end
end
```

Every resource registered via `register_resource` gets `GET /<resources>/export_csv`. No
per-resource route edits. Path helper: `export_csv_<resources>_path`.

### 2. Controller concern (parallels `Typeahead`)

`lib/plutonium/resource/controllers/export_csv.rb`, included in `controller.rb` after
`CrudActions` (so it can reuse the private `filtered_resource_collection`).

```ruby
require "csv"

module Plutonium::Resource::Controllers::ExportCsv
  extend ActiveSupport::Concern

  included do
    before_action :authorize_export_csv!, only: :export_csv
    skip_verify_current_authorized_scope only: :export_csv
  end

  # GET /<resources>/export_csv
  # Streams via a lazy Enumerator response body (NOT send_stream — that
  # lives in ActionController::Live, which would turn every resource
  # action into a threaded streaming response). The primary key is always
  # the first column. Rows are the index's filtered collection.
  def export_csv
    response.headers["Content-Type"] = "text/csv; charset=utf-8"
    response.headers["Content-Disposition"] =
      ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: export_csv_filename)
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["Cache-Control"] = "no-cache"
    self.response_body = export_csv_lines
  end

  def export_csv_lines
    columns = export_columns   # [primary_key] + (exportable_attributes - [primary_key])
    Enumerator.new do |yielder|
      yielder << CSV.generate_line(columns.map { |c| export_csv_header(c) })
      filtered_resource_collection.find_each do |record|
        yielder << CSV.generate_line(columns.map { |c| export_csv_value(record, c) })
      end
    end
  end

  private

  def authorize_export_csv!
    authorize_current! resource_class, to: :export_csv?
  end

  def exportable_attributes
    @exportable_attributes ||= current_policy.send_with_report(:permitted_attributes_for_export)
  end

  def export_csv_value(record, name)
    defn = current_definition.defined_exports[name]
    (defn && defn[:block]) ? defn[:block].call(record) : record.public_send(name)
  end

  def export_csv_header(name)
    defn = current_definition.defined_exports[name]
    defn&.dig(:options, :label) || name.to_s.humanize
  end
end
```

**Streaming + ordering tradeoff:** `find_each` bounds memory (loads ~1k rows at a time, GC'd per
batch) but **forces primary-key order** — the file does *not* preserve the index's current sort.
Filters, search, and scope from `filtered_resource_collection` *are* applied. This is the
deliberate cost of unbounded streaming; CSV consumers re-sort downstream. (Sort-fidelity would
require keyset pagination — out of scope.)

`send_stream` is available on the framework's Rails floor (Appraisal `rails-7` pins `~> 7.2`;
`send_stream` landed in 7.2).

**Known N+1:** an `export` block that walks an association will N+1 across batches. Acceptable for
v1 (document it); a preload hook can come later.

### 3. Policy (parallels `permitted_attributes_for_index`)

`lib/plutonium/resource/policy.rb`, in the action-methods section:

```ruby
# Checks if CSV export is permitted.
# @return [Boolean] false by default — enable per-resource by overriding.
def export_csv?
  false
end

# Returns the attributes included in an export.
# @return [Array<Symbol>] defaults to the index columns.
def permitted_attributes_for_export
  permitted_attributes_for_index
end
```

`export_csv?` defaults to `false` — the explicit opt-in gate. `permitted_attributes_for_export`
is format-agnostic (named `_export`, not `_export_csv`, so a future XLSX/JSON export reuses the
same column set) and defaults to the index columns: "index columns by default, policy-overridable."
The controller always prepends `resource_class.primary_key` as the first column (de-duplicated),
so the id is exported even when the policy's attribute list omits it.

`csv` is declared as a gemspec dependency — it is no longer a default gem on Ruby 3.4+.

### 4. Custom export button (NOT a definition action)

A dedicated Phlex component, `lib/plutonium/ui/export_button.rb`:

```ruby
class Plutonium::UI::ExportButton < Plutonium::UI::Component::Base
  def initialize(url:)
    @url = url
  end

  def view_template
    a(href: @url, target: "_blank", rel: "noopener", class: "pu-btn pu-btn-outline pu-btn-sm") do
      render Phlex::TablerIcons::Download.new(class: "w-4 h-4 shrink-0")
      span { "Export" }
    end
  end
end
```

Rendered by `Plutonium::UI::Page::Index` via the existing `render_after_page_header` hook, gated on
the policy:

```ruby
def render_after_page_header
  return unless current_policy.allowed_to?(:export_csv?)
  url = resource_url_for(resource_class, action: :export_csv, **export_query_params)
  div(class: "flex justify-end mb-2") { render Plutonium::UI::ExportButton.new(url:) }
end
```

`export_query_params` forwards the current `q` (filters/search/scope/sort params) so the export
matches what the user is looking at. The exact `resource_url_for` signature for appending `action:`
+ query params is verified against the existing `route_options_to_url`/`resource_url_for` usage
during implementation; the button URL is the only routing detail to confirm.

A custom button (rather than a definition action) is the right call because export is not a normal
navigable action: it streams a file, must open in a new tab, must not be Turbo-driven, and is
inherently collection-level. Keeping it out of the action DSL avoids bending that DSL around those
quirks.

### 5. Definition DSL — `export` (parallels `display`/`column`)

`lib/plutonium/definition/base.rb`: add `:export` to the `defineable_props` list (alongside
`:field, :input, :display, :column`). Generates `export :name, **options, &block` and
`defined_exports`, exactly like `display`/`column`.

- `&block` — receives the record, returns the cell value (overrides the raw `public_send`).
- `label:` — overrides the column header (default `name.to_s.humanize`).

The `export` DSL **customizes output of columns**; the column *set* is driven by
`permitted_attributes_for_export`. An `export` entry for a name not in that set is simply unused;
conversely the policy method may list virtual/method names (like index columns can), with `export`
supplying their formatting.

## Data flow

```
[Export button on index] --target=_blank, ?q=current--> GET /posts/export_csv?q[...]
  → authorize_export_csv!        (export_csv? — 403 if false)
  → exportable_attributes        (policy.permitted_attributes_for_export)
  → filtered_resource_collection (current_authorized_scope + search/filter/scope; NOT paginated)
  → send_stream: header line, then find_each → one CSV line per record (PK order)
  → text/csv attachment "<plural>_<date>.csv", streamed, opens in new tab
```

Row-level authorization is the scope itself (`current_authorized_scope`), so
`skip_verify_current_authorized_scope` is correct here — same as `typeahead`. Tenant/parent scoping
applies because `filtered_resource_collection` is reused unchanged.

## Error handling

- `export_csv?` false → `ActionPolicy::Unauthorized` (403); button is also hidden.
- Unknown column name in `permitted_attributes_for_export` with no `export` block →
  `NoMethodError` from `public_send` — a definition/policy authoring error that should surface
  loudly (same as an unknown index column).
- An error raised mid-stream (after headers are sent) cannot un-send the 200/headers — the
  download ends up truncated. Acceptable for v1; the column-resolution paths above are simple.

## Out of scope (YAGNI)

- Background-job / email export for very large tables — explicitly deferred (not designed now). The
  `permitted_attributes_for_export` naming leaves the door open for an async path and other formats
  later.
- A split "export current view / export all" button — there is one export: all rows matching the
  current query.
- Preserving the index sort in the file (PK order; see tradeoff above).
- Per-row authorization beyond the scope filter; preload/N+1 handling for `export` blocks.

## Testing

Use a dummy-app resource (created via generators per project convention) with the policy enabled:

- Route exists: `GET /<resources>/export_csv` resolves.
- Disabled by default: with default policy, the button is hidden and the route 403s.
- Enabled: returns a streamed `text/csv` attachment with the right filename.
- Header row = humanized column names; `export :x, label:` overrides a header.
- Body rows = one per matching record; `export :x, &block` formats that cell.
- Respects query: `?q[...]` search/filter narrows the exported rows; pagination does NOT limit them.
- `permitted_attributes_for_export` override changes the column set.
- Tenant/parent scoping: export never leaks rows outside `current_authorized_scope`.

## Files

| Action | Path |
|---|---|
| Modify | `plutonium.gemspec` (add `csv` dependency) |
| Modify | `lib/plutonium/routing/mapper_extensions.rb` (add `define_collection_export_actions`, call it in concern) |
| Create | `lib/plutonium/resource/controllers/export_csv.rb` |
| Modify | `lib/plutonium/resource/controller.rb` (include the concern) |
| Modify | `lib/plutonium/resource/policy.rb` (`export_csv?`, `permitted_attributes_for_export`) |
| Create | `lib/plutonium/ui/export_button.rb` |
| Modify | `lib/plutonium/ui/page/index.rb` (`render_after_page_header` → policy-gated button) |
| Modify | `lib/plutonium/definition/base.rb` (add `:export` defineable prop) |
| Create | tests under `test/` + dummy-app resource |
| Modify | docs (`docs/reference/...`) + relevant `.claude/skills/` skill |
