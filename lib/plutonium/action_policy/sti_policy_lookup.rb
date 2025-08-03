# frozen_string_literal: true

module Plutonium
  module ActionPolicy
    # Custom ActionPolicy lookup resolver for STI (Single Table Inheritance) models
    # This resolver attempts to find a policy for the base class when a policy
    # for the STI subclass is not found
    module StiPolicyLookup
      # STI base class policy resolver
      # Checks if the record is an STI model and looks up the policy for its base class
      STI_BASE_CLASS_LOOKUP = ->(record, namespace: nil, strict_namespace: false, **) {
        # Skip if record is a symbol or doesn't have a class
        next unless record.respond_to?(:class)

        record_class = record.is_a?(Module) ? record : record.class

        # Check if this is an STI model (has base_class and is different from current class)
        next unless record_class.respond_to?(:base_class)
        next if record_class == record_class.base_class

        # Try to find policy for the base class
        policy_name = "#{record_class.base_class}Policy"
        ::ActionPolicy::LookupChain.send(:lookup_within_namespace, policy_name, namespace, strict: strict_namespace)
      }

      class << self
        def install!
          # Insert STI resolver before the standard INFER_FROM_CLASS resolver
          # This ensures we try the base class before giving up
          infer_index = ::ActionPolicy::LookupChain.chain.index(::ActionPolicy::LookupChain::INFER_FROM_CLASS)

          if infer_index
            # Insert after INFER_FROM_CLASS so it runs as a fallback
            ::ActionPolicy::LookupChain.chain.insert(infer_index + 1, STI_BASE_CLASS_LOOKUP)
          else
            # If for some reason INFER_FROM_CLASS isn't found, append to end
            ::ActionPolicy::LookupChain.chain << STI_BASE_CLASS_LOOKUP
          end
        end
      end
    end
  end
end