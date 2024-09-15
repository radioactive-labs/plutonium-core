# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Base < Phlexi::Display::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          def association_tag(**, &)
            create_component(Plutonium::UI::Display::Component::Association, :association, **, &)
          end
        end

        private

        def fields_wrapper(&)
          div(class: themed(:fields_wrapper)) {
            yield
          }
        end
      end
    end
  end
end