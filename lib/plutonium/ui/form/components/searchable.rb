# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Mixin for input components that support backend-driven typeahead
        # queries. Hosts (e.g. ResourceSelect) include this, register
        # their `:as` symbol via `typeahead_input_name`, and supply three
        # small hooks: #apply_typeahead_options, #collect_typeahead_candidates,
        # #serialize_typeahead_row.
        module Searchable
          extend ActiveSupport::Concern

          # Maps the input definition's :as symbol to the component class.
          # Populated when a widget calls `typeahead_input_name :foo`.
          # The Typeahead controller concern reads this to dispatch.
          def self.registry
            @registry ||= {}
          end

          class_methods do
            def typeahead_input_name(name)
              Plutonium::UI::Form::Components::Searchable.registry[name.to_sym] = self
            end

            # Allocates the host without running its render-time
            # initializer (Phlex form components want a field/form
            # context that doesn't exist outside a render cycle), then
            # delegates to #apply_typeahead_options to set just the
            # ivars #typeahead needs.
            def build_for_typeahead(options)
              instance = allocate
              instance.send(:apply_typeahead_options, options || {})
              instance
            end
          end

          # Returns [results, has_more].
          # results is an array of {value:, label:} hashes serialised by
          # the host's #serialize_typeahead_row. has_more is true when
          # the host produced more candidates than `limit`.
          def typeahead(query:, limit:, controller:)
            candidates = collect_typeahead_candidates(query.to_s, controller: controller)
            over = candidates.length > limit
            [candidates.first(limit).map { |row| serialize_typeahead_row(row) }, over]
          end
        end
      end
    end
  end
end
