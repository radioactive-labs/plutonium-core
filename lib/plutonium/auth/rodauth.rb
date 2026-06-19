module Plutonium
  module Auth
    module Rodauth
      def self.for(name)
        mod = Module.new
        mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
          extend ActiveSupport::Concern

          included do
            helper_method :current_user
            helper_method :logout_url
            helper_method :profile_url
          end

          private

          def rodauth(name = :#{name})
            instance = super(name)
            instance.url_options = default_url_options.presence
            instance
          end

          def current_user
            rodauth.rails_account
          end

          def logout_url
            rodauth.logout_path
          end

          # Override this method to return your profile page URL.
          # When defined, a "Profile" link will appear in the user menu.
          # Example: rodauth.change_password_path or your custom profile_path
          def profile_url
            nil
          end

          define_singleton_method(:to_s) { "Plutonium::Auth::Rodauth(:#{name})" }
          define_singleton_method(:inspect) { "Plutonium::Auth::Rodauth(:#{name})" }
        RUBY
        mod
      end
    end
  end
end
