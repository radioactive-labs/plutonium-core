# frozen_string_literal: true

require "application_system_test_case"

# The integration test for this path proves the server infers the parent field.
# It does not render anything: an ActionDispatch::IntegrationTest never opens a
# browser, so a form that will not submit — a stray required input, a Stimulus
# controller that throws on connect — would sail through it.
#
# This drives the same nesting in Chrome, through the form a user actually gets,
# and fails on any severe console error along the way.
class OrgPortal::PolymorphicNestedCreateTest < ApplicationSystemTestCase
  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @post = create_post!(user: @user, organization: @org)
  end

  test "creates a comment through a polymorphic nesting with no inverse_of" do
    visit "/org/#{@org.to_param}/blogging/posts/#{@post.id}/nested_noninverse_comments/new"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"

    assert_selector "form", wait: 10

    # Drain the console buffer before the part under test. The browser session is
    # shared across the system suite, so `logs.get` otherwise returns whatever
    # earlier tests logged — and the login page this test just walked through
    # has its own unrelated Stimulus error ("Missing target element \"checkbox\"
    # for \"password-visibility\""). Neither says anything about the nesting, and
    # folding them in makes the assertion below fail depending on run order.
    page.driver.browser.logs.get(:browser)

    fill_in "Body", with: "Typed into the browser"

    # Comment belongs_to :user, so the form will not submit without one — and a
    # validation re-render still shows the typed body, which would make a naive
    # text assertion pass on a comment that was never created.
    #
    # The select is driven through its slim-select widget rather than by name:
    # the native element is display:none and aria-hidden, so Capybara cannot
    # reach it, and reaching past the widget would not be what a user does. The
    # option is matched on the user's `to_label` ("User #1"), which is what the
    # widget renders — the email only exists on the model.
    find(".ss-main").click
    # exact_text, because Capybara matches substrings: once ids reach double
    # digits, "User #1" also matches "User #10" and match: :first would pick
    # whichever the widget rendered first.
    find(".ss-option", text: @user.to_label, exact_text: true, match: :first, wait: 10).click

    # Confirm the selection LANDED before submitting. slim-select re-renders its
    # option list, so the node found above can go stale between find and click —
    # the click then hits nothing, the form submits with no user, and the failure
    # surfaces as "User must exist" (or, when the driver notices the stale node
    # first, "Node with given id does not belong to the document"). Both are the
    # same bug. This assertion retries until the widget shows the choice, so a
    # lost click is waited out rather than silently submitted.
    assert_selector ".ss-main", text: @user.to_label, wait: 10

    click_button "Create Comment"

    # Wait on the flash, not on the body text: the body is also on screen in the
    # form the user just left, so asserting it can pass mid-navigation and read
    # the database before the create has landed. The flash exists only after the
    # redirect, so it is the signal that the write is done.
    assert_text "Comment was successfully created", wait: 10
    assert_text "Typed into the browser"

    comment = Comment.order(:id).last
    assert_equal @post.id, comment.commentable_id
    # The half that goes missing when the polymorphic reflection is skipped.
    assert_equal @post.class.polymorphic_name, comment.commentable_type
    assert_equal @user.id, comment.user_id

    severe = page.driver.browser.logs.get(:browser).select { |entry| entry.level == "SEVERE" }
    assert_empty severe.map(&:message), "browser console reported errors during the nested create"
  end
end
