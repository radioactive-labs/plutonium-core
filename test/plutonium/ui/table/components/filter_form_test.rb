# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/table/components/filter_form"
require "plutonium/ui/form/query"
require "nokogiri"

# Regression coverage for the FilterForm's hidden state. The filter
# slideover submits via GET to a bare request_path, so hidden inputs are
# the ONLY way to carry the current sort / scope / search / view across
# an apply. `filter_form_values` (the form's record) deliberately excludes
# sort_fields / sort_directions / scope, so reading those off the record
# yields nil and the hidden inputs render empty. The fix threads the
# current values explicitly from params.
class Plutonium::UI::Table::Components::FilterFormTest < ActiveSupport::TestCase
  # FakeQueryObject stands in for Plutonium::Resource::QueryObject: the
  # FilterForm only needs the three definition hashes from it.
  FakeQueryObject = Struct.new(:filter_definitions, :scope_definitions, :sort_definitions) do
    def initialize(filter_definitions: {}, scope_definitions: {}, sort_definitions: {})
      super
    end
  end

  def build_form(params, query_object:, filter_form_values: nil, search_value: nil, search_url: "/admin/tasks")
    filter_form_values ||= filter_form_values_from(params)
    form = Plutonium::UI::Table::Components::FilterForm.new(
      filter_form_values,
      query_object: query_object,
      search_url: search_url,
      search_value: search_value
    )
    # `helpers` is a deprecated alias for `view_context`; bypass the
    # deprecation warning while exercising the same lookup the production
    # code performs (render_sort_fields / render_scope_fields /
    # render_hidden_state all call `helpers.params`).
    form.define_singleton_method(:helpers) { view_context }
    form
  end

  # Mirrors Plutonium::UI::Table::Resource#filter_form_values so the form
  # is constructed exactly as the index page constructs it: the record
  # excludes sort/scope/search so the visible filter inputs stay clean.
  def filter_form_values_from(params)
    raw = params[:q]
    return {} unless raw
    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    hash.deep_symbolize_keys.except(:search, :scope, :sort_fields, :sort_directions)
  end

  def view_context_for(params)
    vc = Object.new
    vc.define_singleton_method(:params) { params }
    vc.define_singleton_method(:turbo_scoped_dom_id) { |base| base.to_s }
    vc
  end

  def render_form(form, params)
    form.call(context: {rails_view_context: view_context_for(params)})
  end

  # Parse every <input type="hidden"> name into a list of its rendered
  # values. CSS attribute selectors can't match names containing `[`
  # (e.g. `q[sort_fields][]`), so select by type and filter in Ruby.
  def hidden_inputs(html)
    Nokogiri::HTML(html).css('input[type="hidden"]').each_with_object(Hash.new { |h, k| h[k] = [] }) do |input, hash|
      hash[input["name"]] << input["value"]
    end
  end

  # ===========================================================================
  # The fix: sort / scope / search / view are preserved across a filter apply
  # ===========================================================================

  test "sort, scope, search, and view are carried as hidden inputs from params" do
    params = ActionController::Parameters.new(
      "q" => {
        "sort_fields" => ["title"],
        "sort_directions" => {"title" => "ASC"},
        "scope" => "active",
        "search" => "foo"
      },
      "view" => "kanban"
    )
    query_object = FakeQueryObject.new(
      scope_definitions: {active: nil, draft: nil},
      sort_definitions: {title: nil, created_at: nil}
    )

    form = build_form(params, query_object:, search_value: params.dig(:q, :search))
    html = render_form(form, params)
    inputs = hidden_inputs(html)

    # sort_fields array field now renders an input per selected sort column;
    # before the fix the array div was empty (value fell back to the excluded
    # record key, so Array(nil) produced zero inputs).
    assert_includes inputs["q[sort_fields][]"], "title",
      "current sort_fields must be carried as hidden inputs"
    # sort_directions keyed per column
    assert_equal ["ASC"], inputs["q[sort_directions][title]"],
      "current sort direction for an active column must be preserved"
    # scope
    assert_equal ["active"], inputs["q[scope]"],
      "current scope must be preserved across a filter apply"
    # search + view (existing behaviour — regression guard)
    assert_equal ["foo"], inputs["q[search]"]
    assert_equal ["kanban"], inputs["view"]
  end

  test "sort_fields with several columns preserves order and every direction" do
    params = ActionController::Parameters.new(
      "q" => {
        "sort_fields" => ["title", "created_at"],
        "sort_directions" => {"title" => "ASC", "created_at" => "DESC"}
      }
    )
    query_object = FakeQueryObject.new(
      scope_definitions: {active: nil},
      sort_definitions: {title: nil, created_at: nil, updated_at: nil}
    )

    form = build_form(params, query_object:)
    inputs = hidden_inputs(render_form(form, params))

    # input_array_tag prepends a blank placeholder input (so an empty
    # submission clears the array); the real sort columns follow it in
    # order. QueryObject drops the blank entry via `& sort_definitions.keys`.
    assert_equal ["title", "created_at"], inputs["q[sort_fields][]"].reject { |v| v.to_s.empty? },
      "every selected sort column must render, in order"
    assert_equal ["ASC"], inputs["q[sort_directions][title]"]
    assert_equal ["DESC"], inputs["q[sort_directions][created_at]"]
    # A column with NO direction in the URL still renders (its direction is
    # read from params and comes back blank); it must not carry over a
    # stale value from the excluded record.
    assert_equal [""], inputs["q[sort_directions][updated_at]"]
  end

  # ===========================================================================
  # No spurious values when the URL carries no sort/scope
  # ===========================================================================

  test "no sort params produces no value-bearing sort inputs" do
    params = ActionController::Parameters.new("q" => {})
    query_object = FakeQueryObject.new(
      scope_definitions: {active: nil},
      sort_definitions: {title: nil}
    )

    form = build_form(params, query_object:)
    inputs = hidden_inputs(render_form(form, params))

    # Array field with nil value -> zero inputs (Array(nil) == []).
    assert_empty inputs["q[sort_fields][]"],
      "no sort selection must not fabricate sort_fields inputs"
    # Direction inputs are keyed per defined sorter; with no value they
    # render blank — but never carry a stale value.
    assert_equal [""], inputs["q[sort_directions][title]"]
    # Scope with no selection renders blank (preserving an explicit "All"
    # would require a separate param; absence stays absent here).
    assert_equal [""], inputs["q[scope]"]
  end

  test "scope hidden input is omitted entirely when the resource defines no scopes" do
    params = ActionController::Parameters.new("q" => {"scope" => "active"})
    query_object = FakeQueryObject.new(
      scope_definitions: {},
      sort_definitions: {title: nil}
    )

    form = build_form(params, query_object:)
    inputs = hidden_inputs(render_form(form, params))

    refute inputs.key?("q[scope]"),
      "render_scope_fields must short-circuit when scope_definitions is blank"
  end

  # ===========================================================================
  # The fix reads from params, NOT from the (excluded) form record — prove
  # the values survive even though filter_form_values drops the keys.
  # ===========================================================================

  test "filter_form_values excludes sort/scope yet the hidden inputs still carry them" do
    params = ActionController::Parameters.new(
      "q" => {"sort_fields" => ["title"], "scope" => "active"}
    )
    query_object = FakeQueryObject.new(
      scope_definitions: {active: nil},
      sort_definitions: {title: nil}
    )

    # The record the production index page passes in:
    record = filter_form_values_from(params)
    assert_nil record[:sort_fields], "precondition: the record excludes sort_fields"
    assert_nil record[:scope], "precondition: the record excludes scope"

    form = build_form(params, query_object:, filter_form_values: record)
    inputs = hidden_inputs(render_form(form, params))

    assert_includes inputs["q[sort_fields][]"], "title"
    assert_equal ["active"], inputs["q[scope]"]
  end

  # ===========================================================================
  # Regression guard for the inline Query form (SearchBar / extract_input).
  #
  # Unlike FilterForm, the Query form's record is `raw_resource_query_params`
  # (params[:q].to_unsafe_h) — a HashWithIndifferentAccess that INCLUDES
  # sort_fields / sort_directions / scope. The implicit object read in its
  # render_sort_fields therefore works. This test pins that behaviour so a
  # future refactor of raw_resource_query_params (e.g. mirroring
  # filter_form_values' exclusions) would break loudly here rather than
  # silently regressing the inline form the way the FilterForm did.
  # ===========================================================================

  QueryFakeQueryObject = Struct.new(:filter_definitions, :scope_definitions, :sort_definitions,
    :search_filter, :search_query) do
    def initialize(filter_definitions: {}, scope_definitions: {}, sort_definitions: {},
      search_filter: nil, search_query: nil)
      super
    end
  end

  test "the inline Query form preserves sort/scope via its full-params record" do
    params = ActionController::Parameters.new(
      "q" => {
        "sort_fields" => ["title"],
        "sort_directions" => {"title" => "ASC"},
        "scope" => "active"
      }
    )
    query_object = QueryFakeQueryObject.new(
      scope_definitions: {active: nil, draft: nil},
      sort_definitions: {title: nil, created_at: nil}
    )
    # raw_resource_query_params includes everything (no exclusions):
    record = params[:q].to_unsafe_h

    form = Plutonium::UI::Form::Query.new(record, query_object: query_object, page_size: 10)
    form.define_singleton_method(:helpers) { view_context_for(params) }
    html = form.call(context: {rails_view_context: view_context_for(params)})
    inputs = hidden_inputs(html)

    assert_includes inputs["q[sort_fields][]"], "title"
    assert_equal ["ASC"], inputs["q[sort_directions][title]"]
    assert_equal ["active"], inputs["q[scope]"]
  end
end
