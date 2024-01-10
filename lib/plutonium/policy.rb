module Plutonium
  module Policy # :nodoc:
    extend ActiveSupport::Autoload

    autoload :Initializer
    autoload :Base
    # autoload :AdminResourcePolicy
    # autoload :EntityResourcePolicy
  end
end
