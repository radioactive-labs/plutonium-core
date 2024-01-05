require "rails/engine"

module Plutonium
  module App
    extend ActiveSupport::Concern

    included do
      isolate_namespace to_s.deconstantize.constantize
    end

    module ClassMethods
      def register_resource(resource)
        @resource_register ||= []
        @resource_register << resource
      end

      def resource_register
        @resource_register || []
      end

      def draw_resource_routes
        registered_resources = resource_register
        routes.draw do
          registered_resources.each do |resource|
            resources resource.underscore.pluralize
          end
        end
      end
    end
  end
end
