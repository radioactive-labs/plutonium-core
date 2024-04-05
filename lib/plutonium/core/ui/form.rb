module Plutonium
  module Core
    module Ui
      class Form
        extend Dry::Initializer

        option :record, optional: true
        option :inputs, default: proc { {} }
      end
    end
  end
end
