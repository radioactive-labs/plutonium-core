# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class FilterPills < Plutonium::UI::Component::Base
          def initialize(query:, total_count: nil)
            @query = query
            @total_count = total_count
          end

          def view_template
            return if @query.active_filter_descriptions.empty? && @total_count.to_i.zero?

            div(
              class: "flex items-center gap-1.5 px-4 py-2 border-b border-[var(--pu-border)] flex-wrap",
              data: {bulk_actions_target: "filterPills"}
            ) do
              @query.active_filter_descriptions.each { |f| render_pill(f) }
              if @query.active_filter_descriptions.any?
                render_add_filter_pill
                render_clear_all_pill
              end
              render_result_count if @total_count
            end
          end

          private

          def render_pill(filter)
            span(class: "inline-flex items-center gap-1.5 h-6 px-2 rounded-full bg-primary-50 border border-primary-200 text-xs text-primary-700 dark:bg-primary-950/40 dark:border-primary-900/60 dark:text-primary-300") do
              span { plain "#{filter[:label]}: #{filter[:value_label]}" }
              a(href: filter[:clear_url],
                aria: {label: "Remove #{filter[:label]} filter"},
                class: "ml-0.5 inline-flex items-center justify-center w-4 h-4 rounded hover:bg-primary-200 dark:hover:bg-primary-900/60") do
                render Phlex::TablerIcons::X.new(class: "w-3 h-3")
              end
            end
          end

          def render_add_filter_pill
            button(type: "button",
              data: {action: "click->filter-panel#toggle"},
              class: "inline-flex items-center gap-1 h-6 px-2 rounded-full border border-dashed border-[var(--pu-border)] text-xs text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:border-[var(--pu-border-strong)]") do
              render Phlex::TablerIcons::Plus.new(class: "w-3 h-3")
              plain "Filter"
            end
          end

          def render_clear_all_pill
            a(href: clear_all_url,
              class: "inline-flex items-center gap-1 h-6 px-2 rounded-full text-xs text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] underline-offset-2 hover:underline") do
              plain "Clear all"
            end
          end

          # Strip every active filter param while preserving search, scope,
          # sort, view, and pagination state.
          def clear_all_url
            keep = request.query_parameters.dup
            q = keep[:q] || keep["q"]
            if q.is_a?(Hash) || q.is_a?(ActionController::Parameters)
              filter_keys = @query.filter_definitions.keys.map(&:to_s)
              # to_unsafe_h on Parameters; to_h on Hash both yield a
              # plain Hash. Using to_h on Parameters would raise
              # UnfilteredParameters in newer Rails versions.
              raw = q.respond_to?(:to_unsafe_h) ? q.to_unsafe_h : q.to_h
              cleaned = raw.reject { |k, _| filter_keys.include?(k.to_s) }
              if cleaned.empty?
                keep.delete(:q)
                keep.delete("q")
              else
                keep["q"] = cleaned
              end
            end
            "#{request.path}?#{keep.to_query}"
          end

          def render_result_count
            div(class: "ml-auto text-xs text-[var(--pu-text-muted)]") do
              plain "#{@total_count} #{(@total_count == 1) ? "result" : "results"}"
            end
          end
        end
      end
    end
  end
end
