module Plutonium
  module Core
    module UI
      Collection = Data.define :resource_class, :records, :fields, :actions, :pager, :search_object do
        def initialize(
          resource_class:, records: [], fields: {}, actions: Plutonium::Core::Actions::Collection.new,
          pager: nil, search_object: nil
        )
          super
        end
      end
    end
  end
end
