module Plutonium
  module UI
    class Block < Plutonium::UI::Component::Base
      def view_template(&)
        raise ArgumentError, "Block requires a content block" unless block_given?

        div class: "relative bg-[var(--pu-surface)] rounded-[var(--pu-radius-lg)] my-3", style: "box-shadow: var(--pu-shadow-md)" do
          yield
        end
      end
    end
  end
end
