# frozen_string_literal: true

require "test_helper"
require "capybara/rails"
require "capybara/minitest"
require "selenium/webdriver"

# Treat chromedriver's cross-document node error as a retryable element error.
#
# Turbo Drive renders a visit by parsing the response into a SEPARATE document
# and then adopting it into the live one (`activateNewBody` calls
# `document.adoptNode`). A Capybara query that is mid-flight when that lands
# holds element handles whose ownerDocument just changed, and chromedriver
# rejects them with:
#
#   UnknownError: unhandled inspector error:
#   {"code":-32000,"message":"Node with given id does not belong to the document"}
#
# Capybara already handles "the DOM moved under me" by retrying: `synchronize`
# re-runs the block for every error in `driver.invalid_element_errors`, which
# includes StaleElementReferenceError. Plain detach, navigation and whole
# document replacement all raise THAT error and are absorbed silently.
# Cross-document adoption is the one variant chromedriver reports as
# UnknownError instead, so it escapes the retry loop and fails the test — which
# is why this surfaced in CI as unrelated system tests erroring at random,
# always shortly after a Turbo navigation.
#
# Classifying it restores the behaviour Capybara already intends. Capybara does
# the same for InvalidSelectorError ("Work around chromedriver
# go_back/go_forward race condition"). It has to be the error CLASS because
# `catch_error?` matches with `is_a?`, so a message-scoped matcher is never
# consulted; a genuine persistent UnknownError therefore still fails the test,
# just after the query's wait expires rather than immediately.
module CapybaraRetryCrossDocumentNode
  def invalid_element_errors = super + [::Selenium::WebDriver::Error::UnknownError]
end
Capybara::Selenium::Driver.prepend(CapybaraRetryCrossDocumentNode)

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--window-size=1280,900")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :headless_chrome
Capybara.javascript_driver = :headless_chrome
Capybara.server = :puma, {Silent: true}
Capybara.default_max_wait_time = 5

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveRecord::TestFixtures

  # Disable transactional tests so the browser-driven Puma thread sees the
  # same rows the test process created. cleanup_test_data handles cleanup.
  self.use_transactional_tests = false

  include IntegrationTestHelper
  include SlimSelectHelpers

  driven_by :headless_chrome

  def login_as_admin_via_browser(admin)
    visit "/admins/login"
    fill_in "login", with: admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"
  end
end
