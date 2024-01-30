module Plutonium
  module Core
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Fields
      autoload :Controllers
      autoload :Presenters
      autoload :AppController
    end
  end
end
