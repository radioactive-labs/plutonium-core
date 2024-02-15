module Plutonium
  module Core
    module Actions
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :BasicAction
        autoload :Collection
        autoload :NewAction
        autoload :DestroyAction
        autoload :EditAction
        autoload :InteractiveAction
        autoload :ShowAction
      end
    end
  end
end
