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
              collection = if @provided_choices || @skip_authorization
                @choice_collection
              else
                authorized_resource_scope(association_reflection.klass, relation: @choice_collection)
              end
              Phlexi::Form::ChoicesMapper.new(collection, label_method: @label_method, value_method: @value_method)
            end
          end

          def build_attributes
            @provided_choices = !attributes[:choices].nil?
            @skip_authorization = attributes.delete(:skip_authorization)

            super
          end
        end
      end
    end
  end
end
