module Rodauth
  class UserController < RodauthController
    # used by Rodauth for rendering views, CSRF protection, and running any
    # registered action callbacks and rescue_from handlers

    private

    def current_account
      rodauth.rails_account
    end

    def rodauth(name = :user)
      super
    end
  end
end
