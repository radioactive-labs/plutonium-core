# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class Easymde < Phlexi::Form::Components::Base
          include Phlexi::Form::Components::Concerns::HandlesInput

          def view_template
            textarea(**attributes, data_controller: "easymde") { field.dom.value }
          end
        end
      end
    end
  end
end
