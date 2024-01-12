module Plutonium
  module Policy # :nodoc:
    extend ActiveSupport::Autoload

    autoload :Initializer
    autoload :Scope
    # autoload :AdminResourcePolicy
    # autoload :EntityResourcePolicy
  end
end
