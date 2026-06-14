# Form Sectioning — Design

**Date:** 2026-06-14
**Status:** Approved (pending spec review)

## Problem

Plutonium forms render every field in a single responsive grid
(`Form::Resource#render_fields` walks a flat `resource_fields` list inside one
`fields_wrapper`). There is no way to group fields under headings ("Personal
details", "Address", …). We want a clean DSL for *sectioning* forms that works
for both resource definitions and interactions, without disturbing per-field
configuration.

## Constraints discovered in the codebase

- **Field config lives in the definition** (`input :x, ...` via
  `DefineableProps`, stored as ordered hashes), but the **set and order of
  fields actually rendered come from the policy** (`permitted_attributes_for(action)`,
  via `submittable_attributes_for`). The form receives that flat list as
  `resource_fields`.
- **Interactions reuse the resource form.** `Form::Interaction < Form::Resource`
  and only swaps in `resource_fields` (from `interaction.attribute_names`) and
  `resource_definition` (the interaction instance). So sectioning added to
  `Form::Resource#render_fields` is inherited by interactions for free.
- The shared definition DSL is composed from `Plutonium::Definition::*` concern
  modules. `StructuredInputs` is the precedent for a module mixed into **both**
  `Definition::Base` and `Interaction::Base`.

Therefore: sectioning is a **presentation concern declared in the definition**
that must group a **policy-driven** field list — skipping fields the policy
filtered out and hiding sections that end up empty.

## DSL

A new shared module `Plutonium::Definition::FormLayout` provides `form_layout`.

```ruby
form_layout do
  section :identity, :name, :date_of_birth, :grade,
    label: "Your identification", description: "Basic info"

  section :address, :street, :city, :country,
    collapsible: true, columns: 2,
    condition: -> { object.requires_address? }

  ungrouped label: "Other", collapsible: true
end
```

### `section(key, *fields, **opts)`

- `key` — Symbol, the section's identity. Heading defaults to `key.to_s.humanize`.
  `:ungrouped` is **reserved** for the macro below — `section :ungrouped, …`
  raises `ArgumentError`.
- `*fields` — ordered field keys placed in this section.
- `**opts`:
  - `label:` — overrides the humanized heading.
  - `description:` — optional help line under the heading.
  - `collapsible:` — Boolean (default `false`). Renders as a native
    `<details>/<summary>` disclosure (no JS).
  - `collapsed:` — Boolean (default `false`). Initial state when collapsible;
    `false` ⇒ the `<details>` is `open`.
  - `columns:` — Integer overriding the section's grid column count. Default
    inherits the form's responsive grid.
  - `condition:` — lambda evaluated in the **form instance context** (same
    semantics as `input ..., condition:`; `object` and helpers available). A
    falsey result renders nothing for the section.

### `ungrouped(**opts)`

- Configures the implicit bucket that auto-collects every permitted field not
  claimed by a `section`. Takes **no field list**.
- Accepts the same options as `section` (`label:`, `description:`,
  `collapsible:`, `collapsed:`, `columns:`, `condition:`).
- **Position:** where the macro is called sets where leftovers render. If the
  macro is omitted, leftovers render **last** (appended after all declared
  sections), with **no heading**. _(Amended — was "first"; see Amendments.)_
- Calling `ungrouped` more than once in a single `form_layout` raises
  `ArgumentError`.

### Field configuration stays on `input`

`form_layout`/`section` only reference field **keys** and carry **section-level**
options. All per-field rendering config (`as:`, the field's own `label:`,
`choices:`, per-field `condition:`, `pre_submit:`, blocks) remains on the `input`
declaration. Layout never duplicates field config.

### Inheritance / override

- Re-declaring `form_layout` in a subclass **replaces** the parent layout as a
  unit. Field-level `input` config continues to inherit normally.
- The section registry is duplicated to subclasses on `inherited` (mirrors
  `StructuredInputs`).

### Backwards compatibility

No `form_layout` declared ⇒ the current single-grid behavior is used unchanged.
This is equivalent to one implicit, heading-less `ungrouped` region.

## Rendering

`Plutonium::Definition::FormLayout` exposes an ordered, frozen registry of
section specs (and the `ungrouped` spec + its position) on definition and
interaction instances.

`Form::Resource#render_fields` becomes:

1. **No layout** → existing path: one `fields_wrapper` over all `resource_fields`.
2. **Layout present**:
   - Assign each `section` its `fields ∩ resource_fields`, preserving the
     section's declared field order.
   - The `ungrouped` bucket gets `resource_fields` minus all claimed fields,
     preserving `resource_fields` order.
   - Build the ordered render list: sections in declared order with the
     `ungrouped` bucket inserted at its declared position (default: **last**).
   - For each entry: evaluate `condition` (skip if falsey); render a Section
     component with its renderable fields. Empty sections are **not**
     special-cased — they render with defaults (see Edge cases).

Field rendering itself still goes through the existing `render_resource_field`,
so all input types/components are unaffected.

### Section component

New `Plutonium::UI::Form::Components::Section` (Phlex). Responsibilities:

- Wrapper + heading (`label`) + optional `description`.
- When `collapsible`, wrap in native `<details>`/`<summary>` (`open` unless
  `collapsed`), styled with Tailwind/`--pu-*` tokens.
- A grid (`fields_wrapper`-style) whose column count comes from `columns:` when
  given, else the existing responsive default
  (`grid-cols-1 md:grid-cols-2 2xl:grid-cols-4`).
- Yields to render the section's fields via `render_resource_field`.

A small helper maps `columns:` → grid classes (e.g. `1 → "grid grid-cols-1 gap-6"`,
`2 → "grid grid-cols-1 md:grid-cols-2 gap-6"`). Theme entries added for section
heading/description/wrapper so they're themeable like the rest of the form.

## Edge cases

- **Field permitted but in no section** → falls into `ungrouped`.
- **Section references a policy-filtered field** → that individual field is
  skipped (no input is rendered for an unpermitted attribute).
- **Empty section** (all fields filtered out, or none assigned) → **not
  hidden**. It renders through the normal path with defaults (its default/declared
  chrome). There is no automatic empty-hiding; to hide a section conditionally,
  use `condition:`.
- **Field key in a `section` not in the permitted set** (a typo, or filtered by
  policy / per-action / scoping / nesting) → **silently skipped**, never an
  error. _(Amended — originally raised; see Amendments.)_
- **`condition` falsey** → section renders nothing; its fields do **not** spill
  into `ungrouped` (they remain owned by the suppressed section).
- **No leftovers** → `ungrouped` renders with defaults (with no fields and no
  configured heading, that is simply nothing visible; a configured `label:`
  still renders).

## Files

- **New** `lib/plutonium/definition/form_layout.rb` — DSL module: `form_layout`
  block builder, ordered + inheritable section registry, `section` / `ungrouped`,
  instance readers, validation (duplicate `ungrouped`, etc.).
- **Modify** `lib/plutonium/definition/base.rb` — `include FormLayout`.
- **Modify** `lib/plutonium/interaction/base.rb` — `include FormLayout`.
- **New** `lib/plutonium/ui/form/components/section.rb` — section component.
- **Modify** `lib/plutonium/ui/form/resource.rb` — `render_fields` grouping; columns→grid helper.
- **Modify** `lib/plutonium/ui/form/theme.rb` — section heading/description/wrapper tokens.

## Testing (RSpec)

- **DSL/registry:** sections recorded in order with options; `ungrouped` spec +
  position; humanized default label; `label:` override; duplicate `ungrouped`
  raises; `section :ungrouped` raises; inheritance duplicates registry;
  re-declaring `form_layout` replaces.
- **Assignment:** fields land in the right section in declared order; leftovers
  collect into `ungrouped`; `ungrouped` default position is last; explicit
  position honored.
- **Filtering:** a field not in the permitted set (policy-filtered or a typo) is
  skipped; an empty section still renders with defaults (is **not** hidden).
- **Conditions:** falsey `condition` hides the section and withholds its fields.
- **Rendering:** headings/descriptions present; collapsible emits
  `<details>`/`<summary>` with correct `open`; `columns:` changes grid classes.
- **Interactions:** an interaction with `form_layout` sections renders grouped
  via `Form::Interaction`.
- **Backwards-compat:** a definition with no `form_layout` renders the single
  grid exactly as before.

## Out of scope (YAGNI)

- Applying sections to show/display pages or the index grid (forms only for now;
  the same registry could later be reused by `Display::Resource`).
- Nested sections / tabs.
- Per-field layout hints (e.g. `field :notes, span: 2`) — Style 1 keeps fields
  positional; this can be added later via the nested-block form if needed.
- Stimulus-driven animated collapse (native `<details>` chosen for leanness).

## Amendments (post-implementation)

Changes made after the original plan landed:

- **Implicit `ungrouped` placement: first → last.** When no `ungrouped` macro is
  declared, leftover fields are now appended **after** all declared sections
  (was: prepended). This matches the convention of the explicit macro ("the
  rest" trails the sections you care about) and makes "omit it" equivalent to
  "declare it last." To float leftovers above your sections, declare `ungrouped`
  explicitly at the top.

- **`columns:` actually lays out in a grid.** Previously every field wrapper got
  `col-span-full`, so a section's `columns: N` had no visible effect. Fields in a
  multi-column section now flow into single grid cells. A field that declares its
  own span (`input :x, wrapper: {class: "col-span-..."}`) **always wins** — in any
  section — so authors can opt a field back to full width (or wider) inside a
  multi-column section.

- **Dynamic section options.** Every section option except `columns:`
  (`collapsed`, `collapsible`, `label`, `description`, plus the existing
  `condition`) may be a **proc**, resolved at render time in the form instance
  context — the same context as input/section `condition:` (so `object`,
  `current_user`, `params`, helpers are available). The whole layout is resolved
  once per render in `Form::Resource#resolve_form_layout` (visibility + option
  evaluation in one pass); `render_form_section` is pure presentation. `columns:`
  stays a validated literal (it feeds the grid class).

- **Unknown / filtered field keys are skipped, not raised.** A `section` key not
  in the form's permitted set (`submittable_attributes_for(action)`) is silently
  dropped instead of raising `ArgumentError`. The original raise couldn't tell a
  typo from a field that's simply not permitted in the current context (per-action
  `permitted_attributes`, entity scoping, nesting, per-user policy), so it crashed
  forms that referenced conditionally-permitted fields. Skipping makes one
  `form_layout` safe across all those contexts. (`resolve_form_sections` only ever
  saw the filtered list, so it could never reliably distinguish typo from filtered
  anyway.)

- **Interactions: verified + exercised.** `Form::Interaction < Form::Resource`
  already inherited the layout path; this is now covered by a dummy interaction
  (`ReconfigureKitchenSink`, a record action on `KitchenSink`) and an integration
  test. In an interaction form `object` is the interaction instance and
  `object.resource` is the record, so record-aware dynamic options work there too
  (e.g. `collapsed: -> { object.resource.archived? }`).

- **Unrelated fix surfaced while driving the dummy in `development`:** the package
  engine system (`Plutonium::Package::Engine`) called `Rails.application.initializers`
  from a `before_configuration` hook, prematurely memoizing `Rails.application.railties`
  and dropping package engines from the autoload paths when a second
  `Rails::Application` (combustion, in dev) was instantiated before the packages
  glob ran — surfacing as `uninitialized constant Blogging::Post`. The view-path
  neutralization was moved to a real initializer (`before: :add_view_paths`).
