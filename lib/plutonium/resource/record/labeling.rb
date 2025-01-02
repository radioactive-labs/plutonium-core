# frozen_string_literal: true

# lib/plutonium/resource/associations.rb
module Plutonium
  module Resource
    module Record
      module Labeling
        def to_label
          %i[name title].each do |method|
            name = send(method) if respond_to?(method)
            return name if name.present?
          end

          "#{model_name.human} ##{to_param}"
        end
      end
    end
  end
end
