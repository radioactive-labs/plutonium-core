# frozen_string_literal: true

require "application_system_test_case"

# Guards the harness patch in application_system_test_case.rb.
#
# Turbo Drive adopts each new body into the live document, and a Capybara query
# mid-flight when that lands gets chromedriver's
# UnknownError("Node with given id does not belong to the document") instead of
# the StaleElementReferenceError every other DOM-moved-under-me case raises.
# Capybara retries the latter and not the former, so the harness classifies it
# as retryable. If that patch is dropped, unrelated system tests start failing
# at random after a navigation — a very expensive thing to re-diagnose, hence
# this test.
#
# Deliberately driver-level and browser-free: the real condition is a race, so
# asserting on it directly would itself be flaky.
class CapybaraRetryClassificationTest < ActiveSupport::TestCase
  def driver = Capybara::Selenium::Driver.new(nil, browser: :chrome)

  test "the cross-document node error is classified retryable" do
    assert_includes driver.invalid_element_errors,
      ::Selenium::WebDriver::Error::UnknownError,
      "chromedriver reports Turbo's cross-document adoption as UnknownError; " \
      "without it in this list Capybara's synchronize loop fails instead of retrying"
  end

  # The patch must ADD to Capybara's list, never replace it — dropping the
  # stale-element error would break the ordinary retry path.
  test "the stock retryable errors are preserved" do
    errors = driver.invalid_element_errors

    assert_includes errors, ::Selenium::WebDriver::Error::StaleElementReferenceError
    assert_includes errors, ::Selenium::WebDriver::Error::ElementNotInteractableError
    assert_includes errors, ::Selenium::WebDriver::Error::ElementClickInterceptedError
  end

  # Capybara's catch_error? uses `error.is_a?(type)`, so only real classes in
  # the list are ever consulted. This pins the assumption the patch rests on:
  # if it ever changed to `===`, a precise message-scoped matcher would be
  # possible and preferable to whitelisting the whole class.
  test "catch_error? matches by is_a?, which is why the whole class is listed" do
    source = Capybara::Node::Base.instance_method(:catch_error?).source_location
    body = File.read(source.first).lines[(source.last - 1), 6].join

    assert_includes body, "is_a?",
      "if this became `===`, narrow the patch to the cross-document message"
  end
end
