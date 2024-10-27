module Plutonium
  module Resource
    module Controllers
      module Defineable
        extend ActiveSupport::Concern

        included do
          helper_method :current_definition, :resource_definition
        end

        private

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
