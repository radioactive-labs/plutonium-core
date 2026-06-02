# Structured Inputs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a classless `structured_input` DSL — a group of fields collected as a hash (single) or array of hashes (`repeat:`) — usable on interactions (→ attribute) and resource definitions (→ JSON column), and remove the broken `nested_input`/`accepts_nested_attributes_for` surface from interactions.

**Architecture:** A shared `Plutonium::Definition::StructuredInputs` registry DSL is mixed into both `Definition::Base` (resources) and `Interaction::Base`. Rendering rides phlexi-form's `nest_one`/`nest_many` over plain hashes (no per-row class); params are extracted by the existing form-driven `extract_input` path and run through a shared `ParamCleaner` before assignment. On resources the value lands in a JSON column with `as: :<name>` (no model macro); on interactions `structured_input` also declares an ActiveModel `attribute`.

**Tech Stack:** Ruby, Rails, phlexi-form (`nest_one`/`nest_many`, `extract_input`), Phlex, ActiveModel::Attributes, Minitest + Appraisal.

**User Verification:** NO — no user verification required (feature build; verified by automated tests).

**Spec:** `docs/superpowers/specs/2026-06-01-structured-inputs-design.md`

**Run tests with:** `bundle exec appraisal rails-8.1 ruby -Itest <file>` (single file) or `bundle exec appraisal rails-8.1 rake test` (full).

---

## Task 0: Shared `structured_input` DSL + registry

**Goal:** A shared concern providing the `structured_input` class DSL, a `defined_structured_inputs` registry (inherited by subclasses), and a fields-definition holder; mixed into resource definitions.

**Files:**
- Create: `lib/plutonium/definition/structured_inputs.rb`
- Modify: `lib/plutonium/definition/base.rb` (add `include StructuredInputs`)
- Test: `test/plutonium/definition/structured_inputs_test.rb`

**Acceptance Criteria:**
- [ ] `structured_input :addr do |f| f.input :street end` registers an entry in `defined_structured_inputs[:addr]` with the block.
- [ ] The fields holder built from the block exposes the declared inputs via `defined_inputs`.
- [ ] `repeat:` and `limit:`/`fields:`/`using:` options are captured under `[:options]`.
- [ ] Subclasses inherit parent `defined_structured_inputs`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/structured_inputs_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/definition/structured_inputs_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::StructuredInputsTest < Minitest::Test
  def build_definition(&block)
    Class.new(Plutonium::Definition::Base, &block)
  end

  def test_registers_a_structured_input_with_its_block
    klass = build_definition do
      structured_input :address do |f|
        f.input :street
        f.input :city
      end
    end

    entry = klass.defined_structured_inputs[:address]
    refute_nil entry
    assert_kind_of Proc, entry[:block]
  end

  def test_captures_repeat_and_limit_options
    klass = build_definition do
      structured_input :contacts, repeat: 10 do |f|
        f.input :label
      end
    end

    assert_equal 10, klass.defined_structured_inputs[:contacts][:options][:repeat]
  end

  def test_fields_holder_exposes_declared_inputs
    klass = build_definition do
      structured_input :address do |f|
        f.input :street
        f.input :city
      end
    end

    holder = Plutonium::Definition::StructuredInputs::FieldsDefinition.new
    klass.defined_structured_inputs[:address][:block].call(holder)
    assert_equal %i[street city], holder.defined_inputs.keys
  end

  def test_subclasses_inherit_registry
    parent = build_definition do
      structured_input(:a) { |f| f.input :x }
    end
    child = Class.new(parent)
    assert child.defined_structured_inputs.key?(:a)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/structured_inputs_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'structured_input'`.

- [ ] **Step 3: Write the module**

```ruby
# lib/plutonium/definition/structured_inputs.rb
# frozen_string_literal: true

module Plutonium
  module Definition
    # Classless structured inputs: a group of fields collected into a hash
    # (single) or an array of hashes (when `repeat:` is given). Mixed into both
    # resource definitions and interactions.
    #
    # @example
    #   structured_input :address do |f|
    #     f.input :street
    #     f.input :city
    #   end
    #
    #   structured_input :contacts, repeat: 10 do |f|
    #     f.input :label
    #     f.input :phone_number
    #   end
    module StructuredInputs
      extend ActiveSupport::Concern

      # Holder built per render from a structured_input block. Reuses the same
      # field/input DSL as the rest of Plutonium definitions.
      class FieldsDefinition
        include Plutonium::Definition::DefineableProps

        defineable_props :field, :input
      end

      class_methods do
        # @param name [Symbol]
        # @option options [Integer, true] :repeat  presence ⇒ array; Integer ⇒ max rows
        # @option options [Class] :using  a FieldsDefinition-like class instead of a block
        # @option options [Array<Symbol>] :fields  restrict rendered fields
        def structured_input(name, **options, &block)
          defined_structured_inputs[name] = {options:, block:}.compact
        end

        def defined_structured_inputs
          @defined_structured_inputs ||= {}
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(
            :@defined_structured_inputs,
            defined_structured_inputs.deep_dup
          )
        end
      end
    end
  end
end
```

- [ ] **Step 4: Wire into resource definitions**

In `lib/plutonium/definition/base.rb`, add the include next to the other definition concerns (after `include NestedInputs`):

```ruby
      include NestedInputs
      include StructuredInputs
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/structured_inputs_test.rb`
Expected: PASS (4 runs).

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/definition/structured_inputs.rb lib/plutonium/definition/base.rb test/plutonium/definition/structured_inputs_test.rb
git commit -m "feat(definition): add classless structured_input DSL + registry"
```

```json:metadata
{"files": ["lib/plutonium/definition/structured_inputs.rb", "lib/plutonium/definition/base.rb", "test/plutonium/definition/structured_inputs_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/structured_inputs_test.rb", "acceptanceCriteria": ["structured_input registers in defined_structured_inputs with block", "fields holder exposes declared inputs", "repeat/limit options captured", "subclasses inherit registry"], "requiresUserVerification": false}
```

---

## Task 1: Shared param cleaner

**Goal:** A pure function that turns submitted structured-input params into the stored value — a hash (single) or a cleaned array of hashes (repeat: drop all-blank rows, strip `_destroy`).

**Files:**
- Create: `lib/plutonium/structured_inputs/param_cleaner.rb`
- Test: `test/plutonium/structured_inputs/param_cleaner_test.rb`

**Acceptance Criteria:**
- [ ] Single (`repeat:` false): passes the hash through (symbolized), `_destroy` stripped.
- [ ] Repeater (`repeat:` truthy): normalizes an `Array` or index-keyed `Hash` to an array, drops all-blank rows, strips `_destroy`, returns positional array (no ids).
- [ ] `nil`/blank input → `{}` (single) or `[]` (repeater).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/param_cleaner_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/structured_inputs/param_cleaner_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::StructuredInputs::ParamCleanerTest < Minitest::Test
  Cleaner = Plutonium::StructuredInputs::ParamCleaner

  def test_single_passes_hash_through
    assert_equal({street: "1 A St", city: "Town"},
      Cleaner.call({"street" => "1 A St", "city" => "Town"}, repeat: false))
  end

  def test_single_strips_destroy
    assert_equal({street: "x"}, Cleaner.call({"street" => "x", "_destroy" => "1"}, repeat: false))
  end

  def test_single_blank_returns_empty_hash
    assert_equal({}, Cleaner.call(nil, repeat: false))
  end

  def test_repeater_normalizes_array
    input = [{"label" => "a"}, {"label" => "b"}]
    assert_equal [{label: "a"}, {label: "b"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_normalizes_index_keyed_hash
    input = {"0" => {"label" => "a"}, "1" => {"label" => "b"}}
    assert_equal [{label: "a"}, {label: "b"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_drops_all_blank_rows_and_strips_destroy
    input = [{"label" => "a", "_destroy" => "false"}, {"label" => ""}, {"label" => "c", "_destroy" => "1"}]
    assert_equal [{label: "a"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_blank_returns_empty_array
    assert_equal [], Cleaner.call(nil, repeat: true)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/param_cleaner_test.rb`
Expected: FAIL — uninitialized constant `Plutonium::StructuredInputs::ParamCleaner`.

- [ ] **Step 3: Write the cleaner**

```ruby
# lib/plutonium/structured_inputs/param_cleaner.rb
# frozen_string_literal: true

module Plutonium
  module StructuredInputs
    # Turns submitted structured-input params into the stored value.
    module ParamCleaner
      DESTROY_VALUES = [1, "1", true, "true"].freeze

      module_function

      # @param value [Hash, Array, nil] the extracted param for this input
      # @param repeat [Boolean, Integer] truthy ⇒ array (repeater), else hash
      # @return [Hash, Array<Hash>]
      def call(value, repeat:)
        repeat ? clean_collection(value) : clean_one(value)
      end

      def clean_one(value)
        return {} unless value.is_a?(Hash)
        strip(value)
      end

      def clean_collection(value)
        rows = value.is_a?(Hash) ? value.values : Array(value)
        rows
          .filter_map { |row| row.is_a?(Hash) ? row : nil }
          .reject { |row| destroy?(row) }
          .map { |row| strip(row) }
          .reject { |row| row.values.all? { |v| v.to_s.strip.empty? } }
      end

      def destroy?(row)
        DESTROY_VALUES.include?(row[:_destroy] || row["_destroy"])
      end

      # Drop _destroy and symbolize keys.
      def strip(row)
        row.to_h.except(:_destroy, "_destroy").transform_keys(&:to_sym)
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/param_cleaner_test.rb`
Expected: PASS (7 runs).

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/structured_inputs/param_cleaner.rb test/plutonium/structured_inputs/param_cleaner_test.rb
git commit -m "feat(structured-inputs): add param cleaner (single hash / cleaned array)"
```

```json:metadata
{"files": ["lib/plutonium/structured_inputs/param_cleaner.rb", "test/plutonium/structured_inputs/param_cleaner_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/param_cleaner_test.rb", "acceptanceCriteria": ["single passes hash through, strips _destroy", "repeater normalizes array and index-hash", "drops all-blank rows", "blank ⇒ {} or []"], "requiresUserVerification": false}
```

---

## Task 2: Interaction host — declare attribute, remove the old nested surface

**Goal:** On interactions, `structured_input` also declares the backing ActiveModel attribute (default `{}` single / `[]` repeat); remove `nested_input` and `accepts_nested_attributes_for` from interactions.

**Files:**
- Modify: `lib/plutonium/interaction/base.rb`
- Delete: `lib/plutonium/interaction/nested_attributes.rb`
- Test: replace `test/plutonium/ui/form/interaction_nested_input_test.rb` with `test/plutonium/interaction/structured_inputs_test.rb`

**Acceptance Criteria:**
- [ ] `structured_input :a` on an interaction adds `:a` to `attribute_names` with a fresh `{}` default; `structured_input :b, repeat: 3` defaults to `[]`.
- [ ] Defaults are not shared across instances (mutating one instance's value doesn't leak).
- [ ] Interactions do **not** respond to `nested_input`, `accepts_nested_attributes_for`, or `defined_nested_inputs`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/structured_inputs_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing test (and delete the obsolete one)**

```bash
git rm test/plutonium/ui/form/interaction_nested_input_test.rb
```

```ruby
# test/plutonium/interaction/structured_inputs_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::StructuredInputsTest < Minitest::Test
  def build_interaction(&block)
    Class.new(Plutonium::Resource::Interaction, &block)
  end

  def test_single_declares_attribute_defaulting_to_hash
    klass = build_interaction do
      structured_input(:address) { |f| f.input :street }
    end
    instance = klass.new(view_context: nil)
    assert_includes instance.attribute_names, "address"
    assert_equal({}, instance.address)
  end

  def test_repeat_declares_attribute_defaulting_to_array
    klass = build_interaction do
      structured_input(:contacts, repeat: 3) { |f| f.input :label }
    end
    assert_equal [], klass.new(view_context: nil).contacts
  end

  def test_defaults_are_not_shared_between_instances
    klass = build_interaction do
      structured_input(:contacts, repeat: 3) { |f| f.input :label }
    end
    a = klass.new(view_context: nil)
    a.contacts << {label: "x"}
    b = klass.new(view_context: nil)
    assert_equal [], b.contacts
  end

  def test_nested_input_is_removed_from_interactions
    refute Plutonium::Resource::Interaction.respond_to?(:nested_input)
    refute Plutonium::Resource::Interaction.respond_to?(:accepts_nested_attributes_for)
    refute Plutonium::Resource::Interaction.respond_to?(:defined_nested_inputs)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/structured_inputs_test.rb`
Expected: FAIL — `structured_input` not yet wired to declare attributes; `nested_input` still present.

- [ ] **Step 3: Edit `lib/plutonium/interaction/base.rb`**

Remove these two includes (currently lines 28–29):

```ruby
      include Plutonium::Definition::NestedInputs
      include Plutonium::Interaction::NestedAttributes
```

Add the structured-inputs include and the attribute-declaring override. Place the include with the other `include` lines, and the override below the `included`/class body:

```ruby
      include Plutonium::Definition::StructuredInputs

      # On interactions, declaring a structured input also declares the backing
      # ActiveModel attribute so the value survives `attributes=` and shows up in
      # `attribute_names` (which drives the interaction form's field list).
      def self.structured_input(name, **options, &block)
        super
        default = options[:repeat] ? -> { [] } : -> { {} }
        attribute name, default: default
      end
```

> `super` resolves to `StructuredInputs::ClassMethods#structured_input` (ActiveSupport::Concern puts it in the singleton ancestry), so the registry entry is still written.

- [ ] **Step 4: Delete the dead module**

```bash
git rm lib/plutonium/interaction/nested_attributes.rb
```

Confirm nothing else references it:

```bash
grep -rn "Interaction::NestedAttributes" lib/ app/ test/
```
Expected: no matches.

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/structured_inputs_test.rb`
Expected: PASS (4 runs).

- [ ] **Step 6: Run the interaction + action suites for regressions**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/action/interactive_test.rb`
Expected: PASS (no refs to the removed modules).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(interaction): structured_input declares attribute; drop nested_input/accepts_nested_attributes_for"
```

```json:metadata
{"files": ["lib/plutonium/interaction/base.rb", "lib/plutonium/interaction/nested_attributes.rb", "test/plutonium/interaction/structured_inputs_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/structured_inputs_test.rb", "acceptanceCriteria": ["structured_input declares attribute with {} / [] default", "defaults not shared across instances", "nested_input/accepts_nested_attributes_for/defined_nested_inputs removed from interactions"], "requiresUserVerification": false}
```

---

## Task 3: Rendering — `RendersStructuredInputs` concern + form branch

**Goal:** Render a structured input on the form: single via `nest_one` (one fieldset), repeater via `nest_many` (the existing repeater chrome), classless, fields named `host[name][...]`.

**Files:**
- Create: `lib/plutonium/ui/form/concerns/renders_structured_inputs.rb`
- Modify: `lib/plutonium/ui/form/resource.rb` (include concern; branch `render_resource_field`)
- Test: covered by the integration tests in Task 6 (rendering needs a real form + view context).

**Acceptance Criteria:**
- [ ] `render_resource_field` dispatches a name in `defined_structured_inputs` to `render_structured_input`, before the `nested_input` and simple-field branches.
- [ ] Single renders one `<fieldset>` of the declared inputs, no add/remove chrome, no hidden id/`_destroy`, fields named `host[name][field]`.
- [ ] Repeater renders the `nested-resource-form-fields` controller container with `limit` = the `repeat` cap, a `<template>` blank row, existing rows from the array value, an add button and per-row delete control, fields named `host[name][N][field]` / `host[name][NEW_RECORD][field]`, no hidden id/`_destroy`.

**Verify:** exercised by `test/integration/admin_portal/structured_input_rendering_test.rb` (Task 6).

**Steps:**

- [ ] **Step 1: Write the concern**

Model the structure on `lib/plutonium/ui/form/concerns/renders_nested_resource_fields.rb`, but classless (blank row `{}`, `as: :<name>`, no hidden id/`_destroy`). The repeat cap: `repeat: true` ⇒ `DEFAULT_LIMIT`, `repeat: <int>` ⇒ that int.

```ruby
# lib/plutonium/ui/form/concerns/renders_structured_inputs.rb
# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Concerns
        # Renders classless structured inputs (single → hash via nest_one,
        # repeater → array via nest_many). Field/namespace work is delegated to
        # the form; this concern owns the structural markup.
        # @api private
        module RendersStructuredInputs
          extend ActiveSupport::Concern

          DEFAULT_REPEAT_LIMIT = 10

          private

          def render_structured_input(name)
            entry = resource_definition.defined_structured_inputs[name]
            options = entry[:options] || {}
            definition = structured_input_fields_definition(entry)
            fields = options[:fields] || definition.defined_inputs.keys
            repeat = options[:repeat]

            if repeat
              render_structured_repeater(name, definition, fields, repeat_limit(repeat))
            else
              render_structured_single(name, definition, fields)
            end
          end

          def structured_input_fields_definition(entry)
            return entry[:options][:using] if entry[:options]&.key?(:using)

            holder = Plutonium::Definition::StructuredInputs::FieldsDefinition.new
            entry[:block].call(holder)
            holder
          end

          def repeat_limit(repeat)
            repeat.is_a?(Integer) ? repeat : DEFAULT_REPEAT_LIMIT
          end

          # --- single -------------------------------------------------------

          def render_structured_single(name, definition, fields)
            div(class: "col-span-full space-y-2 my-4") do
              h2(class: "text-lg font-semibold text-[var(--pu-text)]") { name.to_s.humanize }
              nest_one(name, as: name, default: {}) do |nested|
                render_structured_fieldset(nested, definition, fields)
              end
            end
          end

          # --- repeater -----------------------------------------------------

          def render_structured_repeater(name, definition, fields, limit)
            div(
              class: "col-span-full space-y-2 my-4",
              data: {
                controller: "nested-resource-form-fields",
                nested_resource_form_fields_limit_value: limit
              }
            ) do
              h2(class: "text-lg font-semibold text-[var(--pu-text)]") { name.to_s.humanize }
              template data_nested_resource_form_fields_target: "template" do
                nest_many(name, as: name, collection: {NEW_RECORD: {}}, default: {NEW_RECORD: {}}, template: true) do |nested|
                  render_structured_fieldset(nested, definition, fields)
                end
              end
              nest_many(name, as: name, default: []) do |nested|
                render_structured_fieldset(nested, definition, fields)
              end
              div(data_nested_resource_form_fields_target: :target, hidden: true)
              render_structured_add_button(name)
            end
          end

          def render_structured_fieldset(nested, definition, fields)
            fieldset(
              class: "nested-resource-form-fields border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] p-4 space-y-4 relative"
            ) do
              div(class: "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-4 grid-flow-row-dense") do
                fields.each { |input| render_simple_resource_field(input, definition, nested) }
              end
              render_structured_delete_button
            end
          end

          def render_structured_delete_button
            div(class: "flex items-center justify-end") do
              label(class: "inline-flex items-center text-md font-medium text-red-900 cursor-pointer") do
                plain "Delete"
                input(
                  type: :checkbox,
                  class: "w-4 h-4 ms-2 text-danger-600 bg-danger-100 border-danger-300 rounded cursor-pointer",
                  data_action: "nested-resource-form-fields#remove"
                )
              end
            end
          end

          def render_structured_add_button(name)
            div do
              button(
                type: :button,
                class: "inline-block",
                data: {action: "nested-resource-form-fields#add", nested_resource_form_fields_target: "addButton"}
              ) do
                span(class: "bg-secondary-700 text-white flex items-center justify-center px-4 py-1.5 text-sm font-medium rounded-lg") do
                  render Phlex::TablerIcons::Plus.new(class: "w-4 h-4 mr-1")
                  span { "Add #{name.to_s.singularize.humanize}" }
                end
              end
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Include the concern and branch `render_resource_field`**

In `lib/plutonium/ui/form/resource.rb`, add the include with the other concern includes (near the top of the class):

```ruby
        include Plutonium::UI::Form::Concerns::RendersStructuredInputs
```

Replace the body of `render_resource_field` (currently `resource.rb:165-173`) with the structured-input branch added FIRST:

```ruby
        def render_resource_field(name)
          when_permitted(name) do
            if resource_definition.respond_to?(:defined_structured_inputs) && resource_definition.defined_structured_inputs[name]
              render_structured_input(name)
            elsif resource_definition.respond_to?(:defined_nested_inputs) && resource_definition.defined_nested_inputs[name]
              render_nested_resource_field(name)
            else
              render_simple_resource_field(name, resource_definition, self)
            end
          end
        end
```

- [ ] **Step 3: Smoke-check it loads**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/form/hidden_input_test.rb`
Expected: PASS (form still constructs/loads with the new concern).

- [ ] **Step 4: Commit**

```bash
git add lib/plutonium/ui/form/concerns/renders_structured_inputs.rb lib/plutonium/ui/form/resource.rb
git commit -m "feat(ui): render structured inputs (single + repeater), classless"
```

```json:metadata
{"files": ["lib/plutonium/ui/form/concerns/renders_structured_inputs.rb", "lib/plutonium/ui/form/resource.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/form/hidden_input_test.rb", "acceptanceCriteria": ["render_resource_field dispatches structured inputs first", "single renders one fieldset, no chrome", "repeater renders controller container + template + add/delete", "no hidden id/_destroy"], "requiresUserVerification": false}
```

---

## Task 4: Param flow — apply the cleaner on both hosts

**Goal:** Run extracted structured-input params through `ParamCleaner` (keyed off `defined_structured_inputs`) before assignment, for resources and interactions.

**Files:**
- Modify: `lib/plutonium/resource/controller.rb` (`submitted_resource_params`)
- Modify: `lib/plutonium/resource/controllers/interactive_actions.rb` (`submitted_interaction_params`)
- Create: `lib/plutonium/structured_inputs/params_concern.rb` (shared cleaning helper)
- Test: `test/plutonium/structured_inputs/params_concern_test.rb`

**Acceptance Criteria:**
- [ ] A shared helper `clean_structured_inputs(definition, params)` rewrites each `defined_structured_inputs` key in `params` through `ParamCleaner` with the right `repeat:` flag; leaves other keys untouched.
- [ ] `submitted_resource_params` and `submitted_interaction_params` apply it before returning.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/params_concern_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/structured_inputs/params_concern_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::StructuredInputs::ParamsConcernTest < Minitest::Test
  class Host
    include Plutonium::StructuredInputs::ParamsConcern
  end

  def definition
    Class.new(Plutonium::Definition::Base) do
      structured_input(:address) { |f| f.input :street }
      structured_input(:contacts, repeat: 5) { |f| f.input :label }
    end.new
  end

  def test_cleans_single_and_repeater_keys_only
    params = {
      name: "keep me",
      address: {"street" => "1 A St", "_destroy" => "1"},
      contacts: [{"label" => "a"}, {"label" => ""}]
    }
    out = Host.new.clean_structured_inputs(definition, params)

    assert_equal "keep me", out[:name]
    assert_equal({street: "1 A St"}, out[:address])
    assert_equal [{label: "a"}], out[:contacts]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/params_concern_test.rb`
Expected: FAIL — uninitialized constant `ParamsConcern`.

- [ ] **Step 3: Write the concern**

```ruby
# lib/plutonium/structured_inputs/params_concern.rb
# frozen_string_literal: true

module Plutonium
  module StructuredInputs
    # Rewrites structured-input params in place through ParamCleaner. Shared by
    # the resource controller and the interactive-actions controller.
    module ParamsConcern
      # @param definition [#defined_structured_inputs]
      # @param params [Hash] extracted form params (mutable copy)
      # @return [Hash]
      def clean_structured_inputs(definition, params)
        return params unless definition.respond_to?(:defined_structured_inputs)

        definition.defined_structured_inputs.each do |name, entry|
          next unless params.key?(name)

          repeat = entry[:options]&.fetch(:repeat, false)
          params[name] = Plutonium::StructuredInputs::ParamCleaner.call(params[name], repeat:)
        end
        params
      end
    end
  end
end
```

- [ ] **Step 4: Apply on resources**

In `lib/plutonium/resource/controller.rb`, `submitted_resource_params` (currently `controller.rb:143-148`) — wrap the extracted hash. Include the concern in the controller module and clean using the current definition:

Add near the top of the controller module body: `include Plutonium::StructuredInputs::ParamsConcern`

Then:

```ruby
      def submitted_resource_params
        extraction_record = resource_record?&.dup || resource_class.new
        @submitted_resource_params ||= begin
          extracted = build_form(extraction_record, form_action: false)
            .extract_input(params, view_context:)[resource_param_key.to_sym].compact
          clean_structured_inputs(current_definition, extracted)
        end
      end
```

> `current_definition` is the resource definition in controller context (see `presentable.rb`). If unavailable in this exact method, use `resource_definition(resource_class)`.

- [ ] **Step 5: Apply on interactions**

In `lib/plutonium/resource/controllers/interactive_actions.rb`, include the concern in the module and clean using the interaction (which is itself the definition):

```ruby
      def submitted_interaction_params
        @submitted_interaction_params ||= begin
          interaction = current_interactive_action.interaction
          extracted = interaction
            .build_form(interaction.new(view_context:))
            .extract_input(params, view_context:)[:interaction]
          clean_structured_inputs(interaction, extracted)
        end
      end
```

> The interaction CLASS exposes `defined_structured_inputs` (class-level registry); pass the class.

- [ ] **Step 6: Run the cleaner-concern test + a smoke of the controllers**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/params_concern_test.rb`
Expected: PASS.
Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/org_portal/catalog_products_test.rb`
Expected: PASS (existing resource param flow unaffected — definitions without structured inputs are untouched).

- [ ] **Step 7: Commit**

```bash
git add lib/plutonium/structured_inputs/params_concern.rb lib/plutonium/resource/controller.rb lib/plutonium/resource/controllers/interactive_actions.rb test/plutonium/structured_inputs/params_concern_test.rb
git commit -m "feat(structured-inputs): clean structured params before assignment (both hosts)"
```

```json:metadata
{"files": ["lib/plutonium/structured_inputs/params_concern.rb", "lib/plutonium/resource/controller.rb", "lib/plutonium/resource/controllers/interactive_actions.rb", "test/plutonium/structured_inputs/params_concern_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/structured_inputs/params_concern_test.rb", "acceptanceCriteria": ["clean_structured_inputs rewrites only structured keys", "applied in submitted_resource_params", "applied in submitted_interaction_params"], "requiresUserVerification": false}
```

---

## Task 5: Dummy fixtures (generators) — resource JSON column + interaction action

**Goal:** Stand up the fixtures the integration tests render against, using the `pu:*` generators per project convention.

**Files:**
- Create (generated): a dummy resource with a `json` column and `structured_input` in its definition + policy permit.
- Create (generated): a dummy interaction with `structured_input` (single + repeat) wired as an action.
- Modify: the generated definition/policy to add the structured inputs.

**Acceptance Criteria:**
- [ ] A resource (e.g. `Catalog::Settings` or a new `Profile`) has a `json` column `payload` and `structured_input :payload` (single) + `structured_input :tags, repeat: 5` over a second json column.
- [ ] An interaction wired to an existing resource action declares `structured_input :address` (single) + `structured_input :contacts, repeat: 3`.
- [ ] Migrations run; the dummy app boots.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/resources_test.rb` → PASS (app boots with new fixtures).

**Steps:**

- [ ] **Step 1: Generate the resource fixture**

From `test/dummy`, generate a resource with json columns (quote shell args). Example using the catalog package:

```bash
cd test/dummy && bin/rails g pu:res:scaffold Catalog::Spec 'payload:json' 'rows:json' --dest=catalog
```

> If `json` is not a recognized scaffold type, generate with `text` columns and change the migration/model to `t.json`. SQLite (the dummy DB) supports `json` columns via Rails serialization.

- [ ] **Step 2: Add structured inputs to the generated definition**

Edit `test/dummy/packages/catalog/app/definitions/catalog/spec_definition.rb`:

```ruby
class Catalog::SpecDefinition < Catalog::ResourceDefinition
  structured_input :payload do |f|
    f.input :title
    f.input :notes
  end

  structured_input :rows, repeat: 5 do |f|
    f.input :key
    f.input :value
  end
end
```

- [ ] **Step 3: Permit the structured inputs in the generated policy**

Edit `test/dummy/packages/catalog/app/policies/catalog/spec_policy.rb`:

```ruby
class Catalog::SpecPolicy < Catalog::ResourcePolicy
  def permitted_attributes_for_create
    [:payload, :rows]
  end
  alias_method :permitted_attributes_for_update, :permitted_attributes_for_create

  def permitted_attributes_for_read
    [:payload, :rows, :created_at]
  end
end
```

Register the resource in the admin portal routes (`test/dummy/packages/admin_portal/config/routes.rb`): `register_resource ::Catalog::Spec`.

- [ ] **Step 4: Generate the interaction fixture**

Create `test/dummy/packages/catalog/app/interactions/catalog/collect_spec.rb` (a non-immediate interactive action with structured inputs), and wire it onto an existing resource (e.g. `Catalog::Product`) via `action :collect_spec, interaction: Catalog::CollectSpec` in `ProductDefinition`:

```ruby
class Catalog::CollectSpec < Catalog::ResourceInteraction
  attribute :resource

  structured_input :address do |f|
    f.input :street
    f.input :city
  end

  structured_input :contacts, repeat: 3 do |f|
    f.input :label
    f.input :phone_number
  end

  private

  def execute
    success(resource).with_message("Collected #{contacts.size} contacts")
  end
end
```

- [ ] **Step 5: Run migrations and boot check**

```bash
cd test/dummy && bin/rails db:migrate RAILS_ENV=test
```

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/resources_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "test(dummy): add structured-input fixtures (resource json columns + interaction action)"
```

```json:metadata
{"files": ["test/dummy/packages/catalog/app/definitions/catalog/spec_definition.rb", "test/dummy/packages/catalog/app/policies/catalog/spec_policy.rb", "test/dummy/packages/catalog/app/interactions/catalog/collect_spec.rb", "test/dummy/packages/admin_portal/config/routes.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/resources_test.rb", "acceptanceCriteria": ["resource with json columns + structured_input", "interaction with single + repeat structured_input wired as action", "migrations run, app boots"], "requiresUserVerification": false}
```

---

## Task 6: Integration tests — render + round-trip (both hosts)

**Goal:** Characterize the rendered HTML and the persistence/round-trip for single and repeater, on resources (JSON column) and interactions (attribute → execute).

**Files:**
- Create: `test/integration/admin_portal/structured_input_rendering_test.rb`
- Create: `test/integration/admin_portal/structured_input_roundtrip_test.rb`

**Acceptance Criteria:**
- [ ] Resource new form renders: single fieldset for `payload` with `catalog_spec[payload][title]`; repeater for `rows` with the controller container, `<template>`, `catalog_spec[rows][NEW_RECORD][key]`, add/delete, no hidden id/`_destroy`.
- [ ] Resource create persists `payload` as a hash and `rows` as a cleaned array into the JSON columns; blank rows dropped; edit repopulates.
- [ ] Interaction action form renders the single + repeater; submitting reaches `execute` with `address` a hash and `contacts` an array.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/structured_input_rendering_test.rb` and `..._roundtrip_test.rb` → PASS.

**Steps:**

- [ ] **Step 1: Write the rendering test**

```ruby
# test/integration/admin_portal/structured_input_rendering_test.rb
# frozen_string_literal: true

require "test_helper"

class AdminPortal::StructuredInputRenderingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "single structured input renders one fieldset with nested names" do
    get "/admin/catalog/specs/new"
    assert_response :success
    assert_includes response.body, %(name="catalog_spec[payload][title]")
    assert_includes response.body, %(name="catalog_spec[payload][notes]")
  end

  test "repeater renders the controller container, template, and nested names" do
    get "/admin/catalog/specs/new"
    assert_match(/data-controller="nested-resource-form-fields"[^>]*data-nested-resource-form-fields-limit-value="5"/, response.body)
    assert_includes response.body, %(<template data-nested-resource-form-fields-target="template">)
    assert_includes response.body, %(name="catalog_spec[rows][NEW_RECORD][key]")
    assert_includes response.body, %(data-action="nested-resource-form-fields#add")
    refute_includes response.body, %(catalog_spec[rows][NEW_RECORD][_destroy])
  end
end
```

- [ ] **Step 2: Write the round-trip test**

```ruby
# test/integration/admin_portal/structured_input_roundtrip_test.rb
# frozen_string_literal: true

require "test_helper"

class AdminPortal::StructuredInputRoundtripTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "create persists single hash and cleaned repeater array to json columns" do
    post "/admin/catalog/specs", params: {catalog_spec: {
      payload: {title: "T", notes: "N"},
      rows: {"0" => {key: "a", value: "1"}, "1" => {key: "", value: ""}}
    }}
    spec = Catalog::Spec.order(:id).last
    assert_equal({"title" => "T", "notes" => "N"}, spec.payload)
    assert_equal([{"key" => "a", "value" => "1"}], spec.rows)
  end
end
```

- [ ] **Step 3: Run both; fix rendering/extraction until green**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/structured_input_rendering_test.rb`
Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/structured_input_roundtrip_test.rb`
Expected: PASS. If field naming differs (e.g. `extract_input` needs `as:` adjusted), reconcile Task 3's `as:`/`nest_*` calls and Task 4's cleaning here, since these tests are the source of truth for the contract.

> Add an interaction render+execute test once the interactive-action route for `Catalog::CollectSpec` is confirmed (GET the action form, POST the commit, assert the success message reflects `contacts.size`). Use `test/integration/org_portal/catalog_products_test.rb` for the action URL pattern.

- [ ] **Step 4: Commit**

```bash
git add test/integration/admin_portal/structured_input_rendering_test.rb test/integration/admin_portal/structured_input_roundtrip_test.rb
git commit -m "test(structured-inputs): integration render + round-trip (resource + interaction)"
```

```json:metadata
{"files": ["test/integration/admin_portal/structured_input_rendering_test.rb", "test/integration/admin_portal/structured_input_roundtrip_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/structured_input_rendering_test.rb", "acceptanceCriteria": ["single + repeater render with correct nested names, no hidden id/_destroy", "create persists hash + cleaned array to json columns", "interaction execute receives hash + array"], "requiresUserVerification": false}
```

---

## Task 7: Full regression + docs

**Goal:** Confirm nothing regressed across the suite and Rails versions; document `structured_input` and the interaction removals.

**Files:**
- Modify: `lib/plutonium/interaction/README.md`
- Create: `docs/reference/` page (or extend the resource definition / interaction docs) describing `structured_input`.
- Modify: any skill doc referencing interaction `nested_input` (search first).

**Acceptance Criteria:**
- [ ] `bundle exec appraisal rails-8.1 rake test` passes; spot-check `rails-7` and `rails-8.0` on the new test files.
- [ ] README no longer shows `accepts_nested_attributes_for` + `nested_input` on an interaction; shows `structured_input` instead.
- [ ] Docs describe single→hash, `repeat:`→array, JSON-column backing on resources, attribute backing on interactions.

**Verify:** `bundle exec appraisal rails-8.1 rake test` → 0 failures.

**Steps:**

- [ ] **Step 1: Rework the interaction README**

In `lib/plutonium/interaction/README.md`, replace the `accepts_nested_attributes_for` + `nested_input` example with a `structured_input` example (single + repeat), and add a note that `nested_input`/`accepts_nested_attributes_for` are not available on interactions.

- [ ] **Step 2: Search for and update other docs/skills**

```bash
grep -rln "nested_input\|accepts_nested_attributes_for" docs/ .claude/skills/ | grep -v node_modules
```
Update any that describe these on interactions; add `structured_input` to the resource/definition and interaction references.

- [ ] **Step 3: Full suite + cross-version spot check**

```bash
bundle exec appraisal rails-8.1 rake test
bundle exec appraisal rails-8.0 ruby -Itest test/plutonium/definition/structured_inputs_test.rb
bundle exec appraisal rails-7   ruby -Itest test/plutonium/structured_inputs/param_cleaner_test.rb
```
Expected: 0 failures.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs(structured-inputs): document structured_input; rework interaction nested docs"
```

```json:metadata
{"files": ["lib/plutonium/interaction/README.md", "docs/"], "verifyCommand": "bundle exec appraisal rails-8.1 rake test", "acceptanceCriteria": ["full suite green", "README/docs document structured_input and the interaction removals"], "requiresUserVerification": false}
```

---

## Self-Review notes

- **Spec coverage:** DSL (Task 0), cleaner (Task 1), interaction host + removals (Task 2), rendering (Task 3), param flow both hosts (Task 4), fixtures (Task 5), render + round-trip tests both hosts (Task 6), regression + docs (Task 7). All spec sections mapped.
- **Open spec questions resolved here:** clean-step home = `submitted_resource_params` + `submitted_interaction_params` (Task 4); field naming = `as: :<name>` (Task 3, verified by Task 6); JSON column type = `json` on SQLite (Task 5).
- **Risk:** the `as: :<name>` extraction contract is verified by Task 6's round-trip; if `extract_input` namespaces differently, Task 3/4/6 are reconciled together (Task 6 is the contract source of truth).
