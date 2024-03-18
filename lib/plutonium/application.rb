module Plutonium
  module Application
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Controller
    end
  end
end
