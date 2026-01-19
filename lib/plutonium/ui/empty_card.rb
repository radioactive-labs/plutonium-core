module Plutonium
  module UI
    class EmptyCard < Plutonium::UI::Component::Base
      attr_accessor :message

      def initialize(message)
        @message = message
      end

      def view_template
        div(class: "pu-card") do
          div(class: "pu-empty-state") do
            p(class: "pu-empty-state-description") { message }
            yield if block_given?
          end
        end
      end
    end
  end
end
