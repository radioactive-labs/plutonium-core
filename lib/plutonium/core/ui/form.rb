module Plutonium
  module Core
    module UI
      class Form
        extend Dry::Initializer

        option :record, optional: true
        option :inputs, default: proc { {} }
      end
    end
  end
end
