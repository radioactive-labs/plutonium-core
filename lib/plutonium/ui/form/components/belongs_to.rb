# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class BelongsTo < Phlexi::Form::Components::BelongsTo
          include Plutonium::UI::Component::Methods

          private

          def build_attributes
            @skip_authorization = attributes.delete(:skip_authorization)
            unless @skip_authorization || attributes[:choices]
              attributes[:choices] = authorized_resource_scope(association_reflection.klass, relation: field.choices)
            end

            super
          end
        end
      end
    end
  end
end
