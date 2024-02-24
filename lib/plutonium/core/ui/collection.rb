module Plutonium
  module Core
    module UI
      Collection = Data.define :resource_class, :records, :fields, :actions, :pager, :search_object, :search_field do
        def initialize(
          resource_class:, records: [], fields: {}, actions: Plutonium::Core::Actions::Collection.new,
          pager: nil, search_object: nil, search_field: nil
        )
          super
        end
      end
    end
  end
end
