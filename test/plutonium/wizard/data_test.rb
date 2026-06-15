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
          "invites" => [
            {"email" => "a@x.com", "role" => "admin"},
            {"email" => "b@x.com", "role" => "member"}
          ],
          "note" => "hi"
        }

        invites = w.data.invites
        assert_kind_of Array, invites
        assert_equal 2, invites.size
        assert_equal "a@x.com", invites.first.email
        assert_equal "admin", invites.first.role
        assert_equal "b@x.com", invites.last.email
        assert_equal "hi", w.data.note
      end

      def test_structured_array_empty_when_uncollected
        w = WithStructured.new
        assert_equal [], w.data.invites
      end

      def test_structured_array_handles_indifferent_access
        w = WithStructured.new
        w.data_attributes = {"invites" => [{email: "c@x.com", role: "admin"}]}
        assert_equal "c@x.com", w.data.invites.first.email
      end
    end
  end
end
