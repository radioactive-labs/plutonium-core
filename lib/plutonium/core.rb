module Plutonium
  module Core
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Actions
      autoload :Controllers
      autoload :Fields
      autoload :Presenters
      autoload :UI
      autoload :Action
      autoload :AppController
    end
  end
end
