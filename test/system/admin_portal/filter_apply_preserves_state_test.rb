# frozen_string_literal: true

require "application_system_test_case"

# Applying a filter from the slideover must preserve the current sort,
# scope, search and view. The FilterForm submits via GET to a bare
# request_path, so the only mechanism carrying those across an apply is
# hidden inputs. This is the end-to-end counterpart to the unit tests in
# filter_form_test.rb: it drives the real index page (login, slideover,
# Apply) and asserts the resulting URL still carries sort/scope/view.
#
# Catalog::Product is the fixture: it declares scopes (:active, :draft,
# :discontinued), sorts (:name, :price_cents, :status, :created_at) and
# the Grid index view (grid_fields). The same FilterForm renders across
# Table::Resource and Grid::Resource, so both views are exercised.
class AdminPortal::FilterApplyPreservesStateTest < ApplicationSystemTestCase
  setup do
    @admin = create_admin!
    # An active-scoped product so the scope=active URL returns a row and
    # the index isn't an empty card (which renders a different shell).
    create_product!(status: :active, name: "Alpha")
  end

  teardown do
    Product.delete_all if defined?(Product)
    Catalog::Product.delete_all
  end

  # Table view: sort + scope + view survive an Apply.
  test "applying a filter on the table preserves sort, scope and view" do
    open_index view: :table

    within "#filter-form" do
      # The filter <label> has no `for` (Phlexi renders a sibling label), so
      # fill by the field's id rather than by label text.
      fill_in "q_name_query", with: "Alpha"
      click_button "Apply"
    end

    assert_current_path(/view=table/, wait: 5)
    assert_current_path(/q%5Bsort_fields%5D%5B%5D=name/, wait: 5)
    assert_current_path(/q%5Bsort_directions%5D%5Bname%5D=ASC/, wait: 5)
    assert_current_path(/q%5Bscope%5D=active/, wait: 5)
    assert_current_path(/q%5Bname%5D%5Bquery%5D=Alpha/, wait: 5)
  end

  # Grid view: same FilterForm, same hidden state — view=grid survives.
  test "applying a filter on the grid preserves sort, scope and view" do
    open_index view: :grid

    within "#filter-form" do
      fill_in "q_name_query", with: "Alpha"
      click_button "Apply"
    end

    assert_current_path(/view=grid/, wait: 5)
    assert_current_path(/q%5Bsort_fields%5D%5B%5D=name/, wait: 5)
    assert_current_path(/q%5Bsort_directions%5D%5Bname%5D=ASC/, wait: 5)
    assert_current_path(/q%5Bscope%5D=active/, wait: 5)
    assert_current_path(/q%5Bname%5D%5Bquery%5D=Alpha/, wait: 5)
  end

  # No prior sort/scope in the URL: Apply must not fabricate a sort or a
  # real scope value. The FilterForm always renders a `q[scope]` hidden
  # input (so an explicit "All" selection can round-trip), so the param
  # key appears with an EMPTY value — that empty marker is NOT fabricated
  # state (QueryObject treats `q[scope]=""` as "All"). The guard is that
  # no NON-EMPTY scope and no sort_fields leak in.
  test "applying a filter with no prior sort or scope does not fabricate them" do
    open_index view: :table, sort_scope: false

    within "#filter-form" do
      fill_in "q_name_query", with: "Alpha"
      click_button "Apply"
    end

    assert_current_path(/view=table/, wait: 5)
    assert_current_path(/q%5Bname%5D%5Bquery%5D=Alpha/, wait: 5)
    # No sort_fields at all (the array div is empty when nothing is sorted).
    assert_no_match(/q%5Bsort_fields%5D/, page.current_url)
    # Scope present but EMPTY — not fabricated to a real scope value.
    assert_no_match(/q%5Bscope%5D=[^&]/, page.current_url)
  end

  private

  # Logs in (Rodauth returns to the original URL preserving query params)
  # then opens the filter slideover so #filter-form is interactive.
  def open_index(view:, sort_scope: true)
    query = sort_scope ? "?view=#{view}&q[scope]=active&q[sort_fields][]=name&q[sort_directions][name]=ASC" : "?view=#{view}"
    visit "/admin/catalog/products#{query}"
    fill_in "login", with: @admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"
    # Open the filter slideover so #filter-form is visible for filling.
    click_button "Filter"
    assert_selector "#filter-form", wait: 5
    # Confirm the hidden state rendered the current sort/scope before Apply.
    assert_selector "#filter-form input[name='q[sort_fields][]'][value='name']", visible: :all if sort_scope
  end
end
