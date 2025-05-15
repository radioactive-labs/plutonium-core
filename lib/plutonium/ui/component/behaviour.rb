# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      module Behaviour
        extend ActiveSupport::Concern
        include Methods
        include Kit
        include Tokens

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
