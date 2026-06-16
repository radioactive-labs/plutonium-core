# frozen_string_literal: true

require "digest"

module Plutonium
  module Wizard
    # Computes the deterministic identity digest a wizard session row is keyed by
    # (§4). There are two builders, mirroring the two identity axes:
    #
    # - {.concurrency} — a wizard with a `concurrency_key`. The digest is over the
    #   wizard name and the serialized key value(s) (which already include the
    #   folded tenant, §4.4). The keyed row IS the lock — two launches with the
    #   same key collapse to one digest, so the second resumes the first.
    # - {.tokened} — a wizard without a `concurrency_key`. The digest is over the
    #   wizard name and the per-launch `wizard_token`, so every launch is a fresh,
    #   independent (repeatable) run.
    #
    # The two recipes MUST stay byte-identical between the place that creates rows
    # (runner/driving) and the place that recomputes the key (the gate), or
    # one-time gating silently breaks.
    module InstanceKey
      # Keyed (concurrency_key) identity.
      #
      # @param wizard_name [String] the wizard class name
      # @param key_values [Object, Array] the concurrency_key value(s); arrays are
      #   serialized element-wise then joined. The tenant is expected to already be
      #   folded in by the caller (§4.4).
      # @return [String] a hex SHA256 digest
      def self.concurrency(wizard_name, key_values)
        digest("concurrency", wizard_name, serialize(key_values))
      end

      # Tokened (no concurrency_key) identity.
      #
      # @param wizard_name [String] the wizard class name
      # @param token [String] the per-launch wizard token
      # @return [String] a hex SHA256 digest
      def self.tokened(wizard_name, token)
        digest("tokened", wizard_name, token.to_s)
      end

      # Serialize a key value for the digest:
      #   - Array → each element serialized, then joined with "|"
      #   - AR record / GlobalID-able → its GlobalID string
      #   - nil → "" (so a nil tenant folds to a stable blank, not the literal)
      #   - scalar → to_s
      #
      # @param value [Object]
      # @return [String]
      def self.serialize(value)
        case value
        when Array
          value.map { |v| serialize(v) }.join("|")
        when nil
          ""
        when String, Symbol, Numeric, true, false
          value.to_s
        else
          if value.respond_to?(:to_global_id)
            value.to_global_id.to_s
          else
            value.to_s
          end
        end
      end

      def self.digest(*parts)
        Digest::SHA256.hexdigest(parts.map(&:to_s).join("|"))
      end
      private_class_method :digest
    end
  end
end
