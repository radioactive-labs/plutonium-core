# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Preloads the associations and attachments a collection is about to
      # render, without being told which.
      #
      # Plutonium can do this where a general-purpose Rails app cannot. The
      # rendered field set is DECLARED — resolved from the policy — rather than
      # discovered by running a template, and resolving it never touches the
      # collection. So the exact set of associations a page will read is known
      # before the query is built. There is no `includes` list to write, and none
      # to keep in step with the definition as fields come and go.
      #
      # Every collection rendering passes its OWN field set, because they differ:
      # the index renders `presentable_attributes`, the CSV export renders
      # `permitted_attributes_for_export`, and a kanban card renders its
      # `card_fields` (falling back to the grid fields). Reading one action's
      # fields from another's code path resolves the wrong policy method.
      module EagerLoading
        extend ActiveSupport::Concern

        private

        # Whether this controller preloads what it is about to render.
        # Override to opt a single resource out (or in, against a global off).
        # @return [Boolean]
        def auto_eager_load_index?
          Plutonium.configuration.auto_eager_load_index
        end

        # @param collection [ActiveRecord::Relation]
        # @param fields [Array<Symbol>] the field set about to be rendered
        # @return [ActiveRecord::Relation]
        def auto_eager_load(collection, fields)
          return collection unless auto_eager_load_index?

          fields = Array(fields).map(&:to_sym)

          associations = fields & eager_loadable_associations
          collection = collection.includes(*associations) if associations.any?

          # Attachments are not associations under their declared name: for BOTH
          # backends `reflect_on_association(:file)` is nil, and the reflections
          # that exist are `file_attachment`/`file_blob`. `with_attached_*` is the
          # supported preload and ActiveStorage and active_shrine both expose it,
          # so one path serves both.
          (fields & eager_loadable_attachments).each do |name|
            collection = collection.public_send(:"with_attached_#{name}")
          end

          collection
        end

        # `belongs_to` and `has_one` only. `has_many` is deliberately excluded:
        # preloading one to render a count loads every child row, which loses to a
        # counter cache, and the row count is unbounded in a way a single parent
        # is not.
        #
        # Both lists are memoised on the model (outside dev) by
        # Resource::Record::FieldNames. Its `has_one` list already strips the
        # `_attachment`/`_blob` reflections backing an attachment, so those cannot
        # be loaded twice by the two branches above. Its attachment lists go
        # through `reflect_on_all_attachments`, which — unlike
        # `attachment_reflections`, empty under active_shrine — reports both
        # backends.
        def eager_loadable_associations
          @eager_loadable_associations ||=
            resource_class.belongs_to_association_field_names +
            resource_class.has_one_association_field_names
        end

        def eager_loadable_attachments
          @eager_loadable_attachments ||=
            resource_class.has_one_attached_field_names +
            resource_class.has_many_attached_field_names
        end
      end
    end
  end
end
