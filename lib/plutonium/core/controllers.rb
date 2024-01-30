module Plutonium
  module Core
    module Controllers
      extend ActiveSupport::Autoload

      autoload :Bootable
      autoload :CrudActions
      autoload :EntityScoping
    end
  end
end
