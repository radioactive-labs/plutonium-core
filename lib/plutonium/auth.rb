module Plutonium
  module Auth
    extend ActiveSupport::Autoload

    def self.rodauth(name)
      Rodauth.for(name)
    end

    autoload :Rodauth
  end
end
