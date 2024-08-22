using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Resource
    module Controllers
      module Defineable
        extend ActiveSupport::Concern

        def resource_definition(resource_class)
          definition_class = "#{resource_class}Definition".constantize
          definition_class.new
        end

        def current_definition
          @current_definition ||= resource_definition resource_class
        end
      end
    end
  end
end
