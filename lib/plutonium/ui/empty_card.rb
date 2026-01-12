module Plutonium
  module UI
    class EmptyCard < Plutonium::UI::Component::Base
      attr_accessor :message

      def initialize(message)
        @message = message
      end

      def view_template
        div(class: "relative bg-white dark:bg-gray-800 shadow-md") do
          div(class: "p-6 flex items-center flex-col gap-2") do
            p(class: "text-gray-500 sm:text-lg dark:text-gray-200 text-center") { message }
            yield if block_given?
          end
        end
      end
    end
  end
end
