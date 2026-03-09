# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class ScopesBar < Plutonium::UI::Component::Base
          include Plutonium::UI::Component::Behaviour

          def view_template
            div(
              class: "flex flex-wrap justify-between items-center gap-4 mb-4"
            ) do
              div(class: "flex flex-wrap items-center gap-2") do
                render_all_scope_button
                current_query_object.scope_definitions.each_key do |name|
                  render_scope_button(name)
                end
              end
            end
          end

          private

          def render_all_scope_button
            active = all_scope_active?
            a(
              id: "all-scope",
              href: current_query_object.build_url(scope: nil),
              class: active ? active_scope_class : inactive_scope_class
            ) { "All" }
          end

          def render_scope_button(name)
            active = name.to_s == current_scope
            a(
              id: "#{name}-scope",
              href: current_query_object.build_url(scope: name),
              class: active ? active_scope_class : inactive_scope_class
            ) { name.to_s.humanize }
          end

          def current_scope
            # Use the effective scope (includes default when no selection)
            current_query_object.selected_scope&.to_s
          end

          def all_scope_active?
            # Active if user explicitly selected "All" OR no scope param and no default
            current_query_object.all_scope_selected? ||
              (!raw_resource_query_params.key?(:scope) && current_query_object.default_scope_name.blank?)
          end

          def active_scope_class
            "pu-btn pu-btn-sm pu-btn-primary"
          end

          def inactive_scope_class
            "pu-btn pu-btn-sm pu-btn-ghost"
          end

          def render?
            current_query_object.scope_definitions.present?
          end
        end
      end
    end
  end
end
