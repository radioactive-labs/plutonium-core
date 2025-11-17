# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      module Behaviour
        extend ActiveSupport::Concern
        include Phlexi::Field::Common::Tokens
        include Methods
        include Kit
        include Tokens

        # Generate custom CSS class for theming
        # @example
        #   theme_class(:button) # => "pu-button"
        #   theme_class(:button, variant: :table) # => "pu-button-table"
        def theme_class(component, variant: nil, element: nil)
          Theme.custom_class(component, variant:, element:)
        end

        if Rails.env.development?
          def around_template(&)
            comment { "open:#{self.class.name}" }
            super
            comment { "close:#{self.class.name}" }
          end
        end

        protected

        def phlexi_render(arg, &)
          return unless arg
          raise ArgumentError, "phlexi_render requires a default render block" unless block_given?

          # Handle Phlex components or Rails Renderables
          if arg.class < Phlex::SGML || arg.respond_to?(:render_in)
            render arg
          # Handle procs
          elsif arg.respond_to?(:to_proc)
            instance_exec(&arg)
          else
            yield arg
          end
        end
      end
    end
  end
end
