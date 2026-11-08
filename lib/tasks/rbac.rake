# frozen_string_literal: true

namespace :plutonium do
  namespace :rbac do
    desc "Upsert system roles declared with Plutonium::Rbac.system_role"
    task sync: :environment do
      Plutonium::Rbac::Sync.call
      puts "Synced #{Plutonium::Rbac.system_roles.size} system role(s)"
    end
  end
end
