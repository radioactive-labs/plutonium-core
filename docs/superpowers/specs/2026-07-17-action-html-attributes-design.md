# Native `link:` / `button:` HTML attributes on actions

**Date:** 2026-07-17
**Status:** Approved (design)

## Problem

On released Plutonium (≤0.62.2) there is no native way to put `target`, `rel`, or
arbitrary HTML attributes on an action's rendered control. `Action::Base` reads a
fixed key set in `initialize`, so any extra option passed to an action is silently
inert — not stored, never rendered. `ActionButton`'s three render paths
(`render_link`, `render_button`, `render_dropdown_item`) hardcode their attributes.

Concrete need: an action that opens an external link in a new tab
(`target: "_blank" rel: "noopener noreferrer"`), or that carries custom
`data-*` / `aria-*` attributes.

## API

Two target-named attribute bags on the action DSL, each naming the **element**
it applies to. No merged/"always" bag — `link:` covers every anchor rendering
and `button:` covers the button_to form, so per-element bags cover everything
with no "which element?" ambiguity.

The element rule, not HTTP method, decides which bag applies: dropdown items
are anchors even for non-GET actions (they submit via `data-turbo-method`), so
`link:` applies to them regardless of method, and `button:` applies only to the
toolbar's button_to rendering. A non-GET action that needs attributes in both
placements sets both bags.

```ruby
action :docs,
  link:   { target: "_blank", rel: "noopener noreferrer", data: { analytics: "docs" } },
  button: { data: { turbo_confirm: "Sure?" } }
```

- **`link:`** → every `<a>` rendered for the action: the GET toolbar link,
  dropdown items (any method), bulk-actions toolbar links, kanban column
  action links, and the grid/kanban card's hidden show anchor (for `:show`).
- **`button:`** → the `button_to` **`<form>`** element, in `render_button` (non-GET),
  via `button_to`'s `form:` option. The form wrapper, not the inner `<button>`.
- Both default to `{}`. `target`/`rel` are just keys inside `link:` — no first-class
  sugar, nothing special-cased.

## Storage — `Action::Base`

- New ivars `@link` / `@button` in `initialize`, each normalized on the way in:
  the action stores its **own deep-symbolized copy** of the bag (never freezing
  or sharing the caller's hash), structurally deep-frozen. Symbolizing is
  load-bearing: the render-time `deep_merge` matches keys exactly, so a
  string-keyed bag would sit *alongside* the framework's symbol keys and emit
  duplicate attributes (browser keeps the first — the framework's) instead of
  overriding. Any non-Hash value — including `false` — raises `ArgumentError`.
- Matching `attr_reader :link, :button`, plus the merge points
  `link_attributes(base)` / `button_attributes(base)`: rendering surfaces hand
  the framework-built attribute hash to the action, which deep-merges its bag
  over it (author wins). Surfaces never merge the raw bags themselves.
- Both added to `to_options` so `with(**overrides)` round-trips them (miss this and
  `.with` silently drops them — the one non-negotiable).
- `Action::Interactive` already forwards `**options` to `super`, so the bags flow
  through interactive actions automatically. No change needed there.
- Verify during implementation that the definition-level `action` /
  `interactive_action` DSL forwards unknown kwargs into the action constructor
  (it splats `**options` into `Action::Simple.new` / `Interactive::Factory.create`,
  so it should — confirm, don't assume).

## Rendering

Merge rule everywhere: build the framework's attribute hash as the base, then
hand it to the action's merge point (`action.link_attributes(base)` /
`action.button_attributes(base)`) — **the author wins on every key**,
recursively through nested `data`. This gives authors full control (they can
override `turbo_frame`, `class`, `data-*`, anything) at their own risk.

Surfaces funnelling through the merge points:

- **`ActionButton#render_link`** — base
  `{ class: button_classes, data: { turbo_frame: … }.merge(@extra_data) }`
  through `link_attributes`, passed to `link_to`.
- **`ActionButton#render_dropdown_item`** — the existing `link_attrs` hash
  through `link_attributes` before `a(**…)`. Applies to any method — dropdown
  items are anchors; `button:` never applies here.
- **`ActionButton#render_button`** — the `form:` option hash passed to
  `button_to` through `button_attributes`. So `button: { target: "_top" }` sets
  the form's target; `button: { data: { … } }` deep-merges into the form's data.
- **`BulkActionsToolbar#render_action_button`** — the bulk-action anchor's
  attrs through `link_attributes`.
- **`Kanban::Column#column_action_link_attributes`** — the column-action
  anchor's attrs through `link_attributes` (of the registered action).
- **`Grid::Card#render_show_link`** — the hidden row-click show anchor's attrs
  through the `:show` action's `link_attributes`.

## Tests

- `test/plutonium/action/base_test.rb`:
  - `link` / `button` readers default to `{}` and return what was passed.
  - `to_options` includes both bags; `with(link: …)` round-trips and overrides.
- `ActionButton` rendering tests:
  - `link:` attributes (`target`, `rel`, custom `data-*`) land on the `<a>` in the
    GET-link and dropdown renderings.
  - `button:` attributes land on the `<form>` in the non-GET rendering.
  - Author wins on collision: an author `data.turbo_frame` overrides the
    framework's.

## Scope guard (out)

- No third "always" / `html:` bag.
- No attribute-name validation — authors own their HTML; a bad attribute is their
  problem. (Container shape IS validated: a non-Hash bag raises; keys are
  symbolized so string-keyed bags can't silently lose the merge.)
- No per-element targeting *within* a rendering (e.g. the inner `<button>` vs the
  `<form>`) — `button:` targets the form only. Can be extended later if needed.

## Known footguns (documented, accepted)

- `deep_merge` only recurses when **both** values are hashes: an author scalar
  `data:` (`button: { data: "x" }`) wholesale-replaces the framework's data hash,
  deleting `turbo_confirm`/`turbo_frame`. Pass `data:` as a hash. Same mechanics
  mean `class:` **replaces** the framework's classes (no token append) — that's
  the author-wins contract working as designed.
- `button:` lands on the `<form>` wrapper, not the visible `<button>`: click-
  element attributes (`aria-label`, `class` for the control) don't reach the
  button element. Documented in the guide; per-element targeting is the
  deferred extension above.
