# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class ScopesPills < Plutonium::UI::Component::Base
          def view_template
            return if scopes.empty?

            nav(role: "tablist",
              aria: {label: "Scope"},
              class: "flex items-center gap-1 px-4 py-2 border-b border-[var(--pu-border)]") do
              render_all_pill
              scopes.each_key { |key| render_pill(key) }
            end
          end

          private

          def render_all_pill
            active = all_scope_active?
            a(
              id: "all-scope",
              href: current_query_object.build_url(scope: nil),
              role: "tab",
              aria: {selected: active},
              class: pill_classes(active)
            ) { "All" }
          end

          def render_pill(key)
            active = current_query_object.selected_scope.to_s == key.to_s
            label = key.to_s.humanize

            a(
              id: "#{key}-scope",
              href: current_query_object.build_url(scope: key),
              role: "tab",
              aria: {selected: active},
              class: pill_classes(active)
            ) { label }
          end

          def pill_classes(active)
            base = "px-3 py-1 rounded-md text-sm transition-colors"
            state = if active
              "bg-primary-100 text-primary-700 dark:bg-primary-950/40 dark:text-primary-300"
            else
              "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
            end
            "#{base} #{state}"
          end

          def all_scope_active?
            current_query_object.all_scope_selected? ||
              (!raw_resource_query_params.key?(:scope) && current_query_object.default_scope_name.blank?)
          end

          def scopes
            @scopes ||= current_query_object.scope_definitions
          end
        end
      end
    end
  end
end
