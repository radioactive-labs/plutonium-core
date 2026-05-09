# frozen_string_literal: true

require "test_helper"
require "ostruct"

# Ensure ResourceSelect is loaded so it registers itself in Searchable.registry
Plutonium::UI::Form::Components::ResourceSelect

class Plutonium::Resource::Controllers::TypeaheadTest < Minitest::Test
  # Build a tiny class that includes only what `render_typeahead_response`
  # touches: rendering, lookup_typeahead_input_class. We bypass
  # before_action by calling the methods directly.
  def build_controller(input_def: nil, filter_def: nil)
    controller = Class.new do
      attr_accessor :rendered, :head_status

      # Stub Rails class-level callbacks so the concern's `included` block
      # doesn't blow up when included into a plain Ruby class outside of
      # Rails (no AbstractController inheritance, no Authorizable mixin).
      def self.before_action(*) = nil
      def self.skip_verify_current_authorized_scope(*) = nil

      include Plutonium::Resource::Controllers::Typeahead
      # Stub Rails plumbing.
      def render(opts) = (@rendered = opts)
      def head(status) = (@head_status = status)
      def params = @params ||= {}
      attr_writer :params

      def current_definition = @current_definition
      attr_writer :current_definition

      def current_query_object = @current_query_object
      attr_writer :current_query_object

      # called from the Searchable widget via send(:authorized_resource_scope, ...)
      def authorized_resource_scope(klass, **) = klass.all
    end.new

    if input_def
      defn = OpenStruct.new(defined_inputs: {input_def[:name] => input_def[:value]})
      controller.current_definition = defn
    end

    if filter_def
      filter_holder = OpenStruct.new(defined_inputs: {value: filter_def[:value]})
      qo = OpenStruct.new(filter_definitions: {filter_def[:name] => filter_holder})
      controller.current_query_object = qo
    end

    controller
  end

  def test_typeahead_input_returns_404_for_unknown_name
    controller = build_controller(input_def: {name: :existing, value: nil})
    controller.params = {name: "missing"}
    controller.typeahead_input
    assert_equal :not_found, controller.head_status
  end

  def test_typeahead_filter_returns_404_for_unknown_filter
    controller = build_controller(filter_def: {name: :existing, value: nil})
    controller.params = {name: "missing"}
    controller.typeahead_filter
    assert_equal :not_found, controller.head_status
  end

  def test_typeahead_input_returns_400_for_non_searchable_input
    # Input definition with :as => :unknown_kind that isn't in Searchable.registry
    controller = build_controller(input_def: {name: :foo, value: {options: {as: :unknown_kind}}})
    controller.params = {name: "foo"}
    controller.typeahead_input
    assert_equal :bad_request, controller.rendered[:status]
    assert_equal({error: "input is not typeahead-capable"}, controller.rendered[:json])
  end

  def test_typeahead_input_renders_json_envelope_for_searchable_input
    # Use ResourceSelect (already registered in registry as :resource_select)
    # with static choices so we don't need DB.
    controller = build_controller(
      input_def: {
        name: :foo,
        value: {options: {as: :resource_select, choices: [["Alice", "1"], ["Bob", "2"]]}}
      }
    )
    controller.params = {name: "foo", q: "ali"}
    controller.typeahead_input

    body = controller.rendered[:json]
    refute_nil body
    assert_equal [{value: "1", label: "Alice"}], body[:results]
    refute body[:has_more]
  end
end
