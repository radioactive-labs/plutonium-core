module Plutonium
  module UI
    class Block < Plutonium::UI::Component::Base
      def view_template(&)
        raise ArgumentError, "Block requires a content block" unless block_given?

        div class: "relative bg-white dark:bg-gray-800 shadow-md sm:rounded-lg my-3" do
          yield
        end
      end
    end
  end
end
