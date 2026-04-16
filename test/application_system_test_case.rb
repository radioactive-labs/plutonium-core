# frozen_string_literal: true

require "test_helper"
require "capybara/rails"
require "capybara/minitest"
require "selenium/webdriver"

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

  driven_by :headless_chrome

  def login_as_admin_via_browser(admin)
    visit "/admins/login"
    fill_in "login", with: admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"
  end
end
