# frozen_string_literal: true

require "application_system_test_case"

# Regression: a grid card's row-actions dropdown used to be clipped by the
# card's `overflow-hidden` once any ancestor established a containing block
# (transform / filter / will-change / contain) — popper's `fixed` strategy
# escapes plain overflow, but not a transformed overflow ancestor. The
# dropdown controller now teleports the open menu to <body>, so no former
# ancestor can clip it. This drives the real browser to confirm it.
class OrgPortal::GridActionsDropdownTest < ApplicationSystemTestCase
  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    3.times do
      create_product!(category: @category, user: @user, organization: @org, status: :draft)
    end
  end

  test "grid card actions dropdown teleports to body and is not clipped" do
    # Visit the grid view first; the portal bounces to login and returns here.
    visit "/org/#{@org.to_param}/catalog/products?view=grid"
    fill_in "login", with: @user.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"

    # Grid rendered as cards.
    assert_selector ".pu-card", minimum: 3, wait: 5

    # Simulate a real app shell: give a grid ancestor a containing-block
    # trigger + overflow:hidden. Pre-fix, this clips the popper-fixed menu.
    page.execute_script(<<~JS)
      const card = document.querySelector('.pu-card');
      const host = card.parentElement; // the grid container
      host.style.transform = 'translateZ(0)';
      host.style.overflow = 'hidden';
    JS

    # Open the first card's actions dropdown.
    first("[data-resource-drop-down-target='trigger']").click

    # The open menu must be teleported to <body> and fully visible/unclipped.
    result = page.evaluate_script(<<~JS)
      (() => {
        const menus = Array.from(document.querySelectorAll("[data-resource-drop-down-target='menu']"));
        const menu = menus.find(m => !m.classList.contains('hidden'));
        if (!menu) return { open: false };
        const r = menu.getBoundingClientRect();
        // Probe near the menu's bottom edge — the part that used to be clipped.
        const x = r.left + r.width / 2;
        const y = r.bottom - 4;
        const hit = document.elementFromPoint(x, y);
        return {
          open: true,
          inBody: menu.parentElement === document.body,
          visible: r.width > 0 && r.height > 0,
          bottomReachesMenu: !!(hit && menu.contains(hit)),
        };
      })()
    JS

    assert result["open"], "dropdown menu did not open"
    assert result["inBody"], "menu was not teleported to <body> (fix inactive)"
    assert result["visible"], "menu has zero size"
    assert result["bottomReachesMenu"],
      "menu bottom is clipped — element at its lower edge is not the menu"
  end
end
