# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    class FieldImporterTest < ActiveSupport::TestCase
      # --- interaction target -------------------------------------------------

      class ContactInteraction < Plutonium::Interaction::Base
        attribute :phone, :string
        attribute :email, :string
        attribute :age, :integer
        input :phone, as: :phone
        input :email, as: :email
        input :age, as: :integer
        validates :email, presence: true
        validates :phone, presence: true

        form_layout do
          section :reach, :email, :phone, label: "How to reach you"
          section :other, :age, label: "Other"
        end

        private

        def execute = succeed(true)
      end

      def resolve(using, **opts)
        Plutonium::Wizard::FieldImporter.resolve(using:, opts:)
      end

      # ---- types + selectors ----

      def test_interaction_import_types_from_attribute_declarations
        spec = resolve(ContactInteraction, only: %i[email age])
        assert_equal({email: :string, age: :integer}, spec.attribute_schema)
      end

      def test_only_and_fields_are_aliases
        a = resolve(ContactInteraction, only: %i[email])
        b = resolve(ContactInteraction, fields: %i[email])
        assert_equal a.attribute_schema, b.attribute_schema
      end

      def test_except_selector
        spec = resolve(ContactInteraction, except: %i[age])
        assert_equal %i[phone email], spec.attribute_schema.keys
      end

      def test_imports_input_config
        spec = resolve(ContactInteraction, only: %i[email phone])
        assert_equal %i[email phone].sort, spec.inputs.keys.sort
        assert_equal :email, spec.inputs[:email][:options][:as]
        assert_equal :phone, spec.inputs[:phone][:options][:as]
      end

      # ---- validation run-and-filter ----

      def test_validation_runs_and_keeps_imported_field_errors
        spec = resolve(ContactInteraction, only: %i[email])
        errors = spec.validate({"email" => ""})
        assert errors.key?(:email), "imported field error should surface"
      end

      def test_validation_drops_errors_on_non_imported_fields
        # phone is required on the interaction but NOT imported here; its presence
        # error must be filtered out so it never blocks the step.
        spec = resolve(ContactInteraction, only: %i[email])
        errors = spec.validate({"email" => "x@y.com"})
        refute errors.key?(:phone), "non-imported field error must be dropped"
        assert_empty errors
      end

      def test_validation_keeps_base_errors
        spec = resolve(BaseRuleInteraction, only: %i[a])
        errors = spec.validate({"a" => "1", "b" => "2"})
        assert errors.key?(:base), ":base errors must be kept"
      end

      class BaseRuleInteraction < Plutonium::Interaction::Base
        attribute :a, :string
        attribute :b, :string
        validate { errors.add(:base, "always wrong") }

        private

        def execute = succeed(true)
      end

      def test_validate_false_skips_validation
        spec = resolve(ContactInteraction, only: %i[email], validate: false)
        assert_empty spec.validate({"email" => ""})
      end

      def test_validation_context_passed_through
        spec = resolve(ContextInteraction, only: %i[name])
        # No errors without the context (the rule is on: :strict).
        assert_empty spec.validate({"name" => ""})

        ctx_spec = resolve(ContextInteraction, only: %i[name], validation_context: :strict)
        assert ctx_spec.validate({"name" => ""}).key?(:name)
      end

      class ContextInteraction < Plutonium::Interaction::Base
        attribute :name, :string
        validates :name, presence: true, on: :strict

        private

        def execute = succeed(true)
      end

      # ---- form_layout inheritance ----

      def test_form_layout_inherited_filtered_to_imported_fields
        spec = resolve(ContactInteraction, only: %i[email phone])
        refute_nil spec.form_layout
        # The :other section (age) resolves to zero imported fields → dropped.
        keys = spec.form_layout.map { |rs| rs.section.key }
        assert_includes keys, :reach
        refute_includes keys, :other
        reach = spec.form_layout.find { |rs| rs.section.key == :reach }
        assert_equal %i[email phone], reach.fields
      end

      def test_layout_false_skips_form_layout
        spec = resolve(ContactInteraction, only: %i[email], layout: false)
        assert_nil spec.form_layout
      end

      def test_no_form_layout_when_source_has_none
        spec = resolve(BaseRuleInteraction, only: %i[a])
        assert_nil spec.form_layout
      end

      # --- resource-definition target ----------------------------------------

      def test_definition_import_types_from_record_class
        spec = resolve(KitchenSinkDefinition, fields: %i[name age active])
        assert_equal({name: :string, age: :integer, active: :boolean}, spec.attribute_schema)
      end

      def test_definition_import_overlays_definition_input_config
        spec = resolve(KitchenSinkDefinition, fields: %i[email_address website])
        assert_equal :email, spec.inputs[:email_address][:options][:as]
        assert_equal :url, spec.inputs[:website][:options][:as]
      end

      def test_definition_validation_via_transient_model
        # KitchenSink validates :name, presence: true. Importing only :name,
        # the presence error surfaces; organization (a required belongs_to NOT
        # imported) must be dropped.
        spec = resolve(KitchenSinkDefinition, fields: %i[name])
        errors = spec.validate({"name" => ""})
        assert errors.key?(:name)
        refute errors.key?(:organization), "non-imported required belongs_to must be filtered out"
      end

      def test_definition_form_layout_inherited_and_filtered
        spec = resolve(KitchenSinkDefinition, fields: %i[name email_address])
        keys = spec.form_layout.map { |rs| rs.section.key }
        assert_includes keys, :identity
        identity = spec.form_layout.find { |rs| rs.section.key == :identity }
        assert_equal %i[name email_address], identity.fields
      end

      # --- composition: using: wired into a step (FieldCapture) -----------------

      class ImportThenInline < Plutonium::Wizard::Base
        step :contact, using: ContactInteraction, only: %i[phone email] do
          attribute :preferred_time, :string
          input :preferred_time
          validates :preferred_time, presence: true
        end

        def execute = succeed(true)
      end

      def test_step_composes_imported_with_inline_attributes
        step = ImportThenInline.steps.first
        # imported phone/email (typed from the interaction) + inline preferred_time
        assert_equal({phone: :string, email: :string, preferred_time: :string},
          step.attribute_schema)
      end

      def test_step_union_data_includes_imported_attributes
        w = ImportThenInline.new
        w.data_attributes = {"phone" => "555", "email" => "a@b.com", "preferred_time" => "noon"}
        assert_equal "555", w.data.phone
        assert_equal "a@b.com", w.data.email
        assert_equal "noon", w.data.preferred_time
      end

      def test_step_composes_imported_with_inline_inputs
        step = ImportThenInline.steps.first
        assert_equal %i[phone email preferred_time].sort, step.inputs.keys.sort
        assert_equal :phone, step.inputs[:phone][:options][:as]
      end

      def test_step_exposes_imported_validate_fn
        step = ImportThenInline.steps.first
        errors = step.imported_validate_fn.call({"email" => "", "phone" => ""})
        assert errors.key?(:email)
        assert errors.key?(:phone)
      end

      class InlineOverridesImport < Plutonium::Wizard::Base
        # `email` imported as :string from the interaction, but redeclared inline
        # as :integer — inline must win on the conflict (§2.4).
        step :c, using: ContactInteraction, only: %i[email] do
          attribute :email, :integer
        end

        def execute = succeed(true)
      end

      def test_inline_wins_on_attribute_conflict
        assert_equal :integer, InlineOverridesImport.steps.first.attribute_schema[:email]
      end

      class WholeStepImport < Plutonium::Wizard::Base
        # using: supplies everything; no block needed. form_layout inherited.
        step :contact, using: ContactInteraction, only: %i[email phone]

        def execute = succeed(true)
      end

      def test_whole_step_import_inherits_form_layout
        step = WholeStepImport.steps.first
        refute_nil step.form_layout
        assert_equal %i[reach], step.form_layout.map { |rs| rs.section.key }
      end

      class InlineLayoutOverridesImport < Plutonium::Wizard::Base
        step :contact, using: ContactInteraction, only: %i[email phone] do
          form_layout do
            section :mine, :email, :phone, label: "Mine"
          end
        end

        def execute = succeed(true)
      end

      def test_inline_form_layout_overrides_inherited
        step = InlineLayoutOverridesImport.steps.first
        assert_equal %i[mine], step.form_layout.map(&:key)
      end

      # --- regression (review note M4): structured_input using:/fields: sub-paths -

      class StructuredFieldsList < Plutonium::Definition::StructuredInputs::FieldsDefinition
        input :email
        input :role
      end

      class StructuredUsingWizard < Plutonium::Wizard::Base
        step :team do
          structured_input :invites, repeat: 3, using: StructuredFieldsList
        end

        def execute = succeed(true)
      end

      class StructuredExplicitFields < Plutonium::Wizard::Base
        step :team do
          structured_input :members, repeat: 2, fields: %i[name title]
        end

        def execute = succeed(true)
      end

      def test_structured_input_using_resolves_sub_fields
        w = StructuredUsingWizard.new
        w.data_attributes = {"invites" => [{"email" => "a@x.com", "role" => "admin"}]}
        invite = w.data.invites.first
        assert_equal "a@x.com", invite.email
        assert_equal "admin", invite.role
      end

      def test_structured_input_explicit_fields_resolves_sub_fields
        w = StructuredExplicitFields.new
        w.data_attributes = {"members" => [{"name" => "Ada", "title" => "Eng"}]}
        member = w.data.members.first
        assert_equal "Ada", member.name
        assert_equal "Eng", member.title
      end
    end
  end
end
