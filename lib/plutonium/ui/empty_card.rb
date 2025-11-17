module Plutonium
  module UI
    class EmptyCard < Plutonium::UI::Component::Base
      attr_accessor :message

      def initialize(message)
        @message = message
      end

      def view_template
        div(class: tokens(
          theme_class(:card, variant: :empty),
          "relative bg-surface dark:bg-surface-dark shadow-md sm:rounded-sm"
        )) do
          div(class: "p-lg flex items-center flex-col gap-sm") do
            p(class: "text-gray-500 sm:text-lg dark:text-gray-200 text-center") { message }
            yield if block_given?
          end
        end
      end
    end
  end
end
