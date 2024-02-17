module Plutonium
  module Auth
    extend ActiveSupport::Autoload

    def self.rodauth(name)
      Rodauth.for(name)
    end

    autoload :Rodauth
    autoload :PublicAccess
  end
end
