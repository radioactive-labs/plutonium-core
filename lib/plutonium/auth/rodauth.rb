module Plutonium
  module Auth
    module Rodauth
      def self.for(name)
        mod = Module.new
        mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
          extend ActiveSupport::Concern

          included do
            prepend_before_action :authenticate
            helper_method :current_user
            helper_method :logout_url
          end

          private

          def rodauth(name = :#{name})
            super(name)
          end

          def authenticate
            rodauth.require_account
          end

          def current_user
            rodauth.rails_account
          end

          def logout_url
            rodauth.logout_path
          end

          define_singleton_method(:to_s) { "Plutonium::Auth::Rodauth(:#{name})" }
          define_singleton_method(:inspect) { "Plutonium::Auth::Rodautht(:#{name})" }
        RUBY
        mod
      end
    end
  end
end
