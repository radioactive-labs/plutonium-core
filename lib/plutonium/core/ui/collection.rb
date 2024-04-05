require "dry-initializer"

module Plutonium
  module Core
    module Ui
      class Collection
        extend Dry::Initializer

        option :resource_class
        option :records, default: proc { [] }
        option :fields, default: proc { {} }
        option :actions, default: proc { Plutonium::Core::Actions::Collection.new }
        option :pager, optional: true
        option :search_object, optional: true
      end
    end
  end
end
