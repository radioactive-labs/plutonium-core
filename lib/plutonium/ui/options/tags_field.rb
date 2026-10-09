# frozen_string_literal: true

module Plutonium
  module UI
    module Options
      # Detects no_fly_list `has_tags` contexts. A context named `labels`
      # defines a `labels` has_many (the tag records) next to the
      # `labels_list` proxy, so without this it infers as an association.
      # no_fly_list is optional: without the gem nothing is a tag field.
      module TagsField
        def self.context(object, key)
          return unless defined?(NoFlyList::TaggableRecord) && object.is_a?(NoFlyList::TaggableRecord)

          object.class._no_fly_list.tag_contexts[key.to_sym]
        end

        private

        def tags_field? = TagsField.context(object, key).present?
      end
    end
  end
end
