# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # Plutonium::Rbac::Role#permissions as chips grouped by resource.
        # Keys no longer in the catalog (a removed action) are listed raw so a
        # stale grant stays visible.
        class RbacPermissions < List
          def render_value(keys)
            return span(class: themed(:list_item)) { Plutonium::Translation.t("plutonium.rbac.permissions.all") } if keys.include?("*")

            permissions = Plutonium::Rbac::Catalog.permissions.select { keys.include?(it.key) }
            unknown = keys - permissions.map(&:key)

            dl(**attributes) do
              permissions.group_by(&:group).each { |group, items| render_group(group, items.map(&:label)) }
              render_group(Plutonium::Translation.t("plutonium.rbac.permissions.other"), unknown) if unknown.any?
            end
          end

          private

          def render_group(group, labels)
            dt(class: themed(:rbac_permissions_group)) { group }
            dd(class: themed(:list)) do
              labels.each { |label| span(class: themed(:list_item)) { label } }
            end
          end
        end
      end
    end
  end
end
