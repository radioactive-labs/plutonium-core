# frozen_string_literal: true

require "csv"

module Plutonium
  module Resource
    module Controllers
      # Streams the current resource collection as a CSV download.
      #
      # Auto-mounted on every Plutonium resource via the
      # `interactive_resource_actions` routing concern (see
      # Plutonium::Routing::MapperExtensions). Gated by the `export_csv?`
      # policy method, which defaults to `false` — export is strictly
      # opt-in (enable it by overriding `export_csv?` to return true).
      #
      # The exported rows are exactly the index's filtered collection
      # (`filtered_resource_collection`) — same search, filters, scope, and
      # tenant/parent scoping — but NOT paginated: every matching record is
      # exported. Rows are streamed (a lazy Enumerator body + `find_each`) so
      # memory stays flat regardless of row count.
      #
      # Columns come from `policy.permitted_attributes_for_export` (defaults
      # to the index columns), with the primary key always prepended as the
      # first column. Per-field output and headers are customizable through
      # the definition's `export` DSL.
      #
      # `find_each` iterates in primary-key order, so the file does not
      # preserve the index's current sort (filters/search/scope still apply).
      #
      # Streaming uses a lazy Enumerator response body rather than
      # `send_stream` — the latter lives in ActionController::Live, which
      # would turn *every* resource action into a threaded streaming
      # response. The Enumerator body streams through Rack on its own.
      module ExportCsv
        extend ActiveSupport::Concern

        # Placeholder written when a column is neither an `export` block nor a
        # real attribute on the record, so the export degrades to a usable file
        # instead of a mid-stream NoMethodError (which would truncate the
        # already-committed download).
        INVALID_COLUMN = "<<invalid column>>"

        included do
          before_action :authorize_export_csv!, only: :export_csv
          # Row-level authorization is the scope itself
          # (current_authorized_scope via filtered_resource_collection), so
          # the after_action scope verifier is redundant here.
          skip_verify_current_authorized_scope only: :export_csv
        end

        # GET /<resources>/export_csv
        def export_csv
          response.headers["Content-Type"] = "text/csv; charset=utf-8"
          response.headers["Content-Disposition"] =
            ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: export_csv_filename)
          # Defeat proxy/`Rack::ETag` buffering so rows flush as they're read.
          response.headers["X-Accel-Buffering"] = "no"
          response.headers["Cache-Control"] = "no-cache"

          self.response_body = export_csv_lines
        end

        private

        def authorize_export_csv!
          authorize_current! resource_class, to: :export_csv?
        end

        def export_csv_filename
          suffix = export_all_requested? ? "_all" : ""
          "#{export_csv_basename}#{suffix}_#{Date.current}.csv"
        end

        # The human resource name, slugified for a filesystem-friendly file
        # (Blogging::Post → "posts", not the route key "blogging_posts").
        def export_csv_basename
          helpers.resource_name_plural(resource_class).parameterize(separator: "_")
        end

        # Which records to export. Two modes:
        # - default — the index's filtered collection (current scope,
        #   filters, and search via `?q`).
        # - `?all=1` — the entire authorized scope, bypassing the query
        #   object entirely (no scope/filter/search/default-scope).
        # Both still respect tenant/parent scoping (current_authorized_scope).
        def export_csv_collection
          export_all_requested? ? current_authorized_scope : filtered_resource_collection
        end

        def export_all_requested?
          ActiveModel::Type::Boolean.new.cast(params[:all])
        end

        # A lazy line enumerator: the header row, then one CSV line per
        # record streamed via `find_each` (bounded memory). Pure with
        # respect to the response, so it's unit-testable on its own.
        def export_csv_lines
          columns = export_columns
          Enumerator.new do |yielder|
            yielder << export_csv_row(columns.map { |name| export_csv_header(name) })
            export_csv_collection.find_each do |record|
              yielder << export_csv_row(columns.map { |name| export_csv_value(record, name) })
            end
          end
        end

        # Serializes one row, neutralizing spreadsheet formula injection per cell.
        def export_csv_row(cells)
          CSV.generate_line(cells.map { |cell| neutralize_csv_formula(cell) })
        end

        # A cell beginning with = + - @ (or a leading tab/CR) is executed as a
        # formula by Excel/Sheets. Prefix it with a single quote so the value
        # imports as literal text (CSV/formula injection).
        def neutralize_csv_formula(value)
          string = value.to_s
          /\A[=+\-@\t\r]/.match?(string) ? "'#{string}" : string
        end

        # The primary key is always the first column, followed by the
        # policy's exportable attributes (de-duplicated so an explicitly
        # listed primary key isn't repeated).
        def export_columns
          primary_key = resource_class.primary_key.to_sym
          [primary_key] + (exportable_attributes.map(&:to_sym) - [primary_key])
        end

        def exportable_attributes
          @exportable_attributes ||= current_policy.send_with_report(:permitted_attributes_for_export)
        end

        # Resolves a cell's value. An `export` block (definition DSL) takes
        # precedence; otherwise the attribute is read off the record.
        # Associations render as their display label — the same as the index —
        # instead of "#<User:0x…>"; scalars pass through untouched. A name that
        # is neither an `export` block nor a real attribute renders the
        # INVALID_COLUMN placeholder rather than aborting the stream.
        def export_csv_value(record, name)
          definition = current_definition.defined_exports[name]
          return definition[:block].call(record) if definition && definition[:block]

          begin
            value = record.public_send(name)
          rescue NoMethodError
            return INVALID_COLUMN
          end

          case value
          when ActiveRecord::Base then helpers.display_name_of(value)
          when ActiveRecord::Relation then helpers.display_name_of(value.to_a)
          else value
          end
        end

        def export_csv_header(name)
          definition = current_definition.defined_exports[name]
          definition&.dig(:options, :label) || name.to_s.humanize
        end
      end
    end
  end
end
