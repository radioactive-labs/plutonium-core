# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Permission picker for Plutonium::Rbac::Role#permissions: one checkbox
        # per catalog key, grouped by resource, with select-all per group and
        # per standard action (rbac-permissions Stimulus controller).
        class RbacPermissions < Phlexi::Form::Components::Base
          include Phlexi::Form::Components::Concerns::HandlesInput

          def view_template
            # The wrapper's <label for=> points at this id, but a label can't
            # name a div, so the group carries the field label itself.
            div(id: attributes[:id], class: tokens("pu-rbac-permissions", attributes[:class]),
              role: "group", aria: {label: field.label}, data: {controller: "rbac-permissions"}) do
              # Unchecked boxes are not submitted; the blank keeps "no
              # permissions" saveable and is dropped by normalize_input.
              input(type: :hidden, name: input_name, value: "", autocomplete: "off", hidden: true, disabled: attributes[:disabled])
              render_action_toggles
              div(class: "pu-rbac-permissions-groups") do
                Plutonium::Rbac::Catalog.grouped.each { |group, permissions| render_group(group, permissions) }
              end
            end
          end

          protected

          def normalize_input(value) = Array(value).compact_blank.map(&:to_s)

          private

          def input_name = "#{attributes[:name]}[]"

          def selected = @selected ||= Array(field.value).map(&:to_s)

          def render_action_toggles
            div(class: "pu-rbac-permissions-actions") do
              Plutonium::Rbac::Catalog::STANDARD_ACTIONS.each do |action|
                button(type: :button, class: "pu-btn pu-btn-xs pu-btn-outline", disabled: attributes[:disabled],
                  data: {action: "rbac-permissions#toggleAction", rbac_permissions_permission_action_param: action}) do
                  action.to_s.humanize
                end
              end
            end
          end

          def render_group(group, permissions)
            fieldset(class: "pu-rbac-permissions-group", data: {rbac_permissions_target: "group"}) do
              legend do
                label do
                  input(type: :checkbox, class: "pu-checkbox", disabled: attributes[:disabled],
                    data: {action: "rbac-permissions#toggleGroup", rbac_permissions_target: "groupToggle"})
                  plain group
                end
              end
              permissions.each { |permission| render_permission(permission) }
            end
          end

          def render_permission(permission)
            label(class: "pu-rbac-permission") do
              input(type: :checkbox, class: "pu-checkbox", name: input_name, value: permission.key,
                checked: selected.include?(permission.key), disabled: attributes[:disabled],
                data: {rbac_permissions_target: "permission", permission_action: permission.action, action: "rbac-permissions#sync"})
              plain permission.label
            end
          end
        end
      end
    end
  end
end
