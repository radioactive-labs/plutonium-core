module Plutonium
  module Core # :nodoc:
    extend ActiveSupport::Autoload

    autoload :ResourcePolicy
    autoload :ResourceController
    autoload :AppController
    autoload :FeatureController
    autoload :ResourceRecord
    autoload :ResourceInteraction
    autoload :ResourcePresenter
    autoload :ResourceContext
    autoload :ResourceContextScope
    autoload :Controller
  end
end
