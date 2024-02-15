module Plutonium
  module Core
    module Definers
      module FieldDefiner
        extend ActiveSupport::Concern

        include InputDefiner
        include RendererDefiner

        private

        def define_field(name, type: nil, input: nil, renderer: nil, input_options: {}, renderer_options: {})
          define_input(name, type:, input:, **input_options)
          define_renderer(name, type:, renderer:, **renderer_options)
        end
      end
    end
  end
end
