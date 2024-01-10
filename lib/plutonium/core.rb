module Plutonium
  module Core # :nodoc:
    extend ActiveSupport::Autoload

    autoload :ResourcePolicy
    autoload :ResourceController
    autoload :ResourceRecord
    autoload :ResourceInteraction
    autoload :ResourcePresenter
  end
end
