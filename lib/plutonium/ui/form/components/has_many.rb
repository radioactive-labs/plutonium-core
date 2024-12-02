# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class HasMany < Phlexi::Form::Components::HasMany
          include Plutonium::UI::Component::Methods

          private

          def choices
            @choices ||= begin
              collection = authorized_resource_scope(association_reflection.klass, relation: @choice_collection)
              Phlexi::Form::ChoicesMapper.new(collection, label_method: @label_method, value_method: @value_method)
            end
          end
        end
      end
    end
  end
end
