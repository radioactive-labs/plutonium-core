# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # A `has_rich_text` field, rendered through Action Text's own helper:
        # Trix by default, Lexxy once the app adds the lexxy gem (which takes
        # over the helper). The editor's JS comes from the app's bundle.
        class RichText < Phlexi::Form::Components::Base
          include Phlexi::Form::Components::Concerns::HandlesInput

          def view_template
            raw(safe(helpers.rich_text_area_tag(attributes[:name], field.value, id: attributes[:id], required: attributes[:required])))
          end
        end
      end
    end
  end
end
