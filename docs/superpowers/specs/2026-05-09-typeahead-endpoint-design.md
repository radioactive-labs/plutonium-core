# Typeahead Endpoint Design

**Status:** Approved (2026-05-09)
**Author:** stefan
**Scope:** New backend-driven typeahead/autocomplete primitive for resource form inputs and index filter inputs.

## Goal

Add an async typeahead endpoint to every Plutonium resource so association-backed selects (and any future typeahead-capable input) can fetch matching records from the server instead of materialising up to `DEFAULT_CHOICE_LIMIT` options into the page at render time. This unblocks association pickers over large tables (where the existing 100-row cap silently truncates) without forcing every input into a custom JS solution.

## Non-goals

- Pagination of typeahead results (we use a hard cap with an overflow indicator; pagination can be added later if a real need surfaces).
- Rich result rows (subtitle, icon, avatar). MVP returns minimal `{value, label}` per row; richer payloads are a separate iteration.
- Replacing the existing eager-list ResourceSelect; the eager path stays as the fallback / small-table mode.

## Architecture

Three layers, mirroring how `Plutonium::Resource::Controllers::InteractiveActions` is composed today.

### 1. Routing — `Plutonium::Routing::MapperExtensions`

Two routes are added to the existing `interactive_resource_actions` concern (auto-mounted on every Plutonium resource alongside `record_actions`, `bulk_actions`, etc.):

```
GET /<resource>/typeahead/input/:name?q=…   → typeahead_input
GET /<resource>/typeahead/filter/:name?q=…  → typeahead_filter
```

Both collection-level. **No member variant** — authorization on the parent resource class is sufficient (see "Authorization" below).

### 2. Controller concern — `Plutonium::Resource::Controllers::Typeahead`

Two thin actions plus a single `before_action` for auth.

```ruby
module Plutonium::Resource::Controllers::Typeahead
  extend ActiveSupport::Concern

  included do
    before_action :authorize_typeahead!, only: %i[typeahead_input typeahead_filter]
  end

  def typeahead_input
    name = params[:name].to_sym
    defn = current_definition.defined_inputs[name]
    return head(:not_found) unless defn

    render_typeahead_response(defn)
  end

  def typeahead_filter
    name = params[:name].to_sym
    filter = current_query_object.filter_definitions[name]
    return head(:not_found) unless filter

    defn = filter.defined_inputs[:value]
    return head(:not_found) unless defn

    render_typeahead_response(defn)
  end

  private

  def render_typeahead_response(defn)
    klass = lookup_input_class(defn)
    return render(json: { error: "input is not typeahead-capable" }, status: :bad_request) unless klass < Plutonium::UI::Form::Components::Searchable

    widget = klass.build_for_typeahead(defn[:options] || {})
    results, has_more = widget.typeahead(
      query: params[:q].to_s,
      limit: TYPEAHEAD_LIMIT,
      controller: self
    )
    render json: { results: results, has_more: has_more }
  end

  def authorize_typeahead!
    authorize! resource_class, to: :typeahead?
  end

  # Maps the input definition's :as symbol (e.g. :resource_select) to a
  # component class. Backed by an explicit registry — only inputs that
  # opted in by including Searchable register here, so anything not in
  # the registry falls through to the 400 branch.
  def lookup_input_class(defn)
    Plutonium::UI::Form::Components::Searchable.registry[defn[:options]&.[](:as)&.to_sym]
  end
end
```

`TYPEAHEAD_LIMIT` is a module-level constant (default `50`). Easy to tune.

### 3. Search behavior — `Plutonium::UI::Form::Components::Searchable`

A small mixin. Mixed into `ResourceSelect` (and into any future input that wants typeahead). Two-method public surface:

```ruby
module Plutonium::UI::Form::Components::Searchable
  extend ActiveSupport::Concern

  # Maps :as symbol -> component class. Each typeahead-capable widget
  # populates this when it includes Searchable so the controller can
  # dispatch by name without a brittle inflection convention.
  def self.registry
    @registry ||= {}
  end

  class_methods do
    # Subclasses call this to claim their :as symbol in the registry.
    def typeahead_input_name(name)
      Plutonium::UI::Form::Components::Searchable.registry[name.to_sym] = self
    end

    # Allocates the widget and assigns just the ivars #typeahead needs.
    # Bypasses Phlex's render-time build_attributes pipeline so we don't
    # need a field/form context to run the search.
    def build_for_typeahead(options)
      allocate.tap { |w| w.send(:apply_typeahead_options, options) }
    end
  end

  # Returns [results_array, has_more_bool]. results entries are { value:, label: }.
  def typeahead(query:, limit:, controller:)
    raw = collect_typeahead_candidates(query, controller: controller)
    over = raw.length > limit
    [raw.first(limit).map { |r| serialize_typeahead_row(r) }, over]
  end
end
```

`ResourceSelect` implements `apply_typeahead_options`, `collect_typeahead_candidates`, and `serialize_typeahead_row`:

- `apply_typeahead_options(options)` reads `@association_class`, `@raw_choices`, `@choice_limit`, `@skip_authorization` from the input definition's options hash — the same keys the existing `build_attributes` consumes at render time.
- `collect_typeahead_candidates` branches:
  - if `@raw_choices` (static list) — `@raw_choices.select { |label, _| label.to_s.downcase.include?(query.downcase) }`. No auth: choices are static, definition-author-controlled.
  - elsif `@association_class` — runs the search through `controller.send(:authorized_resource_scope, @association_class)` so the associated resource's `policy.relation_scope` enforces row-level auth, then applies the associated resource definition's `search` block if present, else `LIKE` on the column backing `to_label` (or skips filtering when query is blank).
- `serialize_typeahead_row(row)` returns `{ value: row.to_signed_global_id.to_s, label: row.to_label }` for records, or `{ value: raw_value, label: raw_label }` for static choices.

The cap is **`limit + 1`** at the SQL level (`LIMIT 51` for a `limit: 50` request) so we can detect overflow without a separate `COUNT`.

## Authorization

Two gates, layered:

1. **Parent gate** — `policy.typeahead?` on the resource hosting the endpoint. Defaults to `index?` (collection-shaped — typeahead is "list/search records of this class", not "show one record"). Override per-resource if needed (e.g. `def typeahead? = create? || update?` to require write intent).
2. **Row gate** — when the input is association-backed, results are scoped through the *associated* resource's `policy.relation_scope` via the existing `authorized_resource_scope` helper. So a user can typeahead Authors only if they're allowed to read Authors, regardless of whether they can edit Posts.

Static `choices` lists bypass the row gate (they're not records, they're definition-author-controlled enumerations).

## Data flow

```
Browser (Stimulus controller)
  fetch GET /widgets/typeahead/input/author?q=ali
    ↓
Typeahead#typeahead_input
  authorize_typeahead! → policy.typeahead? on Widget       [parent gate]
  defn = current_definition.defined_inputs[:author]
  widget = ResourceSelect.build_for_typeahead(defn[:options])
  widget.typeahead(query: "ali", limit: 50, controller: self)
    authorized_resource_scope(User).where("name LIKE ?", "%ali%").limit(51)   [row gate]
    serialize each → { value: sgid, label: to_label }
  render json: { results: [...], has_more: false }
```

## Components

| File | Responsibility |
|---|---|
| `lib/plutonium/routing/mapper_extensions.rb` | Add 2 routes to the `interactive_resource_actions` concern. |
| `lib/plutonium/resource/controllers/typeahead.rb` | **New.** Controller concern with `typeahead_input`/`typeahead_filter` actions, auth, dispatch, JSON serialization. |
| `lib/plutonium/resource/controller.rb` | Include `Controllers::Typeahead`. |
| `lib/plutonium/resource/policy.rb` | Add `typeahead?` defaulting to `index?`. |
| `lib/plutonium/ui/form/components/searchable.rb` | **New.** `Searchable` mixin (class-level `build_for_typeahead`, instance-level `typeahead`). |
| `lib/plutonium/ui/form/components/resource_select.rb` | Include `Searchable`, call `typeahead_input_name :resource_select` to register. Implement `apply_typeahead_options`, `collect_typeahead_candidates`, `serialize_typeahead_row`. Wire Stimulus controller + remote URL data attrs into the rendered `<select>`. |
| `src/js/controllers/resource_select_controller.js` | **New.** Stimulus controller: debounced fetch, populates options on the underlying `<select>`, surfaces overflow hint, handles network errors. |

## Error handling

- Unknown input/filter name → `404 Not Found`.
- Input class registered but doesn't include `Searchable` → `400 Bad Request` with `{error: "input is not typeahead-capable"}`.
- Authorization failure → existing `ActionPolicy::Unauthorized` flow → `403`.
- Empty/blank `q` → return all candidates within the cap (so initial dropdown open shows something useful, mirroring the eager mode).
- Network/parse errors on the JS side → controller leaves the existing `<select>` options intact and shows a small "couldn't search" inline notice; user can retry.

## Testing

- **Unit — `Searchable#typeahead` (ResourceSelect):** static choices filter case-insensitively; association case routes through `authorized_resource_scope`; overflow detection (`limit+1` rows in DB → `has_more: true`); blank query returns top-N.
- **Controller — `Typeahead#typeahead_input` / `typeahead_filter`:** happy path renders correct JSON envelope; unknown name → 404; non-searchable input class → 400; auth denied → 403.
- **Integration:** full request through `admin_portal` hitting a registered resource, verifying SGID round-trip (the value in the response is accepted by ResourceSelect on form submit).
- **JS — Stimulus controller:** debounces input, handles `has_more`, handles network errors. Lightweight, behavior-focused.

## Migration & rollout

- Existing eager `ResourceSelect` keeps working — typeahead is opt-in per render via a flag on the input definition (e.g. `as: :resource_select, typeahead: true`). When unset, the component renders today's eager list. The Stimulus controller only attaches when `data-resource-select-typeahead-url-value` is present.
- Filter inputs default to typeahead when the underlying input class supports it (filters are the worst pain point for the 100-row cap).

## Open questions / deferred

- Server-driven sort order beyond what `relation_scope` returns (e.g. recency, fuzzy-rank). Out of scope for MVP.
- Multi-select typeahead UX (chips, paste-multiple). MVP supports `multiple: true` mechanically (the array of SGIDs round-trips fine), but the dropdown UX is single-select-shaped. Iteration.
- Caching/coalescing repeated queries client-side. Defer.
