# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Select for choosing a resource record
        class ResourceSelect < Phlexi::Form::Components::Select
          protected

          def choices
            @choices ||= begin
              collection = attributes.delete(:choices) || @association_class&.all || []
              build_choice_mapper(collection)
            end
          end

          def build_attributes
            super
            @association_class = attributes.delete(:association_class)
          end

          # Use include_blank string as blank option text (Phlexi default uses placeholder)
          def blank_option_text
            @include_blank.is_a?(String) ? @include_blank : super
          end
        end
      end
    end
  end
end
