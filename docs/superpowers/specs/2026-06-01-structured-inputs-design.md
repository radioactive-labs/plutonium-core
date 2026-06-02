# Structured Inputs

**Date:** 2026-06-01 (updated 2026-06-02)
**Status:** Approved — DSL name `structured_input` final; ready for implementation plan

## Problem

There is no first-class way to collect a **structured input** — a group of
fields gathered into one object, or a variable-length list of such objects —
without an ActiveRecord association behind it:

- **Interactions** declare scalar `attribute`s only. They cannot collect a
  structured object (`address => {street:, city:}`) or a list of them. The
  included `nested_input` is model-backed and silently renders nothing for the
  classless case (characterized in
  `test/plutonium/ui/form/interaction_nested_input_test.rb`).
- **Resources** can edit a JSON/jsonb column only as a raw JSON textarea or a
  flat `key_value_store` — no structured UI for `{a, b}` or `[{a, b}, …]` stored
  in a JSON column. Association-backed repetition is `nested_input`'s job; JSON
  columns have nothing.

## Goal

One DSL — **`structured_input`** — for a *classless* group of fields, collected
as:

- a **hash** (single object) by default, or
- an **array of hashes** when `repeat:` is given (the repeater),

rendered with a fields group, and feeding either an **interaction attribute** or
a **resource JSON column**. The single object is the base; the repeater is the
same group rendered N times.

### Non-goals

- Type coercion of values. Rows/objects are plain hashes; the host validates.
- Replacing model-backed `nested_input` (stays the resource association feature).

## Feasibility anchors

This design follows the grain of phlexi-form rather than fighting it:

1. **`nest_one` → hash, `nest_many` → array.** The library's own
   `extract_input` already produces exactly these shapes, and `nest_many` is
   literally `nest_one` repeated:

   ```ruby
   # Namespace#extract_input (nest_one):   { key => { field => value, … } }
   # NamespaceCollection#extract_input (nest_many):
   params = params[key]
   params = params.values if params.is_a?(Hash)        # index-hash → array, free
   { key => Array(params).map { |p| namespace.extract_input([p]) } }
   ```

2. **Hash-backed rendering.** `Phlexi::Field::Support::Value.from` reads
   `object[key]` for a `Hash`, so a row/object is a plain hash and the blank
   template is `{}`. No synthesized classes.

3. **Form-driven param extraction.** Plutonium extracts submitted resource
   params via `build_form(record).extract_input(params)`
   (`controller.rb#submitted_resource_params`). Nesting with `as: :<name>` makes
   the extracted hash/array land under `:<name>`, which assigns **directly** to
   the JSON column / interaction attribute — no `_attributes=` setter, no manual
   strong-params.

## Design

### 1. The DSL — `structured_input`

```ruby
# single → hash
structured_input :address do |f|
  f.input :street
  f.input :city
end
# value: address => { street:, city: }

# repeater → array of hashes (max 10 rows)
structured_input :contacts, repeat: 10 do |f|
  f.input :label
  f.input :phone_number
end
# value: contacts => [ { label:, phone_number: }, … ]
```

- `repeat:` semantics: **`repeat: <int>` = maximum rows**; `repeat: true` =
  repeater with the default cap; **absent = single** (hash). Presence of
  `repeat:` always means an array — `repeat: 1` is "array, max one row", *not*
  the single form.
- Fields come from a block or `using:`/`fields:` (the existing lightweight
  `NestedInputsDefinition` holder, `defineable_props :field, :input`).
- Registers config in a `defined_structured_inputs` registry, via a shared
  module included by both resource definitions (`Plutonium::Definition::Base`)
  and interactions (`Plutonium::Interaction::Base`) — both already mix in
  `DefineableProps`.

### 2. Rendering (shared, classless)

The unit is the **fields group** — the declared inputs rendered over a nested
builder. Single and repeater differ only in `nest_one` vs `nest_many` and the
surrounding chrome:

- **Single:** `nest_one(:address, as: :address)` over the current value (or `{}`)
  → one fieldset of inputs. No add/remove chrome, no `<template>`, no hidden
  `id`/`_destroy`.
- **Repeater:** `nest_many(:contacts, as: :contacts)` → the existing repeater
  chrome (the `nested-resource-form-fields` Stimulus controller, `limit` = the
  `repeat` cap, a `<template>` holding a blank `{}` row, existing rows from the
  array value, an add button, a per-row delete control). No hidden `id`/`_destroy`.

This reuses the same Stimulus controller and visual structure as the model-backed
repeater, but is a **separate classless code path**. Model-backed `nested_input`
rendering is untouched (still covered by
`test/integration/admin_portal/nested_form_rendering_test.rb`).

### 3. Param flow (shared)

- Nesting with `as: :<name>` → `extract_input` yields `{name => {…}}` (single) or
  `{name => [{…}, …]}` (repeater, index-hash already normalized to array).
- The value assigns **directly** to the JSON column / interaction attribute.
- A shared **clean step**, keyed off `defined_structured_inputs`, runs
  post-extract: for repeaters, drop all-blank rows and strip `_destroy`; single
  passes through. Rows are positional — **no ids**.

### 4. Host — interactions

`structured_input :name` declares `attribute :name` defaulting to `{}` (single)
or `[]` (repeater). The extracted+cleaned value flows into the attribute;
`execute` sees a hash or an array.

### 5. Host — resources (JSON, no model macro)

Because it is classless, the resource side needs **no `accepts_nested_attributes_for`-style
model declaration** — just:

- **Model:** a `json`/`jsonb` column named `name`.
- **Definition:** `structured_input :name …`.
- **Policy:** permit `:name` in `permitted_attributes_for_*` so the form renders
  it.

Params then flow via the form's `extract_input` → clean → `record.name = hash/array`
→ persisted in the JSON column. The `nested_input` model/definition split
dissolves here; classless JSON needs only the column + the definition DSL.

### 6. Remove the broken nested surface from interactions

- `nested_input` is **removed** from interactions (`Interaction::Base` stops
  mixing in `Plutonium::Definition::NestedInputs`) → `NoMethodError` at
  class-load. `defined_nested_inputs` is likewise undefined; the inherited form
  branch is guarded by `respond_to?` and simply skips.
- `accepts_nested_attributes_for` is **removed** from interactions
  (`Interaction::Base` stops mixing in `Plutonium::Interaction::NestedAttributes`).
  Build models explicitly in `execute` if ever needed.

Resources keep both model-backed `nested_input` and AR `accepts_nested_attributes_for`
unchanged, and additionally gain `structured_input`.

## Testing

- **Clean step** (unit): array and index-keyed-hash → array; all-blank rows
  dropped; `_destroy` stripped; single passes through; no ids.
- **Single** (interaction + resource): renders one fieldset; round-trip → a hash
  value on the attribute / JSON column.
- **Repeater** (interaction + resource): renders the repeater chrome with
  `host[contacts][NEW_RECORD][label]` naming, add/delete, no hidden id/`_destroy`;
  round-trip → an array value; blank rows rejected; edit repopulates.
- **Guard** (unit): interactions do not respond to `nested_input` /
  `accepts_nested_attributes_for` / `defined_nested_inputs` (replaces the current
  `interaction_nested_input_test.rb`).
- **Regression**: resource `nested_input` unchanged — existing characterization
  tests stay green.
- Fixtures via the `pu:*` generators; the resource fixture uses a JSON column.

## Open questions (resolve in plan)

- **Clean-step placement:** one shared function, two call sites (the resource
  controller param path; the interaction's param assignment). Confirm the exact
  hooks.
- **Field naming:** `as: :<name>` (direct assignment, recommended) vs a
  `_attributes` suffix. Verify no collision with form/extract internals.
- **JSON column type in the dummy fixture:** SQLite `json`/serialized text for
  the test; document `jsonb` as the production recommendation.

## Risk / breaking change

- Removing `nested_input` + `accepts_nested_attributes_for` from interactions is
  a deliberate breaking change; the only previously-working case (an interaction
  mirroring a real resource association) is redundant with resource forms.
  Offenders get a `NoMethodError` naming the method; the README is reworked to
  `structured_input`.
- `structured_input` is additive on resources and new on interactions.
