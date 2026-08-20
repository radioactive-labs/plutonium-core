# frozen_string_literal: true

require "application_system_test_case"

# Why {SlimSelectHelpers#select_association} retries instead of waiting.
#
# OrgPortal::PolymorphicNestedCreateTest failed intermittently in CI with:
#
#   expected to find visible css ".ss-main" with text "User #34"
#   but there were no matches. Also found "".
#
# The widget was still showing its placeholder, so the option click never took
# effect. The test already waited 10 seconds for the result — which is the point:
# a click that did not land cannot be waited out. Only redone.
#
# A lost click is forced here rather than raced for. slim-select selects on
# `click`, so a one-shot capture-phase listener that swallows the first click on
# an `.ss-option` reproduces the failure signature exactly, every run.
class SlimSelectHelperTest < ApplicationSystemTestCase
  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @post = create_post!(user: @user, organization: @org)

    visit "/org/#{@org.to_param}/blogging/posts/#{@post.id}/nested_noninverse_comments/new"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"
    assert_selector ".ss-main", wait: 10
  end

  # Swallow the first N clicks on an option, in the capture phase so it runs
  # before slim-select's own handler.
  def swallow_option_clicks!(count)
    page.execute_script(<<~JS, count)
      window.__ssSwallowed = 0;
      const budget = arguments[0];
      document.addEventListener("click", (e) => {
        if (e.target.closest(".ss-option") && window.__ssSwallowed < budget) {
          window.__ssSwallowed++;
          e.stopImmediatePropagation();
          e.preventDefault();
        }
      }, true);
    JS
  end

  def swallowed_count = page.evaluate_script("window.__ssSwallowed")

  test "a lost click leaves the widget unselected no matter how long you wait" do
    swallow_option_clicks!(1)

    # The sequence the flaky test used inline.
    find(".ss-main").click
    find(".ss-option", text: @user.to_label, exact_text: true, match: :first, wait: 5).click

    assert_equal 1, swallowed_count, "the probe must actually have eaten a click"
    # Waiting cannot recover a click that never reached the widget. This is the
    # whole reason the fix has to retry rather than wait longer.
    refute_selector ".ss-main", text: @user.to_label, wait: 3
  end

  test "select_association retries the interaction until the choice lands" do
    swallow_option_clicks!(1)

    select_association @user.to_label, from: "comment[user]"

    assert_equal 1, swallowed_count
    assert_selector ".ss-main", text: @user.to_label, wait: 0
  end

  # One lost click could be luck. A widget that eats several in a row is the
  # slow-CI case this has to survive.
  test "select_association survives several lost clicks in a row" do
    swallow_option_clicks!(3)

    select_association @user.to_label, from: "comment[user]"

    assert_equal 3, swallowed_count
    assert_selector ".ss-main", text: @user.to_label, wait: 0
  end

  test "it gives up with a diagnostic naming the widget's state and the options offered" do
    swallow_option_clicks!(9_999)

    error = assert_raises(Capybara::ExpectationNotMet) do
      select_association @user.to_label, from: "comment[user]", wait: 2
    end

    # A bare "expected to find" says nothing about WHY. The two facts that
    # actually locate the problem are what the widget reads and what it offered.
    assert_match(/never showed/, error.message)
    assert_match(/The widget reads/, error.message)
    assert_match(/Options offered/, error.message)
  end

  test "it is a no-op when the option is already selected" do
    select_association @user.to_label, from: "comment[user]"
    swallow_option_clicks!(9_999)

    # Must not re-open and re-click: with every click swallowed, anything that
    # tried would raise rather than return.
    select_association @user.to_label, from: "comment[user]", wait: 2

    assert_equal 0, swallowed_count
    assert_selector ".ss-main", text: @user.to_label, wait: 0
  end
end
