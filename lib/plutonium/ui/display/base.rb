# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Base < Phlexi::Display::Base
        include Plutonium::UI::Component::Behaviour

        private

        def fields_wrapper(&)
          div(class: "relative bg-white dark:bg-gray-800 shadow-md sm:rounded-lg my-3") {
            div(class: "p-6 grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-3 gap-6") {
              yield
            }
          }
        end
      end
    end
  end
end
