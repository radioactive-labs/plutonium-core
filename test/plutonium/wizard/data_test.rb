# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    class DataTest < Minitest::Test
      def build(schema, attrs = {})
        Plutonium::Wizard::Data.class_for(schema).new(attrs)
      end

      def test_casts_to_declared_types
        data = build({count: :integer, active: :boolean, name: :string},
          {"count" => "7", "active" => "true", "name" => "Acme"})

        assert_equal 7, data.count
        assert_equal true, data.active
        assert_equal "Acme", data.name
      end

      def test_uncollected_fields_are_nil
        data = build({count: :integer, name: :string}, {"name" => "Acme"})

        assert_nil data.count
        assert_equal "Acme", data.name
      end

      def test_accepts_symbol_keys
        data = build({name: :string}, {name: "Sym"})
        assert_equal "Sym", data.name
      end

      def test_empty_schema
        data = build({}, {})
        assert_respond_to data, :attributes
        assert_empty data.attributes
      end

      def test_inline_attribute_default_applies_when_unset
        klass = Plutonium::Wizard::Data.class_for(
          {foo: :string},
          options: {foo: {default: "bar"}}
        )

        assert_equal "bar", klass.new({}).foo
        assert_equal "set", klass.new({"foo" => "set"}).foo
      end

      # The form pipeline infers a field's required marker from
      # `object.class.validators_on(key)`, so the step's inline `validates` must be
      # replayed onto the typed data class — otherwise required fields render
      # without the asterisk.
      def test_inline_validations_are_replayed_onto_the_data_class
        klass = Plutonium::Wizard::Data.class_for(
          {name: :string, note: :string},
          validations: [[[:name], {presence: true}]]
        )

        assert klass.validators_on(:name).any? { |v| v.kind == :presence }
        assert_empty klass.validators_on(:note)
      end

      class WithRequired < Plutonium::Wizard::Base
        step :identity do
          attribute :name, :string
          attribute :plan, :string
          input :name
          input :plan
          validates :name, presence: true
        end

        def execute = succeed
      end

      def test_step_presence_validation_threads_into_data_snapshot
        identity = WithRequired.new.data.identity

        assert identity.class.validators_on(:name).any? { |v| v.kind == :presence },
          "expected the step's presence validator on the typed data class"
        assert_empty identity.class.validators_on(:plan)
      end

      # A `using:` import must also surface the source model's form-relevant
      # validators onto the data class, so imported required fields render the
      # marker just like inline ones. KitchenSink validates :name presence.
      class WithImport < Plutonium::Wizard::Base
        step :acct, using: KitchenSink, fields: %i[name description]
        def execute = succeed
      end

      def test_imported_model_validations_thread_into_data_snapshot
        acct = WithImport.new.data.acct

        assert acct.class.validators_on(:name).any? { |v| v.kind == :presence },
          "expected the imported model's presence validator on the typed data class"
        assert_empty acct.class.validators_on(:description)
      end

      # The runner validates imported fields via the importer's transient model
      # (imported_validate_fn), so imported validators must NOT also leak into
      # `step.validations` — that would double-validate the field.
      def test_imported_validations_do_not_pollute_the_runner_validations
        assert_empty WithImport.steps.first.validations
      end

      class WithDefault < Plutonium::Wizard::Base
        step :details do
          attribute :foo, :string, default: "bar"
          input :foo
        end

        def execute = succeed
      end

      def test_step_inline_default_threads_into_data_snapshot
        assert_equal "bar", WithDefault.new.data.details.foo

        w = WithDefault.new
        w.data_attributes = {"details" => {"foo" => "given"}}
        assert_equal "given", w.data.details.foo
      end

      class WithStructured < Plutonium::Wizard::Base
        step :team do
          structured_input :invites, repeat: 5 do |f|
            f.input :email
            f.input :role
          end
        end

        step :details do
          attribute :note, :string
          input :note
        end

        def execute = succeed
      end

      def test_structured_array_yields_typed_sub_objects
        w = WithStructured.new
        w.data_attributes = {
          "team" => {
            "invites" => [
              {"email" => "a@x.com", "role" => "admin"},
              {"email" => "b@x.com", "role" => "member"}
            ]
          },
          "details" => {"note" => "hi"}
        }

        invites = w.data.team.invites
        assert_kind_of Array, invites
        assert_equal 2, invites.size
        assert_equal "a@x.com", invites.first.email
        assert_equal "admin", invites.first.role
        assert_equal "b@x.com", invites.last.email
        assert_equal "hi", w.data.details.note
      end

      def test_structured_array_empty_when_uncollected
        w = WithStructured.new
        assert_equal [], w.data.team.invites
      end

      def test_structured_array_handles_indifferent_access
        w = WithStructured.new
        w.data_attributes = {"team" => {"invites" => [{email: "c@x.com", role: "admin"}]}}
        assert_equal "c@x.com", w.data.team.invites.first.email
      end

      # --- container (step-keyed dispatch) ------------------------------------

      def test_container_dispatches_to_step_sub_objects
        w = WithStructured.new
        w.data_attributes = {"details" => {"note" => "hi"}}

        assert_respond_to w.data, :team
        assert_respond_to w.data, :details
        assert_equal %i[team details], w.data.step_keys
        assert_equal "hi", w.data[:details].note   # dynamic [] access
        assert_nil w.data[:nope]                    # unknown step → nil
      end

      def test_container_to_h_is_nested_and_typed
        w = WithDefault.new
        w.data_attributes = {"details" => {"foo" => "given"}}
        assert_equal({details: {foo: "given"}}, w.data.to_h)
      end
    end
  end
end
