module Plutonium
  module Core
    module Actions
      class Collection
        delegate_missing_to :@collection

        def initialize(collection = {})
          @collection = collection
        end

        def permitted_for(policy)
          Collection.new(@collection.select { |name, action| policy.send :"#{action.name}?" })
        end

        def collection_actions
          Collection.new(@collection.select { |name, action| action.collection_action? })
        end

        def collection_record_actions
          Collection.new(@collection.select { |name, action| action.collection_record_action? })
        end

        def record_actions
          Collection.new(@collection.select { |name, action| action.record_action? })
        end

        def bulk_actions
          Collection.new(@collection.select { |name, action| action.bulk_action? })
        end
      end
    end
  end
end
