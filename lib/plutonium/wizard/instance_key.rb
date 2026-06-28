# frozen_string_literal: true

require "digest"
require "json"

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

      # Serialize a key value into a STRUCTURED, unambiguous form for the digest:
      #   - Array → each element serialized, kept as a nested array
      #   - AR record / GlobalID-able → its GlobalID string
      #   - nil → nil (a nil tenant folds to a stable, distinct blank)
      #   - scalar → to_s
      #
      # Structure (not a flat join) is the point: the digest hashes the JSON of the
      # nested form, so `["a", "b"]` and the scalar `"a|b"` serialize to distinct
      # JSON (`["a","b"]` vs `"a|b"`) and can never collide. A separator-joined form
      # would make a key element containing the separator indistinguishable from a
      # structural boundary (two distinct runs collapsing to one row — cross-run
      # data exposure / one-time gating satisfied by the wrong run).
      #
      # @param value [Object]
      # @return [Object] a JSON-serializable structure (String / nested Array / nil)
      def self.serialize(value)
        case value
        when Array
          value.map { |v| serialize(v) }
        when nil
          nil
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

      # Hash the JSON of [salt, *parts]. JSON makes the boundaries between parts (and
      # between nested array elements) unambiguous; the salt (the app secret) makes
      # the digest a MAC over otherwise-public identifiers (wizard name + key GIDs),
      # so it can't be recomputed off-app to probe another run's existence/state.
      def self.digest(*parts)
        Digest::SHA256.hexdigest(JSON.generate([salt, *parts]))
      end
      private_class_method :digest

      # A stable, app-specific salt. Falls back to a constant when no Rails app /
      # secret is configured (e.g. isolated unit contexts) so the digest is still
      # deterministic — the MAC property simply degrades to the unsalted form there.
      def self.salt
        if defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application
          ::Rails.application.secret_key_base.to_s
        else
          "plutonium-wizard"
        end
      end
      private_class_method :salt
    end
  end
end
