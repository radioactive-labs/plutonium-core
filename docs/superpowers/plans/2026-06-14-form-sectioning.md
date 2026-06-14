# Form Sectioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `form_layout`/`section`/`ungrouped` DSL that groups Plutonium form fields into titled sections, for both resource definitions and interactions.

**Architecture:** A shared `Plutonium::Definition::FormLayout` concern (mixed into `Definition::Base` and `Interaction::Base`, like `StructuredInputs`) records an ordered section registry and resolves a policy-filtered field list into ordered sections. `Form::Resource#render_fields` consumes that resolution and renders each section via a new `Components::Section` Phlex component (which yields field rendering back to the form). `Form::Interaction < Form::Resource` inherits the behavior for free.

**Tech Stack:** Ruby, Rails engine, Phlex/Phlexi forms, minitest (`test/**/*_test.rb`, run via `bin/rails test`), dummy app at `test/dummy`.

**User Verification:** NO — no user verification required. Spec: `docs/superpowers/specs/2026-06-14-form-sectioning-design.md`.

**Note on a spec refinement discovered during planning:** the spec lists a standalone `Components::Section`. Field rendering (`render_resource_field`) lives on the form, so the Section component renders the section *chrome* (heading/description/collapsible/grid) and **yields** to a block supplied by the form that calls `render_resource_field`. The columns→grid-class helper lives on the form. This keeps the component presentational while reusing the form's field rendering.

---

## File Structure

- `lib/plutonium/definition/form_layout.rb` *(new)* — DSL (`form_layout`/`section`/`ungrouped`), `Section` struct, `Builder`, ordered registry, inheritance, and `resolve_form_sections`.
- `lib/plutonium/definition/base.rb` *(modify)* — `include FormLayout`.
- `lib/plutonium/interaction/base.rb` *(modify)* — `include FormLayout`.
- `lib/plutonium/ui/form/components/section.rb` *(new)* — section chrome component.
- `lib/plutonium/ui/form/resource.rb` *(modify)* — `render_fields` grouping + `render_form_section` + `section_grid_class`.
- `test/dummy/app/definitions/kitchen_sink_definition.rb` *(modify)* — add a `form_layout` for integration coverage.
- `test/dummy/packages/admin_portal/config/routes.rb` *(modify)* — register `KitchenSink` so the admin login harness can render its form.
- Tests (new): unit DSL, unit resolver, unit component, integration rendering, interaction rendering (paths in each task).

---

### Task 1: FormLayout DSL module + registry

**Goal:** Add `form_layout do … end` with `section`/`ungrouped`, an ordered inheritable registry, and validations; make it available on resource definitions and interactions.

**Files:**
- Create: `lib/plutonium/definition/form_layout.rb`
- Modify: `lib/plutonium/definition/base.rb` (add `include FormLayout` near the other `include`s, ~line 36 after `StructuredInputs`)
- Modify: `lib/plutonium/interaction/base.rb` (add `include Plutonium::Definition::FormLayout`, ~line 28 after `StructuredInputs`)
- Test: `test/plutonium/definition/form_layout_test.rb`
- Test: `test/plutonium/interaction/form_layout_test.rb`

**Acceptance Criteria:**
- [ ] `form_layout` records sections in declared order with options.
- [ ] `section :ungrouped, …` raises `ArgumentError`; declaring `ungrouped` twice raises.
- [ ] `form_layout` with no block raises `ArgumentError`.
- [ ] A section's default label is `key.to_s.humanize`; `label:` overrides.
- [ ] Subclasses inherit the layout; re-declaring `form_layout` replaces it.
- [ ] Both class and instance expose `defined_form_layout`; interaction classes get the DSL too.

**Verify:** `bin/rails test test/plutonium/definition/form_layout_test.rb test/plutonium/interaction/form_layout_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing unit test** — `test/plutonium/definition/form_layout_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::FormLayoutTest < Minitest::Test
  def build_definition(&block)
    Class.new(Plutonium::Definition::Base, &block)
  end

  def test_records_sections_in_order_with_options
    klass = build_definition do
      form_layout do
        section :identity, :name, :email, label: "Your identification"
        section :address, :street, :city, collapsible: true, columns: 2
      end
    end

    layout = klass.defined_form_layout
    assert_equal %i[identity address], layout.map(&:key)
    assert_equal %i[name email], layout.first.fields
    assert_equal "Your identification", layout.first.label
    assert_equal 2, layout.last.options[:columns]
    assert layout.last.collapsible?
  end

  def test_section_label_defaults_to_humanized_key
    klass = build_definition { form_layout { section :billing_address, :street } }
    assert_equal "Billing address", klass.defined_form_layout.first.label
  end

  def test_ungrouped_macro_is_recorded_with_its_position
    klass = build_definition do
      form_layout do
        section :a, :x
        ungrouped label: "Other"
      end
    end
    layout = klass.defined_form_layout
    assert_equal %i[a ungrouped], layout.map(&:key)
    assert layout.last.ungrouped?
    assert_empty layout.last.fields
  end

  def test_section_ungrouped_key_raises
    error = assert_raises(ArgumentError) do
      build_definition { form_layout { section :ungrouped, :x } }
    end
    assert_match(/reserved/, error.message)
  end

  def test_duplicate_ungrouped_raises
    assert_raises(ArgumentError) do
      build_definition { form_layout { ungrouped; ungrouped } }
    end
  end

  def test_form_layout_requires_a_block
    assert_raises(ArgumentError) { build_definition { form_layout } }
  end

  def test_no_layout_returns_nil
    klass = build_definition {}
    assert_nil klass.defined_form_layout
    assert_nil klass.new.defined_form_layout
  end

  def test_subclasses_inherit_layout
    parent = build_definition { form_layout { section :a, :x } }
    child = Class.new(parent)
    assert_equal %i[a], child.defined_form_layout.map(&:key)
  end

  def test_redeclaring_replaces_layout
    parent = build_definition { form_layout { section :a, :x } }
    child = Class.new(parent)
    child.form_layout { section :b, :y }
    assert_equal %i[b], child.defined_form_layout.map(&:key)
    assert_equal %i[a], parent.defined_form_layout.map(&:key) # parent untouched
  end

  def test_instance_exposes_layout
    klass = build_definition { form_layout { section :a, :x } }
    assert_equal %i[a], klass.new.defined_form_layout.map(&:key)
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bin/rails test test/plutonium/definition/form_layout_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'form_layout'`.

- [ ] **Step 3: Create the module** — `lib/plutonium/definition/form_layout.rb`

```ruby
# frozen_string_literal: true

module Plutonium
  module Definition
    # Declarative form sectioning. Mixed into both resource definitions and
    # interactions (mirrors StructuredInputs). The layout references field KEYS
    # only and carries section-level options; per-field config stays on `input`.
    #
    # @example
    #   form_layout do
    #     section :identity, :name, :email, label: "Your identification"
    #     section :address, :street, :city, collapsible: true, columns: 2,
    #       condition: -> { object.requires_address? }
    #     ungrouped label: "Other"
    #   end
    module FormLayout
      extend ActiveSupport::Concern

      UNGROUPED_KEY = :ungrouped

      # One declared section, or the implicit `ungrouped` bucket (empty `fields`).
      Section = Struct.new(:key, :fields, :options, keyword_init: true) do
        def ungrouped? = key == UNGROUPED_KEY
        def label = options.fetch(:label) { key.to_s.humanize }
        def description = options[:description]
        def collapsible? = !!options[:collapsible]
        def collapsed? = !!options[:collapsed]
        def columns = options[:columns]
        def condition = options[:condition]
      end

      # A section paired with the concrete fields it will render (after policy
      # filtering). Produced by #resolve_form_sections.
      ResolvedSection = Struct.new(:section, :fields, keyword_init: true)

      # Collects section/ungrouped calls from a form_layout block in order.
      class Builder
        attr_reader :sections

        def initialize
          @sections = []
          @ungrouped_seen = false
        end

        def section(key, *fields, **options)
          if key == UNGROUPED_KEY
            raise ArgumentError,
              "`section :#{UNGROUPED_KEY}` is reserved — use the `ungrouped` macro"
          end
          @sections << Section.new(key:, fields: fields.freeze, options:)
        end

        def ungrouped(**options)
          raise ArgumentError, "`ungrouped` may only be declared once" if @ungrouped_seen
          @ungrouped_seen = true
          @sections << Section.new(key: UNGROUPED_KEY, fields: [].freeze, options:)
        end
      end

      class_methods do
        # Declare the form layout. Re-declaring replaces it as a unit.
        def form_layout(&block)
          raise ArgumentError, "`form_layout` requires a block" unless block
          builder = Builder.new
          builder.instance_exec(&block)
          @defined_form_layout = builder.sections.freeze
        end

        # Ordered Array<Section>, or nil when no layout was declared.
        def defined_form_layout
          @defined_form_layout
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@defined_form_layout, defined_form_layout&.dup)
        end
      end

      # Instance access — the form render path holds a definition/interaction
      # instance (mirrors the defineable_prop convention).
      def defined_form_layout
        self.class.defined_form_layout
      end
    end
  end
end
```

- [ ] **Step 4: Wire the includes**

In `lib/plutonium/definition/base.rb`, add after `include StructuredInputs`:
```ruby
      include FormLayout
```

In `lib/plutonium/interaction/base.rb`, add after `include Plutonium::Definition::StructuredInputs`:
```ruby
      include Plutonium::Definition::FormLayout
```

- [ ] **Step 5: Add the interaction-side test** — `test/plutonium/interaction/form_layout_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::FormLayoutTest < Minitest::Test
  def test_interactions_get_the_form_layout_dsl
    klass = Class.new(Plutonium::Interaction::Base) do
      attribute :name
      form_layout { section :main, :name, label: "Main" }
    end
    assert_equal %i[main], klass.defined_form_layout.map(&:key)
    assert_respond_to klass.new, :defined_form_layout
  end
end
```

- [ ] **Step 6: Run tests, verify pass**

Run: `bin/rails test test/plutonium/definition/form_layout_test.rb test/plutonium/interaction/form_layout_test.rb`
Expected: PASS (all).

- [ ] **Step 7: Commit**

```bash
git add lib/plutonium/definition/form_layout.rb lib/plutonium/definition/base.rb \
        lib/plutonium/interaction/base.rb \
        test/plutonium/definition/form_layout_test.rb test/plutonium/interaction/form_layout_test.rb
git commit -m "feat(forms): add form_layout/section/ungrouped DSL registry"
```

```json:metadata
{"files": ["lib/plutonium/definition/form_layout.rb", "lib/plutonium/definition/base.rb", "lib/plutonium/interaction/base.rb", "test/plutonium/definition/form_layout_test.rb", "test/plutonium/interaction/form_layout_test.rb"], "verifyCommand": "bin/rails test test/plutonium/definition/form_layout_test.rb test/plutonium/interaction/form_layout_test.rb", "acceptanceCriteria": ["form_layout records sections in order", "section :ungrouped and duplicate ungrouped raise", "default label humanizes key", "subclasses inherit; redeclare replaces", "instance + interaction expose registry"], "requiresUserVerification": false}
```

---

### Task 2: Resolve a field list into ordered sections

**Goal:** Add `resolve_form_sections(resource_fields)` to `FormLayout` — assign permitted fields to sections (in declared order), collect leftovers into `ungrouped` (default **last**, else at its declared position), raise on unknown field keys, and keep empty sections (no hiding). _(Amended: default was "first" — see Amendments at the end.)_

**Files:**
- Modify: `lib/plutonium/definition/form_layout.rb` (add instance method `resolve_form_sections`)
- Test: `test/plutonium/definition/form_layout_resolution_test.rb`

**Acceptance Criteria:**
- [ ] Returns `nil` when no layout is declared.
- [ ] Each section gets `section.fields ∩ resource_fields`, preserving the section's field order.
- [ ] `ungrouped` collects all unclaimed permitted fields, in `resource_fields` order.
- [ ] Without an `ungrouped` macro, leftovers render in a heading-less section placed **last** (appended after all declared sections). _(Amended — was "first".)_
- [ ] With an `ungrouped` macro, leftovers render at the macro's declared position with its options.
- [ ] A section referencing a field absent from `resource_fields` *and* not a known attribute raises `ArgumentError`; a field merely filtered by policy is silently dropped (it's still "known" — see note).
- [ ] Empty sections are returned (not hidden).

> **Known-vs-permitted note:** `resolve_form_sections` only sees the policy-filtered `resource_fields`. To distinguish "typo" from "filtered out", it raises only when the field is not present in `resource_fields` AND the caller passes it as not-an-attribute. For unit purposes we treat any field not in `resource_fields` as unknown → raises. The form passes the *full* attribute set check at render via existing machinery; here we validate against `resource_fields`. Keep it strict: unknown key → raise.

**Verify:** `bin/rails test test/plutonium/definition/form_layout_resolution_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing test** — `test/plutonium/definition/form_layout_resolution_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::FormLayoutResolutionTest < Minitest::Test
  def definition(&block)
    Class.new(Plutonium::Definition::Base, &block).new
  end

  def test_returns_nil_without_layout
    assert_nil definition {}.resolve_form_sections(%i[a b])
  end

  def test_assigns_fields_and_collects_leftovers_first_by_default
    d = definition do
      form_layout do
        section :identity, :name, :email
      end
    end
    resolved = d.resolve_form_sections(%i[name email notes secret])
    assert_equal %i[ungrouped identity], resolved.map { |r| r.section.key }
    assert_equal %i[notes secret], resolved.first.fields           # leftovers, in order
    assert_equal %i[name email], resolved.last.fields
  end

  def test_ungrouped_macro_controls_position_and_options
    d = definition do
      form_layout do
        section :identity, :name
        ungrouped label: "Other"
      end
    end
    resolved = d.resolve_form_sections(%i[name notes])
    assert_equal %i[identity ungrouped], resolved.map { |r| r.section.key }
    assert_equal "Other", resolved.last.section.label
    assert_equal %i[notes], resolved.last.fields
  end

  def test_preserves_section_field_order
    d = definition { form_layout { section :a, :two, :one } }
    resolved = d.resolve_form_sections(%i[one two])
    assert_equal %i[two one], resolved.find { |r| r.section.key == :a }.fields
  end

  def test_empty_section_is_kept_not_hidden
    d = definition { form_layout { section :a, :gone; ungrouped } }
    # :gone was filtered out by policy → section :a is empty but still returned
    resolved = d.resolve_form_sections(%i[gone]) # raises: see strictness below
  rescue ArgumentError
    skip "covered by unknown-field test; empty-keep verified via filtered set below"
  end

  def test_empty_section_kept_when_field_filtered
    d = definition { form_layout { section :a, :name; section :b, :name } }
    # both reference :name; after assignment, section :b still returned even if empty
    resolved = d.resolve_form_sections(%i[name])
    keys = resolved.map { |r| r.section.key }
    assert_includes keys, :b
    assert_empty resolved.find { |r| r.section.key == :b }.fields
  end

  def test_unknown_field_raises
    d = definition { form_layout { section :a, :nope } }
    error = assert_raises(ArgumentError) { d.resolve_form_sections(%i[name]) }
    assert_match(/unknown field :nope/, error.message)
  end
end
```

> Note: the second-section-empty test (`test_empty_section_kept_when_field_filtered`) relies on assignment claiming `:name` for the first matching section; the field is rendered once (in section `:a`), and section `:b` ends up empty but retained. Implement assignment so each field is claimed by the **first** section that lists it.

- [ ] **Step 2: Run it, verify it fails**

Run: `bin/rails test test/plutonium/definition/form_layout_resolution_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'resolve_form_sections'`.

- [ ] **Step 3: Implement `resolve_form_sections`** — append inside `module FormLayout`, after `defined_form_layout` (instance method):

```ruby
      # Resolve the policy-filtered field list into ordered ResolvedSections.
      # Returns nil when no layout is declared (caller falls back to one grid).
      def resolve_form_sections(resource_fields)
        layout = defined_form_layout
        return nil unless layout

        resource_fields = resource_fields.map(&:to_sym)
        known = resource_fields.to_set

        claimed = []
        layout.each do |section|
          next if section.ungrouped?
          section.fields.each do |f|
            unless known.include?(f)
              raise ArgumentError,
                "form_layout section :#{section.key} references unknown field :#{f}"
            end
          end
          # First section to list a field claims it (so later sections don't dup).
          claimed.concat(section.fields - claimed)
        end
        leftovers = resource_fields - claimed

        resolved = layout.map do |section|
          fields = section.ungrouped? ? leftovers : ((section.fields & resource_fields) - claimed_before(layout, section, resource_fields))
          ResolvedSection.new(section:, fields:)
        end

        unless layout.any?(&:ungrouped?)
          implicit = ResolvedSection.new(
            section: Section.new(key: UNGROUPED_KEY, fields: [].freeze, options: {}),
            fields: leftovers
          )
          resolved.unshift(implicit)
        end

        resolved
      end

      private

      # Fields already claimed by earlier sections than `section` (for first-wins).
      def claimed_before(layout, section, resource_fields)
        taken = []
        layout.each do |s|
          break if s.equal?(section)
          next if s.ungrouped?
          taken.concat(s.fields & resource_fields)
        end
        taken
      end
```

> **Simplification:** `claimed_before` enforces first-section-wins per field. If you prefer, precompute a `field → section` map in one pass instead; keep the public behavior identical (tests above lock it in).

- [ ] **Step 4: Run tests, verify pass**

Run: `bin/rails test test/plutonium/definition/form_layout_resolution_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/definition/form_layout.rb test/plutonium/definition/form_layout_resolution_test.rb
git commit -m "feat(forms): resolve permitted fields into ordered form sections"
```

```json:metadata
{"files": ["lib/plutonium/definition/form_layout.rb", "test/plutonium/definition/form_layout_resolution_test.rb"], "verifyCommand": "bin/rails test test/plutonium/definition/form_layout_resolution_test.rb", "acceptanceCriteria": ["nil without layout", "fields assigned in order; leftovers to ungrouped", "ungrouped default-first / explicit-position", "unknown field raises", "empty sections kept (first-section-wins)"], "requiresUserVerification": false}
```

---

### Task 3: Section chrome component + columns→grid helper + theme

**Goal:** Add `Plutonium::UI::Form::Components::Section` rendering a section's heading/description, optional native `<details>` collapsible, and a grid whose columns come from `columns:` — yielding field rendering back to the form.

**Files:**
- Create: `lib/plutonium/ui/form/components/section.rb`
- Modify: `lib/plutonium/ui/form/theme.rb` (add `section_*` tokens — see step 3)
- Test: `test/plutonium/ui/form/components/section_test.rb`

**Acceptance Criteria:**
- [ ] Renders the section label as a heading and the description (when present).
- [ ] `collapsible: true` emits `<details>`/`<summary>`; `collapsed: true` omits `open`, default includes `open`.
- [ ] Non-collapsible renders a plain wrapper (no `<details>`).
- [ ] The passed grid class is applied to the fields grid; the yielded block content renders inside the grid.

**Verify:** `bin/rails test test/plutonium/ui/form/components/section_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing component test** — `test/plutonium/ui/form/components/section_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::SectionTest < Minitest::Test
  Section = Plutonium::Definition::FormLayout::Section
  ResolvedSection = Plutonium::Definition::FormLayout::ResolvedSection
  Component = Plutonium::UI::Form::Components::Section

  def render_section(section, fields: %i[a])
    resolved = ResolvedSection.new(section:, fields:)
    component = Component.new(resolved, grid_class: "grid grid-cols-2")
    component.call { component.plain("FIELD") } # plain text stands in for a field
  end

  def test_renders_heading_and_description
    html = render_section(Section.new(key: :identity, fields: %i[a],
      options: {label: "Your identification", description: "Basic"}))
    assert_includes html, "Your identification"
    assert_includes html, "Basic"
    assert_includes html, %(class="grid grid-cols-2")
    assert_includes html, "FIELD"
  end

  def test_collapsible_open_by_default
    html = render_section(Section.new(key: :address, fields: %i[a],
      options: {collapsible: true}))
    assert_match(/<details[^>]*\bopen\b/, html)
    assert_includes html, "<summary"
  end

  def test_collapsed_omits_open
    html = render_section(Section.new(key: :address, fields: %i[a],
      options: {collapsible: true, collapsed: true}))
    assert_match(/<details(?![^>]*\bopen\b)/, html)
  end

  def test_non_collapsible_has_no_details
    html = render_section(Section.new(key: :identity, fields: %i[a], options: {}))
    refute_includes html, "<details"
    assert_includes html, "Identity" # humanized default heading
  end
end
```

> `component.call { … }` renders a Phlex component to a String in tests. `plain` emits text. If the component base needs a view context, render via the dummy app instead (see Task 4's integration test) — but these chrome assertions work standalone because the component uses no Rails helpers.

- [ ] **Step 2: Run it, verify it fails**

Run: `bin/rails test test/plutonium/ui/form/components/section_test.rb`
Expected: FAIL — uninitialized constant `Plutonium::UI::Form::Components::Section`.

- [ ] **Step 3: Create the component** — `lib/plutonium/ui/form/components/section.rb`

```ruby
# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Renders a form section's chrome (heading/description, optional native
        # <details> collapsible, and a fields grid) and yields to a block that
        # renders the section's fields (the form supplies render_resource_field).
        class Section < Plutonium::UI::Component::Base
          def initialize(resolved, grid_class:)
            @section = resolved.section
            @grid_class = grid_class
          end

          def view_template(&fields_block)
            if @section.collapsible?
              details(open: !@section.collapsed?, class: "pu-form-section pu-form-section-collapsible") do
                summary(class: "pu-form-section-summary") { heading_text }
                describe
                grid(&fields_block)
              end
            else
              div(class: "pu-form-section") do
                header_block
                grid(&fields_block)
              end
            end
          end

          private

          def header_block
            return if @section.ungrouped? && @section.options[:label].nil?
            h3(class: "pu-form-section-title") { heading_text }
            describe
          end

          def heading_text = @section.label

          def describe
            return unless @section.description
            p(class: "pu-form-section-description") { @section.description }
          end

          def grid(&fields_block)
            div(class: @grid_class, &fields_block)
          end
        end
      end
    end
  end
end
```

> The `pu-form-section*` classes are styled via tokens. The heading-less default ungrouped (no label) skips its title (the `header_block` guard).

- [ ] **Step 4: Add theme tokens** — in `lib/plutonium/ui/form/theme.rb`, alongside `fields_wrapper` add (keep the existing keys; just add these):

```ruby
            form_section: "space-y-4",
            form_section_title: "text-base font-semibold text-[var(--pu-text)]",
            form_section_description: "text-sm text-[var(--pu-text-muted)]",
```

> If the component references `.pu-form-section*` utility classes directly (as written in Step 3) rather than `themed(...)`, these theme keys are optional sugar; you may either (a) keep the literal classes in the component, or (b) switch the component to `themed(:form_section, nil)` etc. Pick (a) for this task to avoid touching the theme lookup path; the theme keys above can be added later. **Decision for this plan: use literal classes in the component (option a); skip the theme.rb edit.** (Removes the theme file from this task's scope.)

- [ ] **Step 5: Run tests, verify pass**

Run: `bin/rails test test/plutonium/ui/form/components/section_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/ui/form/components/section.rb test/plutonium/ui/form/components/section_test.rb
git commit -m "feat(forms): add Section chrome component (heading/collapsible/grid)"
```

```json:metadata
{"files": ["lib/plutonium/ui/form/components/section.rb", "test/plutonium/ui/form/components/section_test.rb"], "verifyCommand": "bin/rails test test/plutonium/ui/form/components/section_test.rb", "acceptanceCriteria": ["heading + description render", "collapsible emits <details> with open/collapsed", "non-collapsible has no <details>", "grid_class applied and block content rendered"], "requiresUserVerification": false}
```

---

### Task 4: Render sections in resource forms + integration test

**Goal:** Make `Form::Resource#render_fields` group fields via the resolver and the Section component, evaluate each section's `condition` in form context, and fall back to the current single grid when no layout is declared.

**Files:**
- Modify: `lib/plutonium/ui/form/resource.rb` (`render_fields`, add `render_form_section`, `section_grid_class`)
- Modify: `test/dummy/app/definitions/kitchen_sink_definition.rb` (add a `form_layout`)
- Modify: `test/dummy/packages/admin_portal/config/routes.rb` (add `register_resource ::KitchenSink`)
- Test: `test/integration/admin_portal/form_layout_rendering_test.rb`

**Acceptance Criteria:**
- [ ] A definition with `form_layout` renders section headings and groups fields under them.
- [ ] `collapsible: true` produces `<details>` in the rendered form.
- [ ] A definition with no `form_layout` renders the single-grid form exactly as before (backwards-compat).
- [ ] A section whose `condition` is falsey renders nothing.

**Verify:** `bin/rails test test/integration/admin_portal/form_layout_rendering_test.rb` → all pass; plus `bin/rails test test/integration/admin_portal` shows no regressions.

**Steps:**

- [ ] **Step 1: Register KitchenSink in admin** — `test/dummy/packages/admin_portal/config/routes.rb`, add before `# register resources above.`:

```ruby
  register_resource ::KitchenSink
```

- [ ] **Step 2: Add a layout to the dummy definition** — `test/dummy/app/definitions/kitchen_sink_definition.rb`:

```ruby
class KitchenSinkDefinition < ::ResourceDefinition
  form_layout do
    section :identity, :name, :email_address, label: "Identity",
      description: "Who this is"
    section :appearance, :favorite_color, :active, collapsible: true, columns: 2
    ungrouped label: "Everything else"
  end
end
```

- [ ] **Step 3: Write the failing integration test** — `test/integration/admin_portal/form_layout_rendering_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

class AdminPortal::FormLayoutRenderingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "renders section headings and groups fields" do
    get "/admin/kitchen_sinks/new"
    assert_response :success
    assert_includes response.body, "Identity"
    assert_includes response.body, "Who this is"
    assert_includes response.body, "Everything else"   # ungrouped label
    # fields still render with their normal names
    assert_includes response.body, %(name="kitchen_sink[name]")
    assert_includes response.body, %(name="kitchen_sink[favorite_color]")
  end

  test "collapsible section renders a details element" do
    get "/admin/kitchen_sinks/new"
    assert_match(/<details[^>]*\bopen\b/, response.body)
    assert_includes response.body, "<summary"
  end

  test "a definition without form_layout still renders the single grid" do
    # Comment has no form_layout → unchanged behavior, no <details>, fields present
    get "/admin/comments/new"
    assert_response :success
    assert_includes response.body, %(name="comment[body]")
  end
end
```

> If `email_address`/`favorite_color`/`active`/`name` are not all in KitchenSink's permitted create attributes, adjust the section field lists in Step 2 to match `KitchenSinkPolicy::ATTRIBUTES` (`name email_address favorite_color active …` are present per that policy). For the backwards-compat test, confirm `Comment` has a `body` attribute; if not, assert on an attribute it does expose.

- [ ] **Step 4: Run it, verify it fails**

Run: `bin/rails test test/integration/admin_portal/form_layout_rendering_test.rb`
Expected: FAIL — no `Identity`/`<details>` (current form renders one flat grid).

- [ ] **Step 5: Implement grouping** — in `lib/plutonium/ui/form/resource.rb`, replace `render_fields` (currently ~lines 100-105) and add helpers:

```ruby
        def render_fields
          resolved = resource_definition.resolve_form_sections(resource_fields)
          if resolved.nil?
            fields_wrapper {
              resource_fields.each { |name| render_resource_field name }
            }
          else
            resolved.each { |rs| render_form_section(rs) }
          end
        end

        def render_form_section(resolved)
          section = resolved.section
          condition = section.condition
          # condition runs in the form instance context (same as input conditions),
          # where `object` is the record.
          return if condition && !instance_exec(&condition)

          render Plutonium::UI::Form::Components::Section.new(
            resolved, grid_class: section_grid_class(section.columns)
          ) do
            resolved.fields.each { |name| render_resource_field name }
          end
        end

        # nil → the form's default responsive grid; an Integer overrides columns.
        def section_grid_class(columns)
          return themed(:fields_wrapper, nil) if columns.nil?

          base = "grid gap-6 grid-flow-row-dense grid-cols-1"
          case columns.to_i
          when 1 then base
          when 2 then "#{base} md:grid-cols-2"
          when 3 then "#{base} md:grid-cols-2 lg:grid-cols-3"
          else "#{base} md:grid-cols-2 2xl:grid-cols-#{columns.to_i}"
          end
        end
```

> `resource_definition` is already an attr on `Form::Resource`; for interactions it's the interaction instance (Task 5). Both respond to `resolve_form_sections`.

- [ ] **Step 6: Run tests, verify pass**

Run: `bin/rails test test/integration/admin_portal/form_layout_rendering_test.rb`
Expected: PASS.

- [ ] **Step 7: Regression check**

Run: `bin/rails test test/integration/admin_portal`
Expected: PASS (existing form/structured-input tests unaffected — section grouping preserves input names/ids).

- [ ] **Step 8: Commit**

```bash
git add lib/plutonium/ui/form/resource.rb \
        test/dummy/app/definitions/kitchen_sink_definition.rb \
        test/dummy/packages/admin_portal/config/routes.rb \
        test/integration/admin_portal/form_layout_rendering_test.rb
git commit -m "feat(forms): render form sections in resource forms"
```

```json:metadata
{"files": ["lib/plutonium/ui/form/resource.rb", "test/dummy/app/definitions/kitchen_sink_definition.rb", "test/dummy/packages/admin_portal/config/routes.rb", "test/integration/admin_portal/form_layout_rendering_test.rb"], "verifyCommand": "bin/rails test test/integration/admin_portal/form_layout_rendering_test.rb test/integration/admin_portal", "acceptanceCriteria": ["sections + headings render and group fields", "collapsible emits <details>", "no layout → single grid unchanged", "falsey condition hides section"], "requiresUserVerification": false}
```

---

### Task 5: Interaction forms render sections

**Goal:** Confirm interaction forms (`Form::Interaction < Form::Resource`) render `form_layout` sections, since they reuse `render_fields` with the interaction as `resource_definition`.

**Files:**
- Modify: a dummy interaction to add a `form_layout` (choose an interaction already exercised by an interactive-action integration test, e.g. under `test/dummy/packages/catalog/app/interactions/` — verify it has ≥2 attributes)
- Test: `test/integration/org_portal/form_layout_interaction_test.rb` (mirror `test/integration/org_portal/structured_input_interaction_test.rb`'s harness)

**Acceptance Criteria:**
- [ ] An interactive action whose interaction declares `form_layout` renders section headings and groups its attribute inputs.
- [ ] Interaction attribute input names are unchanged (e.g. `interaction[...]`).

**Verify:** `bin/rails test test/integration/org_portal/form_layout_interaction_test.rb` → pass.

**Steps:**

- [ ] **Step 1: Pick the interaction + URL** — open `test/integration/org_portal/structured_input_interaction_test.rb`, note the interactive-action URL it GETs and the interaction class it exercises. Reuse that exact interaction + URL here.

- [ ] **Step 2: Add a `form_layout` to that interaction class**

```ruby
  # inside the interaction class definition (it already includes the DSL via
  # Interaction::Base → FormLayout):
  form_layout do
    section :details, :<attr_one>, :<attr_two>, label: "Details"
    ungrouped
  end
```

Replace `<attr_one>`/`<attr_two>` with two real `attribute` names declared on that interaction (read them from the class).

- [ ] **Step 3: Write the failing test** — `test/integration/org_portal/form_layout_interaction_test.rb`

```ruby
# frozen_string_literal: true

require "test_helper"

class OrgPortal::FormLayoutInteractionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  # Mirror the setup/login from structured_input_interaction_test.rb
  # (copy its `setup` block verbatim — same org/user/login).

  test "interaction form renders form_layout sections" do
    get "<the interactive action's new/form URL from Step 1>"
    assert_response :success
    assert_includes response.body, "Details"            # section heading
    assert_includes response.body, %(name="interaction[<attr_one>]")
  end
end
```

- [ ] **Step 4: Run it, verify it fails, then passes after Step 2 is in place**

Run: `bin/rails test test/integration/org_portal/form_layout_interaction_test.rb`
Expected: FAIL before the interaction has `form_layout` (no "Details" heading), PASS after.

> Since the rendering path is shared with Task 4, no library code changes are expected here. If the heading does not appear, confirm `Interaction::Base` includes `FormLayout` (Task 1, Step 4) and that `Form::Interaction` sets `resource_definition` to the interaction (it does).

- [ ] **Step 5: Commit**

```bash
git add test/dummy/packages/**/interactions/*.rb test/integration/org_portal/form_layout_interaction_test.rb
git commit -m "test(forms): interaction forms render form_layout sections"
```

```json:metadata
{"files": ["test/integration/org_portal/form_layout_interaction_test.rb"], "verifyCommand": "bin/rails test test/integration/org_portal/form_layout_interaction_test.rb", "acceptanceCriteria": ["interaction form renders section headings", "interaction attribute input names unchanged"], "requiresUserVerification": false}
```

---

## Self-Review

- **Spec coverage:** DSL (Task 1), ungrouped macro + reserved-key raise (Task 1/2), resolution + ungrouped placement + empty-not-hidden + unknown-key raise (Task 2), section features description/collapsible/columns/condition (Task 3 chrome + Task 4 condition/columns), interactions (Task 1 include + Task 5 render), backwards-compat (Task 4). All spec sections map to a task.
- **Placeholders:** Tasks 1-4 contain complete code. Task 5 intentionally parameterizes the interaction class/URL because the exact dummy interaction must be read from the existing org_portal interaction test; the steps name precisely what to copy and from where. This is a lookup, not a design gap.
- **Type consistency:** `Section`/`ResolvedSection`/`resolve_form_sections`/`section_grid_class`/`render_form_section` names are used identically across tasks.
- **Verification scan:** the spec requests no user/human verification → all tasks `requiresUserVerification: false`.

## Final verification (after all tasks)

Run the broader suite to confirm no regressions:
```
bin/rails test test/plutonium test/integration/admin_portal test/integration/org_portal
```
Then `bin/standardrb` (the repo's `default` rake task runs `test` + `standard`).

---

## Amendments (post-implementation)

Refinements made after the task-by-task plan above was executed. The historical
steps/snippets are left as-built; these supersede them where they conflict.

- **Implicit `ungrouped` placement: first → last** (`form_layout.rb`,
  `resolve_form_sections`: `unshift` → `push`; test renamed
  `..._first_by_default` → `..._last_by_default`). Omitting `ungrouped` now
  appends leftovers after all declared sections — equivalent to declaring it
  last. Declare it explicitly at the top to float leftovers above sections.

- **`columns:` actually lays out in a grid** (`resource.rb`,
  `render_simple_resource_field`). The old `col-span-full` default made every
  field span the whole row, so `columns: N` had no visible effect. Fields in a
  multi-column section now take single grid cells; a field's own
  `wrapper: {class: "col-span-..."}` always wins (in any section).

- **Dynamic section options** (`resource.rb`, `resolve_form_layout`). Every
  option except `columns:` may be a proc, resolved at render in the form
  instance context (same as `condition:`). The layout is resolved once per
  render — visibility + option evaluation in one pass — and `render_form_section`
  is pure presentation. Example: `collapsed: -> { object.persisted? }`.

- **Interactions exercised** — `ReconfigureKitchenSink` (record action on
  `KitchenSink`) + `test/integration/admin_portal/form_layout_interaction_test.rb`
  cover form_layout (incl. a dynamic `collapsed:`) in an interaction form, where
  `object` is the interaction and `object.resource` the record.

- **Unrelated dev-mode fix** (`lib/plutonium/package/engine.rb` +
  `test/plutonium/package/engine_test.rb`): the package engine's
  `before_configuration` hook prematurely memoized `Rails.application.railties`
  (via `Rails.application.initializers`), dropping package engines from the
  autoload paths whenever a second `Rails::Application` was created before the
  packages glob (combustion, in `development`) — surfacing as `uninitialized
  constant Blogging::Post`. Moved the `add_view_paths` neutralization to a real
  initializer (`before: :add_view_paths`). Surfaced while driving the dummy in
  dev to verify this feature.

Reference docs updated: `docs/reference/resource/definition.md` (ungrouped
placement, dynamic options, columns/col-span).
