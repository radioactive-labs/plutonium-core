# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/form/components/searchable"

class Plutonium::UI::Form::Components::SearchableTest < Minitest::Test
  class TestWidget
    include Plutonium::UI::Form::Components::Searchable

    typeahead_input_name :test_widget

    attr_reader :options

    def apply_typeahead_options(options)
      @options = options
    end

    def collect_typeahead_candidates(query, controller:)
      pool = @options[:pool] || []
      query.empty? ? pool : pool.select { |s| s.include?(query) }
    end

    def serialize_typeahead_row(row)
      {value: row, label: row.upcase}
    end
  end

  def teardown
    Plutonium::UI::Form::Components::Searchable.registry.delete(:test_widget)
    Plutonium::UI::Form::Components::Searchable.registry[:test_widget] = TestWidget
  end

  def test_typeahead_input_name_registers_class
    assert_equal TestWidget, Plutonium::UI::Form::Components::Searchable.registry[:test_widget]
  end

  def test_build_for_typeahead_assigns_options
    widget = TestWidget.build_for_typeahead(pool: %w[alice bob])
    assert_equal({pool: %w[alice bob]}, widget.options)
  end

  def test_typeahead_returns_results_and_has_more_false
    widget = TestWidget.build_for_typeahead(pool: %w[alice bob])
    results, has_more = widget.typeahead(query: "ali", limit: 50, controller: nil)
    assert_equal [{value: "alice", label: "ALICE"}], results
    refute has_more
  end

  def test_typeahead_returns_has_more_true_when_candidates_exceed_limit
    widget = TestWidget.build_for_typeahead(pool: %w[a1 a2 a3 a4])
    results, has_more = widget.typeahead(query: "a", limit: 2, controller: nil)
    assert_equal 2, results.length
    assert has_more
  end

  def test_typeahead_blank_query_returns_all_within_limit
    widget = TestWidget.build_for_typeahead(pool: %w[a b c])
    results, _ = widget.typeahead(query: "", limit: 50, controller: nil)
    assert_equal 3, results.length
  end

  def test_host_class_must_implement_apply_typeahead_options
    bare = Class.new { include Plutonium::UI::Form::Components::Searchable }
    assert_raises(NoMethodError) { bare.build_for_typeahead({}) }
  end
end
