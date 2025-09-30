require "rodauth"

# A plugin to enable case insensitive logins on Rodauth.
# It does that by downcasing any login inputs.
# Should not be enabled on existing installations unless logins are downcased in the database.
# See https://github.com/jeremyevans/rodauth/discussions/451
module Rodauth
  Feature.define(:case_insensitive_login, :CaseInsensitiveLogin) do
    def param(key)
      logins = [login_param]
      logins << login_confirm_param if respond_to?(:login_confirm_param)

      if [logins].include?(key)
        super.downcase
      else
        super
      end
    end

    def account_from_login(login)
      super(login.downcase)
    end
  end
end
