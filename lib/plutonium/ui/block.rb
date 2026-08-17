module Plutonium
  module UI
    # A plain card surface to wrap arbitrary content in.
    #
    # This is THE card primitive — it renders `pu-card` rather than hand-rolling
    # a surface. It used to paint its own background, radius and
    # `--pu-shadow-md` inline, which left it subtly out of step with every
    # `pu-card` on the page: no border, and a heavier shadow. Anything wrapping
    # a `pu-card` in a Block then stacked two cards and got a doubled shadow,
    # while anything wrapping bare content got a borderless one — which is why
    # the show page's details and its metadata rail used to sit on visibly
    # different surfaces.
    #
    # It carries no outer margin: spacing between cards belongs to whatever
    # stacks them (a `space-y-*` container), not to the card itself, so a
    # single Block can't decide the rhythm of a list it doesn't know it's in.
    # Extra classes may be merged in (`Block(class: "overflow-hidden")`) so a
    # caller can adjust the card without re-declaring what a card is.
    class Block < Plutonium::UI::Component::Base
      def initialize(**options)
        @class = options[:class]
      end

      def view_template(&)
        raise ArgumentError, "Block requires a content block" unless block_given?

        div class: tokens("relative pu-card", @class) do
          yield
        end
      end
    end
  end
end
