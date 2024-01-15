module Plutonium
  module Core
    module AppController
      extend ActiveSupport::Concern

      def resource_presenter(resource_class)
        presenter_class = "#{current_package}::#{resource_class}Presenter".constantize
        presenter_class.new resource_context, resource_class
      end

      def policy_namespace(scope)
        [current_package.to_s.underscore.to_sym, scope]
      end

      def build_sidebar_menu
        {
          resources: current_engine.resource_register.map { |resource|
                       [resource.pluralize, url_for(resource.constantize)]
                     }.to_h
        }
      end
    end
  end
end
