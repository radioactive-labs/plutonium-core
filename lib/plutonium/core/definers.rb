module Plutonium
  module Core
    module Definers
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :ActionDefiner
        autoload :FieldDefiner
        autoload :InputDefiner
        autoload :RendererDefiner
      end
    end
  end
end
