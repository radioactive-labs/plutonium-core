module Plutonium
  module Core
    module Controllers
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Authorizable
        autoload :Bootable
        autoload :CrudActions
        autoload :EntityScoping
        autoload :Presentable
      end
    end
  end
end
