module Plutonium
  module Auth
    def self.rodauth(name)
      Rodauth.for(name)
    end
  end
end
