# frozen_string_literal: true

module Pu
  module Profile
    module Concerns
      module ProfileArguments
        extend ActiveSupport::Concern

        included do
          argument :name, type: :string, required: false, banner: "NAME"
          argument :attributes, type: :array, default: [], banner: "field[:type] field[:type]"
        end

        # Normalize arguments: if name is omitted, default to "{UserModel}Profile";
        # if name looks like an attribute (contains ":"), treat it as an attribute
        # and still default the profile name to "{UserModel}Profile".
        def normalize_arguments
          default_name = "#{options[:user_model] || "User"}Profile"
          if name.nil?
            @profile_name = default_name
            @profile_attributes = attributes
          elsif name.include?(":")
            @profile_attributes = [name, *attributes]
            @profile_name = default_name
          else
            @profile_name = name
            @profile_attributes = attributes
          end
        end
      end
    end
  end
end
