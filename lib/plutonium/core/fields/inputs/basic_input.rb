module Plutonium
  module Core
    module Fields
      module Inputs
        class BasicInput < Plutonium::Core::Fields::Input
          def render(f, record)
            f.input name, **options
          end
        end
      end
    end
  end
end
