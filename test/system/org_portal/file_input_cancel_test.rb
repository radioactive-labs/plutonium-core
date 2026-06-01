# frozen_string_literal: true

require "application_system_test_case"

# Regression: dismissing a native file picker fires a *bubbling* `cancel`
# event on the <input type="file">. That event reaches the <dialog>'s cancel
# listeners (remote-modal / dirty-form-guard), which used to treat it as a
# request to close the modal — so cancelling the picker closed the whole
# modal/slideover. The handlers now ignore cancels that don't target the
# dialog itself.
class OrgPortal::FileInputCancelTest < ApplicationSystemTestCase
  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    @product = create_product!(
      category: @category, user: @user, organization: @org, status: :draft
    )
  end

  test "dismissing a file picker does not close the action modal" do
    # Visit the target first: the portal bounces us to login and remembers the
    # location (login_return_to_requested_location?), so login lands straight
    # back on the product show page — avoiding the app's rootless "/" redirect.
    visit "/org/#{@org.to_param}/catalog/products/#{@product.id}"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"

    # Settle: confirm the show page rendered before querying for the action link.
    assert_text @product.name

    # Trigger the action's own link (data-turbo-frame="remote_modal") directly,
    # rather than fighting the responsive actions dropdown. Turbo loads the
    # form into the modal frame exactly as a user click would. The link lives
    # in a collapsed dropdown, so it's in the DOM but not visible.
    assert_selector "a[href*='record_actions/publish']", visible: :all, wait: 5
    page.execute_script(<<~JS)
      document.querySelector("a[href*='record_actions/publish']").click();
    JS

    assert_selector "dialog[open]", wait: 5
    assert_selector "dialog[open] input[type='file']"

    # Reproduce exactly what the browser dispatches when the OS file picker
    # is dismissed without choosing a file.
    page.execute_script(<<~JS)
      document
        .querySelector("dialog[open] input[type='file']")
        .dispatchEvent(new Event("cancel", { bubbles: true }));
    JS

    # The buggy close is async (remote-modal#animateClose removes the `open`
    # attribute only after exit animations settle, ~250ms). Wait past that
    # window before asserting, so a regression can't slip through the gap.
    sleep 0.5

    # Modal must still be open and intact.
    assert_selector "dialog[open]"
    assert_selector "dialog[open] input[type='file']"
  end
end
