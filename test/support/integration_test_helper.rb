# frozen_string_literal: true

module IntegrationTestHelper
  extend ActiveSupport::Concern

  include AuthHelpers
  include DataHelpers

  included do
    teardown :cleanup_test_data
  end

  private

  def cleanup_test_data
    ActiveRecord::Base.with_connection do |connection|
      # Disable FK checks to avoid ordering issues during cleanup
      connection.execute("PRAGMA foreign_keys = OFF")

      UserProfile.delete_all
      Comment.delete_all
      Blogging::PostTag.delete_all
      Blogging::PostDetail.delete_all
      Catalog::ProductMetadata.delete_all
      Catalog::MorphDemo.delete_all
      Blogging::Post.delete_all
      Blogging::Tag.delete_all
      Catalog::Review.delete_all
      Catalog::ProductDetail.delete_all
      Catalog::Variant.delete_all
      Catalog::Product.delete_all
      Catalog::Category.delete_all
      OrganizationUser.delete_all
      Organization.delete_all
      NetworkDevice.delete_all

      # Clean Rodauth session/auth tables
      connection.execute("DELETE FROM user_remember_keys")
      connection.execute("DELETE FROM user_login_change_keys")
      connection.execute("DELETE FROM user_password_reset_keys")
      connection.execute("DELETE FROM user_verification_keys")
      connection.execute("DELETE FROM admin_active_session_keys")
      connection.execute("DELETE FROM admin_authentication_audit_logs")
      connection.execute("DELETE FROM admin_remember_keys")
      connection.execute("DELETE FROM admin_password_reset_keys")
      connection.execute("DELETE FROM admin_verification_keys")
      connection.execute("DELETE FROM admin_otp_keys")
      connection.execute("DELETE FROM admin_recovery_codes")
      connection.execute("DELETE FROM admin_lockouts")
      connection.execute("DELETE FROM admin_login_failures")
      User.delete_all
      Admin.delete_all

      connection.execute("PRAGMA foreign_keys = ON")
    end
  end
end
