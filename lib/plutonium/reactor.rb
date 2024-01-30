module Plutonium
  module Reactor
    extend ActiveSupport::Autoload

    autoload :Engine
    autoload :ResourceContext
    autoload :ResourceController
    autoload :ResourceInteraction
    autoload :ResourcePolicy
    autoload :ResourcePresenter
    autoload :ResourceRecord
  end
end
