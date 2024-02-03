module Plutonium
  module Core
    module Fields
      module Renderers
        class BasicRenderer
          attr_reader :name, :label, :user_options

          def initialize(name, label:, **user_options)
            @name = name
            @label = label
            @user_options = user_options
          end

          def render(view_context, record)
            view_context.display_field value: record.send(name), **options
          end

          def options = @options ||= renderer_options.deep_merge(@user_options)

          private

          def renderer_options = {}.freeze

        end
      end
    end
  end
end
