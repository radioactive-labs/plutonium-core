module Plutonium
  module Reactor
    extend ActiveSupport::Autoload

    autoload :Core
    autoload :PolicyContext
    autoload :ResourceContext
    autoload :ResourceController
    autoload :ResourceInteraction
    autoload :ResourcePolicy
    autoload :ResourcePresenter
    autoload :ResourceQueryObject
    autoload :ResourceRecord
  end
end
