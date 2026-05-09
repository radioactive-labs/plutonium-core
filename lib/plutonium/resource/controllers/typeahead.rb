# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Backend dispatch for typeahead/autocomplete queries against
      # resource form inputs and index filter inputs. Auto-mounted on
      # every Plutonium resource via the `interactive_resource_actions`
      # routing concern (see Plutonium::Routing::MapperExtensions).
      #
      # The controller resolves what to query directly from the input
      # definition + the model's association reflection — no widget
      # indirection. Two source kinds are supported:
      #
      #   1. Static `choices: [...]` — case-insensitive substring filter.
      #   2. Association — either `association_class:` set on the input,
      #      or inferred from `resource_class.reflect_on_association(name)`.
      #
      # Association queries route through the associated resource's
      # `policy.relation_scope` so users only see records they can read.
      module Typeahead
        extend ActiveSupport::Concern

        TYPEAHEAD_LIMIT = 50

        included do
          before_action :authorize_typeahead!, only: %i[typeahead_input typeahead_filter]
          # Read-only JSON; row-level auth is enforced inline through
          # authorized_resource_scope, so the after_action verifier is
          # redundant.
          skip_verify_current_authorized_scope only: %i[typeahead_input typeahead_filter]
        end

        # GET /<resource>/typeahead/input/:name?q=...
        def typeahead_input
          field_name = params[:name].to_sym
          defn = current_definition.defined_inputs[field_name]
          # Inputs are often inferred from the model (no explicit
          # `input :foo` in the definition). Accept the request when the
          # field name maps to a real association even without an entry.
          unless defn || resource_class.reflect_on_association(field_name)
            return head(:not_found)
          end

          render_typeahead_response(defn || {}, field_name)
        end

        # GET /<resource>/typeahead/filter/:name?q=...
        def typeahead_filter
          filter = current_query_object.filter_definitions[params[:name].to_sym]
          return head(:not_found) unless filter

          defn = filter.defined_inputs[:value]
          return head(:not_found) unless defn

          render_typeahead_response(defn, params[:name].to_sym)
        end

        private

        def render_typeahead_response(defn, field_name)
          options = defn[:options] || {}
          query = params[:q].to_s
          candidates = collect_typeahead_candidates(options, field_name, query)

          if candidates.nil?
            return render(json: {error: "input has no typeahead source"}, status: :bad_request)
          end

          has_more = candidates.length > TYPEAHEAD_LIMIT
          results = candidates.first(TYPEAHEAD_LIMIT).map { |row| serialize_typeahead_row(row) }
          render json: {results: results, has_more: has_more}
        end

        # Returns the candidate list, or nil if the input has neither
        # static choices nor a resolvable association class.
        def collect_typeahead_candidates(options, field_name, query)
          if options[:choices]
            filter_static_choices(options[:choices], query)
          elsif (klass = typeahead_association_class(options, field_name))
            filter_association(klass, query, options)
          end
        end

        def typeahead_association_class(options, field_name)
          options[:association_class] ||
            resource_class.reflect_on_association(field_name)&.klass
        end

        def filter_static_choices(choices, query)
          return choices if query.blank?
          q = query.downcase
          choices.select { |label, _| label.to_s.downcase.include?(q) }
        end

        # Routes through the associated resource's policy.relation_scope
        # so typeahead never surfaces records the user can't read, then
        # narrows via the associated resource definition's `search` block
        # when present. Without a search block the relation is returned
        # unfiltered (capped) — define `search do |scope, q| ... end`
        # on the associated resource's definition to get real filtering.
        def filter_association(klass, query, options)
          relation = options[:skip_authorization] ? klass.all : authorized_resource_scope(klass)
          if query.present? && (search_block = associated_definition_search_block(klass))
            relation = search_block.call(relation, query)
          end
          relation.limit(Typeahead::TYPEAHEAD_LIMIT + 1).to_a
        end

        def associated_definition_search_block(klass)
          registry = Plutonium::Resource::Register
          return nil unless registry.respond_to?(:definition_for)
          defn_class = registry.definition_for(klass)
          defn_class&._search_definition if defn_class.respond_to?(:_search_definition)
        rescue
          nil
        end

        def serialize_typeahead_row(row)
          if row.is_a?(Array)
            {value: row[1].to_s, label: row[0].to_s}
          else
            {value: row.to_signed_global_id.to_s, label: row.to_label}
          end
        end

        def authorize_typeahead!
          authorize_current! resource_class, to: :typeahead?
        end
      end
    end
  end
end
