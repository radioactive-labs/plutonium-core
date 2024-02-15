module Plutonium
  module Core
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Action
      autoload :Actions
      autoload :AppController
      autoload :Autodiscovery
      autoload :Controllers
      autoload :Definers
      autoload :Fields
      autoload :UI
    end
  end
end
