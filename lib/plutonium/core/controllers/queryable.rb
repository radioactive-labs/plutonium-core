module Plutonium
  module Core
    module Controllers
      module Queryable
        extend ActiveSupport::Concern

        def resource_query_object(resource_class, params)
          query_object_class = "#{resource_class}QueryObject".constantize
          query_object_class.new resource_context, params
        end

        def current_query_object
          @current_query_object ||= resource_query_object resource_class, params[:q]
        end
      end
    end
  end
end
