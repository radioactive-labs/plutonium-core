module Plutonium
  module Core # :nodoc:
    extend ActiveSupport::Autoload

    autoload :ResourcePolicy
    autoload :ResourceController
    autoload :ResourceRecord
    autoload :ResourceInteraction
    autoload :ResourcePresenter
    autoload :ResourceContext
    autoload :Controller
  end
end
