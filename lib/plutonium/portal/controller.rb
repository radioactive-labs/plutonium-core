module Plutonium
  module Portal
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Core::Controllers::Base

      # private

      # # Menu Builder
      # def build_namespace_node(namespaces, resource, parent)
      #   current = namespaces.shift
      #   if namespaces.size.zero?
      #     parent[current.pluralize] = url_for(resource_url_for(resource, parent: nil))
      #   else
      #     parent[current] = {}
      #     build_namespace_node(namespaces, resource, parent[current])
      #   end
      #   # parent.sort!
      # end

      # def build_namespace_tree(resources)
      #   root = {}
      #   resources.each do |resource|
      #     namespaces = resource.name.split("::")
      #     build_namespace_node(namespaces, resource, root)
      #   end
      #   root
      # end

      # def build_sidebar_menu
      #   build_namespace_tree(current_engine.resource_register)
      # end
    end
  end
end
