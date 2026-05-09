# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::ResourceSelectTypeaheadTest < Minitest::Test
  def test_registry_lookup
    assert_equal Plutonium::UI::Form::Components::ResourceSelect,
      Plutonium::UI::Form::Components::Searchable.registry[:resource_select]
  end

  def test_static_choices_case_insensitive_substring_match
    widget = build_widget(choices: [["Alice", "1"], ["Bob", "2"], ["Alistair", "3"]])
    results, has_more = widget.typeahead(query: "ali", limit: 50, controller: nil)
    labels = results.map { |r| r[:label] }
    assert_equal ["Alice", "Alistair"], labels
    refute has_more
  end

  def test_static_choices_returns_all_for_blank_query
    widget = build_widget(choices: [["Alice", "1"], ["Bob", "2"]])
    results, _ = widget.typeahead(query: "", limit: 50, controller: nil)
    assert_equal 2, results.length
  end

  def test_static_choices_serializes_value_and_label
    widget = build_widget(choices: [["Alice", "1"]])
    results, _ = widget.typeahead(query: "", limit: 50, controller: nil)
    assert_equal({value: "1", label: "Alice"}, results.first)
  end

  def test_static_choices_overflow_detection
    widget = build_widget(choices: 60.times.map { |i| ["item#{i}", i.to_s] })
    results, has_more = widget.typeahead(query: "", limit: 50, controller: nil)
    assert_equal 50, results.length
    assert has_more
  end

  def test_association_path_calls_authorized_resource_scope
    captured_class = nil
    fake_relation = stub_relation_with_connection
    fake_controller = Object.new
    fake_controller.define_singleton_method(:authorized_resource_scope) do |klass, **|
      captured_class = klass
      fake_relation
    end

    fake_class = Class.new
    fake_class.define_singleton_method(:column_names) { ["name"] }

    widget = build_widget(association_class: fake_class)
    widget.typeahead(query: "ali", limit: 50, controller: fake_controller)
    assert_equal fake_class, captured_class
  end

  def test_association_path_skips_authorization_when_flag_set
    rel = stub_relation
    fake_class = Class.new
    fake_class.define_singleton_method(:all) { rel }
    fake_class.define_singleton_method(:column_names) { ["name"] }

    widget = build_widget(association_class: fake_class, skip_authorization: true)
    # Should not call authorized_resource_scope (would NoMethodError on nil controller).
    results, _ = widget.typeahead(query: "", limit: 50, controller: nil)
    assert_equal [], results
  end

  def test_typeahead_attributes_unset_when_option_missing
    widget = build_widget
    attrs = {}
    widget.define_singleton_method(:attributes) { attrs }
    widget.send(:configure_typeahead_attributes!, nil)
    assert_empty attrs
  end

  def test_typeahead_attributes_skipped_when_url_resolution_fails
    widget = build_widget
    # Force typeahead_url_for to return nil
    widget.define_singleton_method(:typeahead_url_for) { |_| nil }
    attrs = {}
    widget.define_singleton_method(:attributes) { attrs }
    widget.send(:configure_typeahead_attributes!, true)
    assert_empty attrs
  end

  def test_typeahead_attributes_added_when_url_resolves
    widget = build_widget
    widget.define_singleton_method(:typeahead_url_for) { |_| "/admin/users/typeahead/input/manager" }
    widget.define_singleton_method(:tokens) { |*args| args.compact.join(" ") }
    attrs = {data_controller: "slim-select"}
    widget.define_singleton_method(:attributes) { attrs }
    widget.send(:configure_typeahead_attributes!, true)
    assert_match(/resource-select/, attrs[:data_controller])
    assert_equal "/admin/users/typeahead/input/manager", attrs[:data_resource_select_url_value]
  end

  private

  def build_widget(**options)
    Plutonium::UI::Form::Components::ResourceSelect.build_for_typeahead(options)
  end

  def stub_relation
    rel = Object.new
    rel.define_singleton_method(:where) { |*| self }
    rel.define_singleton_method(:limit) { |*| self }
    rel.define_singleton_method(:to_a) { [] }
    rel.define_singleton_method(:klass) {
      Class.new {
        def self.column_names
          ["name"]
        end
      }
    }
    rel
  end

  # Relation stub that also provides a klass with a DB connection stub,
  # needed when apply_association_search runs quote_column_name.
  def stub_relation_with_connection
    inner_klass = Class.new do
      def self.column_names
        ["name"]
      end

      def self.connection
        conn = Object.new
        conn.define_singleton_method(:quote_column_name) { |col| %("#{col}") }
        conn
      end
    end

    rel = Object.new
    rel.define_singleton_method(:where) { |*| self }
    rel.define_singleton_method(:limit) { |*| self }
    rel.define_singleton_method(:to_a) { [] }
    rel.define_singleton_method(:klass) { inner_klass }
    rel
  end
end
