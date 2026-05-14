# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Concerns
        # Shared typeahead wiring for association/resource select components.
        #
        # Hosts must implement two hooks:
        #
        #   typeahead_target_class      -> the associated model class, or nil
        #                                  (returns nil for polymorphic/unknown)
        #   typeahead_kind_and_name(opt) -> [:input | :filter, Symbol], used when
        #                                  the consumer didn't pass an explicit
        #                                  `typeahead: {kind:, name:}` hash
        #
        # The concern owns:
        #   - `configure_typeahead_attributes!` — call from `before_template`
        #   - `typeahead_searchable?` — registry + fallback-column check
        #   - `typeahead_url_for` — engine route helper lookup
        module TypeaheadAttributes
          extend ActiveSupport::Concern

          private

          # Adds the typeahead URL data attr so the slim-select Stimulus
          # controller delegates to the backend via events.search.
          # Default-on (opt out with `typeahead: false`). Pass a Hash to
          # override kind/name (e.g. `typeahead: {kind: :filter, name: :status}`).
          #
          # Auto opt-out: if the associated resource has neither a `search`
          # block nor a fallback search column on the model, fall back to
          # slim-select's eager list + client-side filter — the backend
          # would just return unfiltered records.
          def configure_typeahead_attributes!(typeahead_option)
            return if typeahead_option == false
            return unless typeahead_searchable?
            url = typeahead_url_for(typeahead_option)
            return unless url
            attributes[:data_slim_select_typeahead_url_value] = url
          end

          def typeahead_searchable?
            klass = typeahead_target_class
            return false unless klass

            # Go through `resource_definition` so portal/package namespacing
            # is honored — a portal can ship its own definition with a
            # different `search` block than the base.
            return true if resource_definition(klass).class._search_definition.present?

            Plutonium::Resource::Controllers::Typeahead
              .searchable_column_for(klass, label_method: @label_method).present?
          rescue NameError
            false
          end

          def typeahead_url_for(typeahead_option)
            kind, name = if typeahead_option.is_a?(Hash)
              [typeahead_option[:kind] || :input, typeahead_option[:name]]
            else
              typeahead_kind_and_name(typeahead_option)
            end
            return nil unless name

            route_key = resource_class.model_name.route_key
            helper = (kind == :filter) ? :"typeahead_filter_#{route_key}_path" : :"typeahead_input_#{route_key}_path"

            # Engine route helpers are the source of truth for routes
            # mounted under a Plutonium portal — phlex-rails' `helpers`
            # proxy is deprecated and not the right entry point here.
            # Helper may be absent if a consumer removed the typeahead
            # route from the resource — fall back to no URL, slim-select
            # uses its eager list.
            url_helpers = current_engine.routes.url_helpers
            return nil unless url_helpers.respond_to?(helper)
            url_helpers.public_send(helper, name: name)
          end
        end
      end
    end
  end
end
