module Plutonium
  module Core
    module UI
      Detail = Data.define :resource_class, :record, :fields, :actions do
        def initialize(resource_class:, record: nil, fields: {}, actions: Plutonium::Core::Actions::Collection.new)
          super
        end
      end
    end
  end
end
