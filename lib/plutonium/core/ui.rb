module Plutonium
  module Core
    module UI
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Collection
        autoload :Detail
        autoload :Form
      end
    end
  end
end
