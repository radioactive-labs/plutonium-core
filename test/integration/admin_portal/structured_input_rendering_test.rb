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

  test "single structured input has no remove control (only the repeater does)" do
    get "/admin/catalog/specs/new"
    # On the new form the only rendered remove control belongs to the repeater's
    # <template> row; the single payload fieldset must not render one.
    assert_equal 1, response.body.scan("nested-resource-form-fields#remove").size
  end

  test "repeater renders the controller container, template, and nested names" do
    get "/admin/catalog/specs/new"
    assert_match(/data-controller="nested-resource-form-fields"[^>]*data-nested-resource-form-fields-limit-value="5"/, response.body)
    assert_includes response.body, %(<template data-nested-resource-form-fields-target="template">)
    assert_includes response.body, %(name="catalog_spec[rows][NEW_RECORD][key]")
    assert_includes response.body, %(data-action="nested-resource-form-fields#add")
    refute_includes response.body, %(catalog_spec[rows][NEW_RECORD][_destroy])
    # Each row carries data-new-record so the Stimulus remove action deletes it
    # from the DOM (classless rows have no _destroy input to fall back to).
    assert_includes response.body, %(data-new-record)
  end
end
