# frozen_string_literal: true

require "phlex"

module Plutonium
  module UI
    module Component
      module Behaviour
        extend ActiveSupport::Concern
        include Methods
        include Kit

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

          if arg.respond_to?(:render_in)
            render arg
          elsif arg.respond_to?(:call)
            instance_exec(&arg)
          else
            yield
          end
        end
      end
    end
  end
end
