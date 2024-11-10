require "rodauth"

module Rodauth
  Feature.define(:case_insensitive_login, :CaseInsensitiveLogin) do
    def param(key)
      value = super
      value&.downcase! if [login_param, login_confirm_param].include?(key)
      value
    end

    def account_from_login(login)
      super(login&.downcase)
    end
  end
end
