# frozen_string_literal: true

module AuthHelpers
  def login_as_user(user = nil)
    user ||= @user
    post "/users/login", params: {email: user.email, password: "password123"}
    follow_redirect! if response.redirect?
  end

  def login_as_admin(admin = nil)
    admin ||= @admin
    post "/admins/login", params: {email: admin.email, password: "password123"}
    follow_redirect! if response.redirect?
  end

  def logout_user
    post "/users/logout"
    follow_redirect! if response.redirect?
  end

  def logout_admin
    post "/admins/logout"
    follow_redirect! if response.redirect?
  end
end
