module Plutonium
  module Core
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Action
      autoload :Actions
      autoload :Autodiscovery
      autoload :Controllers
      autoload :Definers
      autoload :Fields
      autoload :UI
    end
  end
end
