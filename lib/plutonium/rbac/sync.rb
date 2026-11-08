# frozen_string_literal: true

module Plutonium
  module Rbac
    # Upserts code-declared system roles (Plutonium::Rbac.system_role) as
    # global, locked rows. All or nothing.
    module Sync
      # A global role with a system role's key exists but was not created by
      # sync. Taking it over would rewrite a role someone built by hand.
      class ConflictError < Plutonium::Error; end

      module_function

      def call
        Role.transaction do
          Rbac.system_roles.each_value do |definition|
            role = Role.global.find_or_initialize_by(key: definition[:key])
            if role.persisted? && !role.system_role?
              raise ConflictError,
                "Global role #{role.key.inspect} (id #{role.id}) is not a system role. " \
                "Rename its key or delete it, then sync again."
            end

            role.update!(
              name: definition[:name],
              description: definition[:description],
              permissions: definition[:permissions],
              system_role: true
            )
          end
        end
      end
    end
  end
end
