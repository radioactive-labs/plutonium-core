# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # A free-form card. The block is `instance_exec`ed here, in Phlex, so it
      # emits markup directly (`ul { ... }`, `render SomeComponent.new`); any
      # method it calls that this component lacks is forwarded to the
      # dashboard instance, so a dashboard's own helpers and `current_user`
      # are in scope.
      class Custom < Card
        private

        def render_body
          instance_exec(&card.block)
        end

        def method_missing(name, ...)
          if dashboard.respond_to?(name, true)
            dashboard.send(name, ...)
          else
            super
          end
        end

        def respond_to_missing?(name, include_private = false)
          dashboard.respond_to?(name, true) || super
        end
      end
    end
  end
end
