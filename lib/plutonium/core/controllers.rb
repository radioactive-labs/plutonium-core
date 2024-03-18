module Plutonium
  module Core
    module Controllers
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Authorizable
        autoload :Base
        autoload :Bootable
        autoload :CrudActions
        autoload :EntityScoping
        autoload :InteractiveActions
        autoload :Presentable
        autoload :Queryable
      end
    end
  end
end
