# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Backend dispatch for typeahead/autocomplete queries against
      # resource form inputs and index filter inputs. Auto-mounted on
      # every Plutonium resource via the `interactive_resource_actions`
      # routing concern (see Plutonium::Routing::MapperExtensions).
      module Typeahead
        extend ActiveSupport::Concern

        TYPEAHEAD_LIMIT = 50

        included do
          before_action :authorize_typeahead!, only: %i[typeahead_input typeahead_filter]
        end

        # GET /<resource>/typeahead/input/:name?q=...
        def typeahead_input
          defn = current_definition.defined_inputs[params[:name].to_sym]
          return head(:not_found) unless defn

          render_typeahead_response(defn)
        end

        # GET /<resource>/typeahead/filter/:name?q=...
        def typeahead_filter
          filter = current_query_object.filter_definitions[params[:name].to_sym]
          return head(:not_found) unless filter

          defn = filter.defined_inputs[:value]
          return head(:not_found) unless defn

          render_typeahead_response(defn)
        end

        private

        def render_typeahead_response(defn)
          klass = lookup_typeahead_input_class(defn)
          unless klass && klass < Plutonium::UI::Form::Components::Searchable
            return render(json: {error: "input is not typeahead-capable"}, status: :bad_request)
          end

          widget = klass.build_for_typeahead(defn[:options] || {})
          results, has_more = widget.typeahead(
            query: params[:q].to_s,
            limit: TYPEAHEAD_LIMIT,
            controller: self
          )
          render json: {results: results, has_more: has_more}
        end

        def lookup_typeahead_input_class(defn)
          name = defn[:options]&.[](:as)
          return nil unless name
          Plutonium::UI::Form::Components::Searchable.registry[name.to_sym]
        end

        def authorize_typeahead!
          authorize! resource_class, to: :typeahead?
        end
      end
    end
  end
end
