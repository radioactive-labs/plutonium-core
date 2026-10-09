# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Chip input for a no_fly_list `has_tags` context. Suggests the tags
        # that already exist in the record's tag scope (its tenant), follows
        # the context's `restrict_to_existing` and `limit`, and submits to the
        # `<context>_list` writer.
        class Tags < List
          SUGGESTION_LIMIT = 200

          protected

          def build_attributes
            context = Plutonium::UI::Options::TagsField.context(field.object, field.key)
            attributes[:input_param] ||= :"#{field.key}_list"
            attributes[:addable] = !context[:restrict_to_existing] unless attributes.key?(:addable)
            attributes[:limit] ||= context[:limit]
            attributes[:suggestions] ||= existing_tags(context)
            super
          end

          # The proxy, not the association: on a failed save it still holds
          # what was submitted.
          def current_values
            field.object.public_send(:"#{field.key}_list").to_a
          end

          private

          def existing_tags(context)
            tags = context[:tag_class_name].constantize.order(:name).limit(SUGGESTION_LIMIT)
            if (scope = context[:scope])
              column = field.object.class.reflect_on_association(scope)&.foreign_key || scope
              tags = tags.where(column => field.object[column])
            end
            tags.pluck(:name)
          end
        end
      end
    end
  end
end
