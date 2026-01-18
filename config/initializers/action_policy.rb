# frozen_string_literal: true

# Configure ActionPolicy for Plutonium
Rails.application.config.to_prepare do
  # Install STI policy lookup support
  # This allows STI models to use their base class's policy when a specific policy doesn't exist
  require "plutonium/action_policy/sti_policy_lookup"
  Plutonium::ActionPolicy::StiPolicyLookup.install!
end
