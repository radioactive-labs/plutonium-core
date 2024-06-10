module Plutonium
  module Core
    module Renderable
      extend ActiveSupport::Concern

      included do
        delegate_missing_to :@view_context
      end

      def render_in(view_context)
        @view_context = view_context
        render
      end

      def render
        raise NotImplementedError, "#{self.class}#render"
      end
    end
  end
end
