module Plutonium
  module Core
    module Fields
      class Renderer
        class << self
          def for_resource_attribute(resource_class, attr_name, type: nil, **)
            Plutonium::Core::Fields::Renderers::BasicRenderer.new(resource_class, attr_name, **)
          end
        end

        attr_reader :resource_class, :name, :label, :user_options

        def initialize(resource_class, name, label: nil, **user_options)
          @resource_class = resource_class
          @name = name
          @label = label || resource_class.human_attribute_name(name)
          @user_options = user_options
        end

        def renderer_options = {}.freeze

        def options = @options ||= renderer_options.deep_merge(@user_options)

        def render(view_context, record) = raise NotImplementedError, "#{self.class} must implement #render"
      end
    end
  end
end
