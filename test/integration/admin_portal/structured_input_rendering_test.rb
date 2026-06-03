# frozen_string_literal: true

require "test_helper"

class AdminPortal::StructuredInputRenderingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "single structured input renders one fieldset with nested names" do
    get "/admin/catalog/specs/new"
    assert_response :success
    assert_includes response.body, %(name="catalog_spec[payload][title]")
    assert_includes response.body, %(name="catalog_spec[payload][notes]")
  end

  # payload is sourced from a `using:` fields class restricted via `fields:`.
  test "using: + fields: renders only the permitted subset" do
    get "/admin/catalog/specs/new"
    assert_response :success
    # title/notes come from the using: class...
    assert_includes response.body, %(name="catalog_spec[payload][title]")
    assert_includes response.body, %(name="catalog_spec[payload][notes]")
    # ...but sku is declared on the class and restricted away by fields:.
    refute_includes response.body, %(name="catalog_spec[payload][sku]")
  end

  # The inline-block path renders identically to `using:`; meta is single, items
  # is a repeater. This proves block-declared fields reach the form.
  test "inline-block structured inputs render (single + repeater)" do
    get "/admin/catalog/specs/new"
    assert_response :success
    # single (block)
    assert_includes response.body, %(name="catalog_spec[meta][heading]")
    assert_includes response.body, %(name="catalog_spec[meta][body]")
    # repeater (block)
    assert_includes response.body, %(name="catalog_spec[items][NEW_RECORD][label]")
    assert_includes response.body, %(name="catalog_spec[items][NEW_RECORD][amount]")
  end

  test "single structured inputs have no per-row controller (only repeaters do)" do
    get "/admin/catalog/specs/new"
    # Per-row controllers belong only to repeaters' <template> rows — one each
    # for `rows` and `items`. The single payload/meta fieldsets must not have one.
    assert_equal 2, response.body.scan(%(data-controller="structured-input-row")).size
  end

  test "repeater renders the controller container, template, and nested names" do
    get "/admin/catalog/specs/new"
    assert_match(/data-controller="nested-resource-form-fields"[^>]*data-nested-resource-form-fields-limit-value="5"/, response.body)
    assert_includes response.body, %(<template data-nested-resource-form-fields-target="template">)
    assert_includes response.body, %(name="catalog_spec[rows][NEW_RECORD][key]")
    assert_includes response.body, %(data-action="nested-resource-form-fields#add")
  end

  test "repeater rows soft-delete by disabling their fieldset (no _destroy marker)" do
    get "/admin/catalog/specs/new"
    # No _destroy marker — removal works by omitting the row from submission.
    refute_includes response.body, %([_destroy])
    # The row's fields live in a disable-able fieldset; remove/restore toggle it.
    assert_includes response.body, %(data-structured-input-row-target="content")
    assert_includes response.body, %(data-action="structured-input-row#remove")
    assert_includes response.body, %(data-action="structured-input-row#restore")
    assert_includes response.body, %(data-structured-input-row-target="removed")
  end
end
