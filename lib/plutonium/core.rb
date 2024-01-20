module Plutonium
  module Core
    extend ActiveSupport::Autoload

    autoload :AppController
    autoload :FeatureController
    autoload :ResourceContext
    autoload :ResourceContextScope
    autoload :Controller
  end
end
