# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Switch-styled boolean input (`input :notify, as: :toggle`). Identical
        # behavior to the checkbox; only the `.pu-toggle` styling differs.
        class Toggle < Phlexi::Form::Components::Checkbox
        end
      end
    end
  end
end
