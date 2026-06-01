# Interaction Repeater Inputs

**Date:** 2026-06-01
**Status:** Design — pending review

## Problem

Interactions (`Plutonium::Resource::Interaction`) collect scalar inputs via
`attribute`, but have no first-class way to collect a **repeating group of
fields** — e.g. a variable-length list of `{label, phone_number}` contacts —
as structured input the interaction can validate and use in `execute`.

The repeater UX already exists for resource forms (the
`nested-resource-form-fields` Stimulus controller: add/remove rows, `<template>`
cloning). But it is **model-backed**: the renderer
(`Plutonium::UI::Form::Concerns::RendersNestedResourceFields` →
`NestedFieldContext`) sources its row metadata (`:class`, `:macro`, `:limit`,
multiplicity) from `resource_class.all_nested_attributes_options`, which only
reflects ActiveRecord associations on the acted-on resource.

For an interaction collecting a classless list, there is no association and no
class. The current behaviour (characterized in
`test/plutonium/ui/form/interaction_nested_input_test.rb`):

- `nested_input` is registered on interactions and param coercion works, **but**
- `nested_attribute_options` resolves to `{}`, so `blank_object` is `nil` →
  `nest_one`/`nest_many` have no template object → the nested UI renders nothing.
- The one case that *does* work is when the interaction's nested attribute
  happens to mirror a real association on the acted-on resource (the README's
  `CreateUserInteraction` building a `User` with `has_many :contacts`).

So interactions have the *param* half of nested inputs but no working *rendering*
half for the classless case, and the failure is silent.

## Goal

Let an interaction declare a **classless repeating field group** that:

- renders with the existing repeater UX (add/remove rows, template cloning,
  delete checkbox),
- collects into the interaction as an **array of plain hashes**
  (`contacts => [{label:, phone_number:}, …]`),
- needs **no backing class** — just a fields definition.

Non-goals (explicitly out of scope):

- A single (non-repeater) variant. Repeater only; value is always an array.
- Type coercion of row values. Rows are plain hashes; the interaction validates
  them itself.
- Reusing/extending model-backed `nested_input` semantics for the classless case.

## Feasibility anchor

Phlexi already supports hash-backed rendering. `Phlexi::Field::Support::Value.from`:

```ruby
return object[key] if object.is_a?(Hash)
object.public_send(key) if object.respond_to?(key)
```

So a row can be a plain `Hash`, and the blank/template row can be `{}` (every
field reads `nil` → empty). No synthesized classes are required.

## Design

### 1. DSL — `repeater`

A new, self-contained DSL on the interaction base. One call declares everything:

```ruby
class CreateUserInteraction < Plutonium::Resource::Interaction
  attribute :first_name, :string

  repeater :contacts do |f|
    f.input :label
    f.input :phone_number
  end

  # or, reusing an existing fields definition:
  # repeater :addresses, using: AddressFields, fields: %i[label map_url]

  # options: limit: (default 10)
end
```

`repeater :name` will:

1. declare `attribute :name` defaulting to `[]`,
2. register a **classless** `name_attributes=` collector (see §2),
3. register render config (the fields definition, `multiple: true`, `limit`).

A distinct name (not `nested_input`) is intentional: it signals different
semantics (classless, collects hashes) and keeps a clean, conditional-free
implementation path separate from model-backed `nested_input`.

### 2. Param handling

`name_attributes=` accepts what the form submits — either an `Array` of row
hashes or a `Hash` keyed by index (`{"0" => {...}, "1" => {...}}`, Rails' nested
form shape). For each row:

- skip if `_destroy` is truthy (`1`/`"1"`/`true`/`"true"`),
- skip if every value is blank (the empty trailing/blank rows),
- otherwise keep the row as a symbolized hash with `_destroy` removed.

Store the result as `name` = `Array<Hash>`. The `name` reader returns that array
(used both by `execute` and by the renderer to repopulate on re-render).

### 3. Rendering

Reuse the existing repeater chrome. Add a **classless render path** that does not
touch `all_nested_attributes_options`:

- config (fields, `multiple: true`, `limit`) comes from the `repeater`
  declaration,
- the template/blank row object is `{}`,
- existing rows come from the array of hashes already on the attribute (so a
  validation-failed re-render repopulates),
- field naming via `nest_many(:contacts, as: :contacts_attributes, …)` →
  `interaction[contacts_attributes][N][label]`.

The resource (model-backed) render path is left untouched and stays covered by
the existing characterization tests
(`test/integration/admin_portal/nested_form_rendering_test.rb`).

> Implementation detail deferred to the plan: whether the classless path is a
> sibling context to `NestedFieldContext` or a generalization of it, and how the
> `repeater` fields block maps onto the existing `NestedInputsDefinition`. The
> design constraint is only that the resource path does not change behaviour.

### 4. `nested_input` raises when no class is resolvable

Convert the silent classless failure into a guiding error. When the nested-field
renderer cannot resolve a class to build rows (no `object_class`, and no `:class`
from association metadata), raise:

```
`nested_input :contacts` could not resolve a class to build its rows.
If this is an interaction collecting plain inputs, use `repeater :contacts` instead.
```

This keeps the legitimate model-backed `nested_input` working (class present →
renders) and fails loudly only where it is actually broken. It also guards
genuinely misconfigured resource nested inputs.

### 5. `accepts_nested_attributes_for` is unchanged

It stays available on interactions for the deliberate case of building real
model instances in `execute`. `repeater` does not use or replace it.

### 6. Documentation

Update the interaction README: document `repeater` for classless repeating
input; note that `nested_input` is model-backed and now errors without a
resolvable class.

## Testing

- **Param round-trip** (unit): `contacts_attributes=` with an `Array` and with a
  Rails index-keyed `Hash` → `contacts` is an array of symbolized hashes;
  `_destroy` and all-blank rows dropped.
- **Render** (integration): a dummy interaction with a `repeater`, wired to an
  interactive action, GET its form → assert the repeater HTML — controller
  container + limit, `<template>`, fieldset, `interaction[contacts_attributes]
  [NEW_RECORD][label]` naming, add button, delete checkbox. Fixture built via
  the `pu:*` generators per project convention.
- **Guard** (unit/integration): a classless `nested_input` on an interaction
  raises the guiding error. Update the existing characterization test
  (`interaction_nested_input_test.rb`) from "blank_object is nil" to "raises".
- **Regression**: resource nested fields unchanged — existing characterization
  tests stay green.

## Risk / breaking change

Making `nested_input` raise without a resolvable class is a (small) breaking
change for any interaction relying on the silently-broken classless path — but
that path renders nothing today, so there is no working behaviour to break. The
model-backed path is preserved.
