module Plutonium
  module Core
    module Associations
      module Renderers
        class BasicRenderer
          attr_reader :name, :label, :reflection, :user_options

          def initialize(name, label:, reflection:, **user_options)
            @name = name
            @label = label
            @reflection = reflection
            @user_options = user_options
          end

          def render(view_context, record)
            raise NotImplementedError
          end

          def options = @options ||= renderer_options.deep_merge(@user_options)

          private

          def renderer_options = {}
        end
      end
    end
  end
end
