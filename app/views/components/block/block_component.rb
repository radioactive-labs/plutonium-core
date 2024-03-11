module Plutonium::UI
  class BlockComponent < Plutonium::UI::Base
    option :rounded, optional: true
    option :scroll, optional: true
    option :classes, optional: true

    private

    def classnames
      classnames = Array(classes)
      classnames << rounded_classes
      classnames << scroll_classes
      classnames.join " "
    end

    def scroll_classes
      case scroll
      when :x
        "overflow-x-auto"
      when :y
        "overflow-y-auto"
      when :both
        "overflow-auto"
      else
        "overflow-hidden"
      end
    end

    def rounded_classes
      case rounded
      when :top
        "sm:rounded-t-lg mt-3"
      when :bottom
        "sm:rounded-b-lg mb-3"
      when :all
        "sm:rounded-lg my-3"
      end
    end
  end
end

Plutonium::ComponentRegistry.register :block, to: Plutonium::UI::BlockComponent
