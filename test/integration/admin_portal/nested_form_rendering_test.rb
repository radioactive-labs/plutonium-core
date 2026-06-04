# frozen_string_literal: true

require "test_helper"

# Characterization tests for Plutonium::UI::Form::Concerns::RendersNestedResourceFields.
#
# These pin the rendered HTML contract of nested resource form fields through a
# real request, so the concern can later be extracted into a dedicated Phlex
# component without silently changing output. The fixture is the catalog Product
# form, which declares a has_many (`variants`) and a has_one (`product_detail`)
# nested input — exercising both the `nest_many` and `nest_one` paths.
class AdminPortal::NestedFormRenderingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  # --- has_many (variants) on the new form -------------------------------

  test "renders the nested fields container with the Stimulus controller and limit" do
    get "/admin/catalog/products/new"
    assert_response :success

    assert_match(
      %r{<div class="col-span-full space-y-2 my-4" data-controller="nested-resource-form-fields" data-nested-resource-form-fields-limit-value="10">},
      response.body
    )
  end

  test "renders a header for each nested input" do
    get "/admin/catalog/products/new"

    assert_includes response.body, %(<h2 class="text-lg font-semibold text-[var(--pu-text)]">Variants</h2>)
    assert_includes response.body, %(<h2 class="text-lg font-semibold text-[var(--pu-text)]">Product detail</h2>)
  end

  test "renders a JS template holding a blank NEW_RECORD fieldset" do
    get "/admin/catalog/products/new"

    assert_includes response.body, %(<template data-nested-resource-form-fields-target="template">)
    assert_includes response.body,
      %(<fieldset data-new-record class="nested-resource-form-fields border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] p-4 space-y-4 relative">)
    # Fields inside the template use the NEW_RECORD placeholder key.
    assert_includes response.body, %(name="catalog_product[variants_attributes][NEW_RECORD][name]")
    assert_includes response.body, %(name="catalog_product[variants_attributes][NEW_RECORD][sku]")
    assert_includes response.body, %(name="catalog_product[variants_attributes][NEW_RECORD][stock_count]")
  end

  test "renders hidden id and _destroy fields for nested records" do
    get "/admin/catalog/products/new"

    assert_includes response.body, %(name="catalog_product[variants_attributes][NEW_RECORD][id]")
    assert_match(
      %r{<input type="hidden" id="catalog_product_variants_attributes_NEW_RECORD__destroy" name="catalog_product\[variants_attributes\]\[NEW_RECORD\]\[_destroy\]" value="false"},
      response.body
    )
  end

  test "renders the remove button and a restorable removed bar wired to the controller" do
    get "/admin/catalog/products/new"

    # Remove button (replaces the old delete checkbox)
    assert_includes response.body, %(data-action="nested-resource-form-fields#remove")
    assert_match(/<button[^>]*nested-resource-form-fields#remove[^>]*>.*Remove/m, response.body)

    # Content is wrapped so it can be hidden, with a hidden "Removed — Restore"
    # bar the controller reveals on remove.
    assert_includes response.body, %(data-nested-content)
    assert_includes response.body, %(data-nested-removed)
    assert_includes response.body, %(data-action="nested-resource-form-fields#restore")
    assert_match(/nested-resource-form-fields#restore[^>]*>.*Restore/m, response.body)
  end

  test "renders the add button wired to the add action with a singularized label" do
    get "/admin/catalog/products/new"

    assert_includes response.body, %(data-action="nested-resource-form-fields#add")
    assert_includes response.body, %(data-nested-resource-form-fields-target="addButton")
    assert_includes response.body, "Add Variant"
  end

  # --- has_one (product_detail) ------------------------------------------

  test "renders the has_one nested input fields" do
    get "/admin/catalog/products/new"

    assert_includes response.body, %(name="catalog_product[product_detail_attributes][specifications]")
    assert_includes response.body, %(name="catalog_product[product_detail_attributes][warranty_info]")
  end

  # --- existing records on the edit form ---------------------------------

  test "renders existing nested records with their persisted values and ids" do
    product = create_product!
    variant = create_variant!(product: product, name: "Existing Variant", sku: "EXIST-1")

    get "/admin/catalog/products/#{product.id}/edit"
    assert_response :success

    # The persisted variant renders outside the template, keyed by its real id.
    assert_includes response.body, %(name="catalog_product[variants_attributes][0][id]")
    assert_includes response.body, %(value="#{variant.id}")
    assert_includes response.body, %(value="Existing Variant")
    assert_includes response.body, %(value="EXIST-1")
  end
end
