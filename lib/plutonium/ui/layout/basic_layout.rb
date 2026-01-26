module Plutonium
  module UI
    module Layout
      class BasicLayout < Base
        private

        def page_title
          make_page_title(
            controller.instance_variable_get(:@page_title)
          )
        end
      end
    end
  end
end
