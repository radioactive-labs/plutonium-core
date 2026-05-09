# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Plutonium::Resource::Controllers::TypeaheadTest < Minitest::Test
  def build_controller(input_def: nil, filter_def: nil, resource_class: nil)
    controller = Class.new do
      attr_accessor :rendered, :head_status

      def self.before_action(*) = nil
      def self.skip_verify_current_authorized_scope(*) = nil

      include Plutonium::Resource::Controllers::Typeahead

      def render(opts) = (@rendered = opts)
      def head(status) = (@head_status = status)
      def params = @params ||= {}
      attr_writer :params

      attr_accessor :current_definition, :current_query_object, :resource_class

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

    controller.resource_class = resource_class || Class.new {
      def self.reflect_on_association(_) = nil
    }

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

  def test_typeahead_input_returns_400_when_no_choices_and_no_association
    controller = build_controller(input_def: {name: :foo, value: {options: {as: :string}}})
    controller.params = {name: "foo"}
    controller.typeahead_input
    assert_equal :bad_request, controller.rendered[:status]
    assert_equal({error: "input has no typeahead source"}, controller.rendered[:json])
  end

  def test_typeahead_input_filters_static_choices_case_insensitively
    controller = build_controller(
      input_def: {name: :foo, value: {options: {choices: [["Alice", "1"], ["Bob", "2"], ["Alistair", "3"]]}}}
    )
    controller.params = {name: "foo", q: "ali"}
    controller.typeahead_input

    body = controller.rendered[:json]
    labels = body[:results].map { |r| r[:label] }
    assert_equal ["Alice", "Alistair"], labels
    refute body[:has_more]
  end

  def test_typeahead_input_signals_overflow_when_candidates_exceed_limit
    big_choices = 60.times.map { |i| ["item#{i}", i.to_s] }
    controller = build_controller(input_def: {name: :foo, value: {options: {choices: big_choices}}})
    controller.params = {name: "foo", q: ""}
    controller.typeahead_input

    body = controller.rendered[:json]
    assert_equal Plutonium::Resource::Controllers::Typeahead::TYPEAHEAD_LIMIT, body[:results].length
    assert body[:has_more]
  end

  def test_typeahead_input_resolves_association_via_reflection
    associated = Class.new {
      def self.column_names = ["name"]
      def self.connection = Class.new { def quote_column_name(c) = "\"#{c}\"" }.new
    }
    captured_klass = nil
    fake_relation = Object.new.tap do |r|
      def r.where(*)
        self
      end

      def r.limit(*)
        self
      end

      def r.to_a
        []
      end

      def r.klass
        @klass
      end

      def r.klass=(k)
        @klass = k
      end
    end
    fake_relation.klass = associated

    parent = Class.new
    reflection = OpenStruct.new(klass: associated)
    parent.define_singleton_method(:reflect_on_association) { |name| (name == :author) ? reflection : nil }

    controller = build_controller(
      input_def: {name: :author, value: {options: {}}},
      resource_class: parent
    )
    controller.define_singleton_method(:authorized_resource_scope) do |klass, **|
      captured_klass = klass
      fake_relation
    end

    controller.params = {name: "author", q: "ali"}
    controller.typeahead_input

    assert_equal associated, captured_klass
    assert_kind_of Hash, controller.rendered[:json]
    assert_equal [], controller.rendered[:json][:results]
  end
end
