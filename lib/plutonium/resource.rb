module Plutonium
  module Resource
    extend ActiveSupport::Autoload

    autoload :ResourceContext
    autoload :ResourceController
    autoload :ResourceInteraction
    autoload :ResourcePolicy
    autoload :ResourcePresenter
    autoload :ResourceQueryObject
    autoload :ResourceRecord
  end
end
