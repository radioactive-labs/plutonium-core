module Plutonium
  module UI
    class Block < Plutonium::UI::Component::Base
      def view_template(&)
        raise ArgumentError, "Block requires a content block" unless block_given?

        div class: tokens(
          theme_class(:block),
          "relative bg-surface dark:bg-surface-dark shadow-md sm:rounded-sm my-sm"
        ) do
          yield
        end
      end
    end
  end
end
