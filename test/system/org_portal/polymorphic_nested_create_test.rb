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
    # select_association drives the slim-select widget the way a user does and
    # RETRIES the whole open-narrow-click until the widget reflects the choice.
    # Doing it inline here is what made this test flaky: a lost click cannot be
    # waited out, only redone. See test/support/slim_select_helpers.rb.
    #
    # Matched on the user's `to_label` ("User #1"), which is what the widget
    # renders — the email only exists on the model.
    select_association @user.to_label, from: "comment[user]"

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
