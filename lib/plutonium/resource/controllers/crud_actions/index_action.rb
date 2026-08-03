module Plutonium
  module Resource
    module Controllers
      module CrudActions
        module IndexAction
          extend ActiveSupport::Concern

          private

          def setup_index_action!
            # Applied HERE, not inside filtered_resource_collection: what to
            # preload depends on what is about to be RENDERED, and
            # filtered_resource_collection is shared with the CSV export, which
            # renders a different column set (`permitted_attributes_for_export`).
            # Reading the index's fields in there resolved the wrong policy
            # method for that action and raised. Keeping the hook to filtering and
            # eager-loading at the point of use also leaves an app's own
            # `filtered_resource_collection` override unaffected.
            collection = auto_eager_load(filtered_resource_collection, presentable_attributes)
            @pagy, @resource_records = pagy(:offset, collection)
          end

          def filtered_resource_collection
            query_params = current_definition
              .query_form.new(nil, query_object: current_query_object, page_size: nil)
              .extract_input(params, view_context:)[:q]

            base_query = current_authorized_scope
            current_query_object.apply(base_query, query_params, context: self)
          end

          # Whether this controller preloads what its index is about to render.
          # Override to opt a single resource out (or in, against a global off).
          # @return [Boolean]
          def auto_eager_load_index?
            Plutonium.configuration.auto_eager_load_index
          end

          # Preload the associations and attachments the index will render.
          #
          # Plutonium can do this unprompted where a general-purpose Rails app
          # cannot: the rendered column set is DECLARED — the policy's permitted
          # attributes, less parent/entity fields — rather than discovered by
          # running a template, and resolving it never touches the collection. So
          # by the time this runs the exact set of associations the page will read
          # is already known. There is no `includes` list to write, and none to
          # keep in step with the definition as columns come and go.
          #
          # `belongs_to` and `has_one` only. `has_many` is deliberately excluded:
          # preloading one to render a count loads every child row, which loses to
          # a counter cache, and the row count is unbounded in a way a single
          # parent is not.
          # @param fields [Array<Symbol>] the field set about to be rendered.
          #   Passed in rather than read here, so the same mechanism can serve any
          #   action that renders a collection (the CSV export is the obvious next
          #   one — it streams every row, so its N+1 is the worst of the lot).
          def auto_eager_load(collection, fields)
            return collection unless auto_eager_load_index?

            associations = fields & eager_loadable_associations
            collection = collection.includes(*associations) if associations.any?

            # Attachments are not associations under their declared name: for BOTH
            # backends `reflect_on_association(:file)` is nil, and the reflections
            # that exist are `file_attachment`/`file_blob`. `with_attached_*` is
            # the supported preload and ActiveStorage and active_shrine both expose
            # it, so one path serves both.
            (fields & eager_loadable_attachments).each do |name|
              collection = collection.public_send(:"with_attached_#{name}")
            end

            collection
          end

          # Both memoised on the model (outside dev) by Resource::Record::FieldNames.
          # Its `has_one` list already strips the `_attachment`/`_blob` reflections
          # backing an attachment, so those cannot be loaded twice by the two
          # branches above. Its attachment lists go through
          # `reflect_on_all_attachments`, which — unlike `attachment_reflections`,
          # empty under active_shrine — reports both backends.
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
end
