module Plutonium
  module Core
    module Actions
      class BasicAction < Plutonium::Core::Action
        def initialize(*args, **kwargs)
          kwargs.reverse_merge! action_options
          super(*args, **kwargs)
        end

        private

        def action_options = {}
      end
    end
  end
end
