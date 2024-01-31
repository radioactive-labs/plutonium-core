module Plutonium
  module Core
    module Presenters
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :ActionDefinitions
        autoload :FieldDefinitions
        autoload :InputDefinitions
        autoload :RendererDefinitions
      end
    end
  end
end
