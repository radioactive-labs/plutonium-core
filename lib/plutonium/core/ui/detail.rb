module Plutonium
  module Core
    module UI
      class Detail
        extend Dry::Initializer

        option :resource_class
        option :record, optional: true
        option :fields, default: proc { {} }
        option :associations, default: proc { {} }
        option :actions, default: proc { Plutonium::Core::Actions::Collection.new }
      end
    end
  end
end
