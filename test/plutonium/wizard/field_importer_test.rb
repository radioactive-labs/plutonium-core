# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    # `using:` targets a MODEL only (§2.4). The field universe + types come from
    # the model; `<Model>Definition` is auto-resolved (model→definition, the only
    # reliable direction) to overlay input styling and form_layout.
    #
    # Real dummy models exercised here:
    #   - KitchenSink — real columns (name/age/active/email_address/website/...),
    #     `validates :name, presence: true`, a required `belongs_to :organization`,
    #     and a KitchenSinkDefinition with form_layout + input customizations
    #     (email_address as :email, website as :url).
    class FieldImporterTest < ActiveSupport::TestCase
      def resolve(using, **opts)
        Plutonium::Wizard::FieldImporter.resolve(using:, opts:)
      end

      # ---- types + field universe from the model -----------------------------

      def test_types_from_model_attribute_types
        spec = resolve(KitchenSink, fields: %i[name age active])
        assert_equal({name: :string, age: :integer, active: :boolean}, spec.attribute_schema)
      end

      def test_enum_columns_import_as_string_not_integer
        # status/plan/tier are integer-backed AR enums. Forms submit the string key
        # ("a"), so importing the raw :integer column type would cast it to 0. They
        # must import as :string so the enum key round-trips through wizard `data`.
        spec = resolve(KitchenSink, fields: %i[status plan tier])
        assert_equal({status: :string, plan: :string, tier: :string}, spec.attribute_schema)
      end

      def test_field_universe_is_model_attribute_names
        # `price` is a has_cents virtual accessor, NOT a real column, so it is not
        # in the importable universe even if requested.
        spec = resolve(KitchenSink, fields: %i[name price])
        assert_equal %i[name], spec.attribute_schema.keys
      end

      def test_only_and_fields_are_aliases
        a = resolve(KitchenSink, only: %i[name])
        b = resolve(KitchenSink, fields: %i[name])
        assert_equal a.attribute_schema, b.attribute_schema
      end

      def test_except_selector
        spec = resolve(KitchenSink, fields: %i[name age], except: %i[age])
        assert_equal %i[name], spec.attribute_schema.keys
      end

      # ---- input overlay from the resolved <Model>Definition ------------------

      def test_input_overlay_from_definition
        spec = resolve(KitchenSink, fields: %i[email_address website])
        assert_equal :email, spec.inputs[:email_address][:options][:as]
        assert_equal :url, spec.inputs[:website][:options][:as]
      end

      def test_input_overlay_empty_when_no_definition
        # AnonymousKitchen has no AnonymousKitchenDefinition → model-derived inputs
        # only (empty styling).
        spec = resolve(model_without_definition, fields: %i[name])
        assert_equal({}, spec.inputs[:name])
      end

      # ---- validation: transient model, filtered to imported + :base ----------

      def test_validation_runs_and_keeps_imported_field_errors
        spec = resolve(KitchenSink, fields: %i[name])
        errors = spec.validate({"name" => ""})
        assert errors.key?(:name), "imported presence error should surface"
      end

      def test_validation_drops_required_but_unimported_fields
        # organization is a required belongs_to NOT imported here; its presence
        # error must be filtered out so it never blocks the step.
        spec = resolve(KitchenSink, fields: %i[name])
        errors = spec.validate({"name" => "Acme"})
        refute errors.key?(:organization), "non-imported required belongs_to must be dropped"
        assert_empty errors
      end

      def test_validation_keeps_base_errors
        spec = resolve(model_with_base_rule, fields: %i[name])
        errors = spec.validate({"name" => "x"})
        assert errors.key?(:base), ":base errors must be kept"
      end

      def test_validate_false_skips_validation
        spec = resolve(KitchenSink, fields: %i[name], validate: false)
        assert_nil spec.validate_fn
        assert_empty spec.validate({"name" => ""})
      end

      def test_validation_context_passed_through
        model = model_with_context_rule
        # No errors without the context (rule is on: :strict).
        assert_empty resolve(model, fields: %i[description]).validate({"description" => ""})

        ctx_spec = resolve(model, fields: %i[description], validation_context: :strict)
        assert ctx_spec.validate({"description" => ""}).key?(:description)
      end

      # ---- form_layout inheritance + leftover handling ------------------------

      def test_form_layout_inherited_and_filtered
        spec = resolve(KitchenSink, fields: %i[name email_address])
        identity = spec.form_layout.find { |rs| rs.section.key == :identity }
        refute_nil identity
        assert_equal %i[name email_address], identity.fields
      end

      def test_form_layout_drops_sections_with_zero_imported_fields
        # The :appearance section lists favorite_color/active/website — none imported.
        spec = resolve(KitchenSink, fields: %i[name])
        keys = spec.form_layout.map { |rs| rs.section.key }
        refute_includes keys, :appearance
      end

      def test_form_layout_leftover_imported_fields_land_in_ungrouped
        # `age` is imported but named in NO explicit section → it must still appear,
        # in the ungrouped section (KitchenSinkDefinition declares an explicit one).
        spec = resolve(KitchenSink, fields: %i[name age])
        ungrouped = spec.form_layout.find { |rs| rs.section.ungrouped? }
        refute_nil ungrouped, "an ungrouped section must hold leftover imported fields"
        assert_includes ungrouped.fields, :age
        # And no imported field disappears across all sections.
        all = spec.form_layout.flat_map(&:fields)
        assert_includes all, :name
        assert_includes all, :age
      end

      def test_form_layout_synthesizes_ungrouped_when_definition_has_none
        # A definition whose form_layout sections only SOME imported fields and has
        # no explicit ungrouped → a trailing ungrouped is synthesized for leftovers.
        model = model_with_partial_layout
        spec = resolve(model, fields: %i[name email_address description])
        # :main sections name/email_address; description is the leftover.
        ungrouped = spec.form_layout.find { |rs| rs.section.ungrouped? }
        refute_nil ungrouped, "leftover imported field needs a synthesized ungrouped section"
        assert_equal %i[description], ungrouped.fields
      end

      def test_layout_false_skips_form_layout
        spec = resolve(KitchenSink, fields: %i[name], layout: false)
        assert_nil spec.form_layout
      end

      def test_no_form_layout_when_definition_has_none
        spec = resolve(model_without_definition, fields: %i[title])
        assert_nil spec.form_layout
      end

      # ---- non-model rejection ------------------------------------------------

      def test_plain_class_raises
        plain = Class.new
        err = assert_raises(ArgumentError) { resolve(plain, fields: %i[x]) }
        assert_match(/model class/, err.message)
      end

      def test_interaction_raises
        interaction = Class.new(Plutonium::Interaction::Base) do
          attribute :x, :string

          private

          def execute = succeed(true)
        end
        err = assert_raises(ArgumentError) { resolve(interaction, fields: %i[x]) }
        assert_match(/model class/, err.message)
      end

      def test_non_class_raises
        assert_raises(ArgumentError) { resolve(:not_a_class, fields: %i[x]) }
      end

      # ---- composition: using: wired into a step (FieldCapture) ---------------

      class ImportThenInline < Plutonium::Wizard::Base
        step :company, using: KitchenSink, fields: %i[name age] do
          attribute :preferred_time, :string
          input :preferred_time
          validates :preferred_time, presence: true
        end

        def execute = succeed(true)
      end

      def test_step_composes_imported_with_inline_attributes
        step = ImportThenInline.steps.first
        assert_equal({name: :string, age: :integer, preferred_time: :string},
          step.attribute_schema)
      end

      def test_step_data_includes_imported_attributes
        w = ImportThenInline.new
        w.data_attributes = {"company" => {"name" => "Acme", "age" => "7", "preferred_time" => "noon"}}
        assert_equal "Acme", w.data.company.name
        assert_equal 7, w.data.company.age
        assert_equal "noon", w.data.company.preferred_time
      end

      def test_step_composes_imported_with_inline_inputs
        step = ImportThenInline.steps.first
        assert_equal %i[name age preferred_time].sort, step.inputs.keys.sort
      end

      def test_step_exposes_imported_validate_fn
        step = ImportThenInline.steps.first
        errors = step.imported_validate_fn.call({"name" => ""})
        assert errors.key?(:name)
      end

      class InlineOverridesImport < Plutonium::Wizard::Base
        # `age` imported as :integer from the model, but redeclared inline as
        # :string — inline must win on the conflict (§2.4).
        step :c, using: KitchenSink, fields: %i[age] do
          attribute :age, :string
        end

        def execute = succeed(true)
      end

      def test_inline_wins_on_attribute_conflict
        assert_equal :string, InlineOverridesImport.steps.first.attribute_schema[:age]
      end

      class WholeStepImport < Plutonium::Wizard::Base
        # using: supplies everything; no block needed. form_layout inherited.
        step :company, using: KitchenSink, fields: %i[name email_address]

        def execute = succeed(true)
      end

      def test_whole_step_import_inherits_form_layout
        step = WholeStepImport.steps.first
        refute_nil step.form_layout
        assert_includes step.form_layout.map { |rs| rs.section.key }, :identity
      end

      class InlineLayoutOverridesImport < Plutonium::Wizard::Base
        step :company, using: KitchenSink, fields: %i[name email_address] do
          form_layout do
            section :mine, :name, :email_address, label: "Mine"
          end
        end

        def execute = succeed(true)
      end

      def test_inline_form_layout_overrides_inherited
        step = InlineLayoutOverridesImport.steps.first
        assert_equal %i[mine], step.form_layout.map(&:key)
      end

      private

      # --- throwaway models built for a single behavior, with no need for a table.
      # ActiveModel-style validations run against a transient instance; these never
      # touch the DB (validation is run-and-filtered, never saved).

      def model_without_definition
        Class.new(ApplicationRecord) do
          self.table_name = "kitchen_sinks"
          def self.name = "AnonymousKitchen"
        end
      end

      def model_with_base_rule
        Class.new(ApplicationRecord) do
          self.table_name = "kitchen_sinks"
          def self.name = "BaseRuleKitchen"
          validate { errors.add(:base, "always wrong") }
        end
      end

      def model_with_context_rule
        Class.new(ApplicationRecord) do
          self.table_name = "kitchen_sinks"
          def self.name = "ContextKitchen"
          validates :description, presence: true, on: :strict
        end
      end

      def model_with_partial_layout
        model = Class.new(ApplicationRecord) do
          self.table_name = "kitchen_sinks"
          def self.name = "PartialLayoutKitchen"
        end
        # The resolved <Model>Definition supplies the form_layout: real columns
        # name/email_address are sectioned; description is the leftover.
        defn = Class.new(Plutonium::Resource::Definition) do
          form_layout do
            section :main, :name, :email_address, label: "Main"
          end
        end
        stub_const("PartialLayoutKitchenDefinition", defn)
        model
      end

      # Define a top-level constant for the duration of the test so
      # `"#{Model}Definition".safe_constantize` resolves it, then remove it.
      def stub_const(name, value)
        Object.const_set(name, value)
        @stubbed_consts ||= []
        @stubbed_consts << name
      end

      def teardown
        Array(@stubbed_consts).each { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
      end
    end
  end
end
