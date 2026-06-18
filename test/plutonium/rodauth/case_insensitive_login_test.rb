# frozen_string_literal: true

require "test_helper"

# Regression coverage for the case_insensitive_login Rodauth feature.
#
# The feature must downcase logins on INPUT (account creation) as well as on
# LOOKUP (account_from_login). The dummy app's :user config enables both
# case_insensitive_login and internal_request, so we drive it through the
# Internal Request API on a case-sensitive backend (SQLite).
class Plutonium::Rodauth::CaseInsensitiveLoginTest < ActiveSupport::TestCase
  def teardown
    User.where("lower(email) = ?", "mixedcase.regression@example.com").destroy_all
  end

  test "create_account downcases a mixed-case login on input" do
    mixed = "MixedCase.Regression@Example.com"

    RodauthApp.rodauth(:user).create_account(login: mixed, password: "password123")

    stored = User.where("lower(email) = ?", mixed.downcase).pick(:email)
    assert_equal mixed.downcase, stored,
      "expected the stored login to be normalized to lowercase on input"
  end

  test "an account created with a mixed-case login can be looked up by that login" do
    mixed = "MixedCase.Regression@Example.com"

    RodauthApp.rodauth(:user).create_account(login: mixed, password: "password123")

    instance = RodauthApp.rodauth(:user).allocate
    account = instance.account_from_login(mixed)

    refute_nil account,
      "account_from_login must find the account even when the input differs in case"
  end
end
