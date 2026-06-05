# frozen_string_literal: true

require "application_system_test_case"

# Regression: third-party field widgets (intl-tel-input phone picker,
# flatpickr, slim-select, easymde, …) normalise/inject form values *after*
# the form connects — a silent `input.value = …` assignment and/or an
# injected hidden input, neither of which the user triggered. dirty-form-guard
# used to snapshot the form once on connect and diff against it, so these
# settle-time mutations made a pristine modal look dirty and Esc/close popped a
# spurious "Discard changes?" prompt.
#
# The guard now tracks dirtiness only from *trusted* user input/change events,
# so widget mutations can never flag a form the user never touched.
class OrgPortal::DirtyFormGuardWidgetTest < ApplicationSystemTestCase
  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    @product = create_product!(
      category: @category, user: @user, organization: @org, status: :draft
    )
  end

  test "widget-mutated form is not treated as dirty on close" do
    visit "/org/#{@org.to_param}/catalog/products/#{@product.id}"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"

    assert_text @product.name

    # Open the publish action form in the modal (same path as a user click).
    assert_selector "a[href*='record_actions/publish']", visible: :all, wait: 5
    page.execute_script(<<~JS)
      document.querySelector("a[href*='record_actions/publish']").click();
    JS

    assert_selector "dialog[open] form", wait: 5
    assert_selector "dialog[open] form input[type='text']"

    # Reproduce exactly what a field widget does once it settles: rewrite a
    # field's value via the property (fires NO event) and append a hidden input
    # — all without any user interaction.
    page.execute_script(<<~JS)
      const form = document.querySelector("dialog[open] form");
      const text = form.querySelector("input[type='text']");
      text.value = "reformatted-by-widget";
      const hidden = document.createElement("input");
      hidden.type = "hidden";
      hidden.name = "widget_injected";
      hidden.value = "+15551234567";
      form.appendChild(hidden);
    JS

    # Press Esc. With a pristine (user-untouched) form the guard must not
    # intervene, so the modal closes natively — no discard confirm.
    find("body").send_keys(:escape)

    # Close animates (~250ms); wait past it so a regression can't slip through.
    sleep 0.5

    # No discard prompt, and the modal is gone.
    assert_no_selector "[data-dirty-form-guard-target='confirmDialog'][open]"
    assert_no_selector "dialog[open] form"
  end

  test "genuine user edit still prompts before discarding" do
    visit "/org/#{@org.to_param}/catalog/products/#{@product.id}"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"

    assert_text @product.name

    assert_selector "a[href*='record_actions/publish']", visible: :all, wait: 5
    page.execute_script(<<~JS)
      document.querySelector("a[href*='record_actions/publish']").click();
    JS

    assert_selector "dialog[open] form input[type='text']", wait: 5

    # `.set` types through the browser, so it dispatches *trusted* input
    # events — exactly what a real edit produces.
    find("dialog[open] form input[type='text']").set("real user input")

    find("body").send_keys(:escape)

    # The guard must intervene: discard prompt shown, modal still open.
    assert_selector "[data-dirty-form-guard-target='confirmDialog'][open]", wait: 5
    assert_selector "dialog[open] form"
  end

  # Widgets like flatpickr / slim-select / easymde push the user's choice into
  # the underlying field via a *synthetic* (untrusted) change event. Those edits
  # must still dirty the form — but only once the user has genuinely engaged it,
  # so load-time settling (covered above) stays clean.
  test "widget-mediated edit after a real interaction prompts" do
    visit "/org/#{@org.to_param}/catalog/products/#{@product.id}"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"

    assert_text @product.name

    assert_selector "a[href*='record_actions/publish']", visible: :all, wait: 5
    page.execute_script(<<~JS)
      document.querySelector("a[href*='record_actions/publish']").click();
    JS

    assert_selector "dialog[open] form input[type='text']", wait: 5

    # Real pointer interaction inside the form (trusted) — engages it, the way
    # opening a date picker or select dropdown would.
    find("dialog[open] form input[type='text']").click

    # Now a widget sets the value and fires a synthetic (untrusted) change —
    # exactly what flatpickr/slim-select do on selection.
    page.execute_script(<<~JS)
      const f = document.querySelector("dialog[open] form input[type='text']");
      f.value = "chosen-via-widget";
      f.dispatchEvent(new Event("change", { bubbles: true }));
    JS

    find("body").send_keys(:escape)

    assert_selector "[data-dirty-form-guard-target='confirmDialog'][open]", wait: 5
    assert_selector "dialog[open] form"
  end

  # The baseline is captured at first interaction and compared on close, so an
  # edit reverted back to its original value reads as clean — no prompt.
  test "editing a field then reverting it does not prompt" do
    visit "/org/#{@org.to_param}/catalog/products/#{@product.id}"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"

    assert_text @product.name

    assert_selector "a[href*='record_actions/publish']", visible: :all, wait: 5
    page.execute_script(<<~JS)
      document.querySelector("a[href*='record_actions/publish']").click();
    JS

    assert_selector "dialog[open] form input[type='text']", wait: 5

    field = find("dialog[open] form input[type='text']")
    field.set("temporary")   # trusted typing — baselines the (empty) original
    field.set("")            # back to the original value

    find("body").send_keys(:escape)
    sleep 0.5

    assert_no_selector "[data-dirty-form-guard-target='confirmDialog'][open]"
    assert_no_selector "dialog[open] form"
  end
end
