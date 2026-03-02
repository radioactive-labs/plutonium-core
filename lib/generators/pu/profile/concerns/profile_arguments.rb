# frozen_string_literal: true

module Pu
  module Profile
    module Concerns
      module ProfileArguments
        extend ActiveSupport::Concern

        included do
          argument :name, type: :string, default: "Profile", required: false, banner: "NAME"
          argument :attributes, type: :array, default: [], banner: "field[:type] field[:type]"
        end

        # Normalize arguments: if name contains ":", treat it as an attribute
        def normalize_arguments
          if name.include?(":")
            @profile_attributes = [name, *attributes]
            @profile_name = "Profile"
          else
            @profile_name = name
            @profile_attributes = attributes
          end
        end
      end
    end
  end
end
