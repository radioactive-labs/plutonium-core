module Plutonium
  module Core
    module Presenters
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :FieldDefinitions
      end
    end
  end
end
