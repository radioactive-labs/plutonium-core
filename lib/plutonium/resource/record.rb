module Plutonium
  module Resource
    module Record
      extend ActiveSupport::Concern

      include Plutonium::Models::HasCents
      include Plutonium::Resource::Record::Routes
      include Plutonium::Resource::Record::Labeling
      include Plutonium::Resource::Record::FieldNames
      include Plutonium::Resource::Record::Associations
      include Plutonium::Resource::Record::AssociatedWith
    end
  end
end
