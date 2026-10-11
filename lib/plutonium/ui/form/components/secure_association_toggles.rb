# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Switch-styled {SecureAssociationCheckboxes}
        # (`input :tags, as: :association_toggles`). Same behavior; only the
        # `.pu-toggle` styling differs.
        class SecureAssociationToggles < SecureAssociationCheckboxes
          protected

          def control_theme = :association_toggle
        end
      end
    end
  end
end
