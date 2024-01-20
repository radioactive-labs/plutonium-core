module Plutonium
  module Policy
    extend ActiveSupport::Autoload

    autoload :Initializer
    autoload :Scope
    # autoload :AdminResourcePolicy
    # autoload :EntityResourcePolicy
  end
end
