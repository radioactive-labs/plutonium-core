# frozen_string_literal: true

require "digest"

module Plutonium
  module Wizard
    # Computes the deterministic identity digest a wizard session row is keyed by.
    #
    # The digest is over +wizard+, the scope GID, the anchor GID, and an identity
    # principal. The principal is the +token+ when present, otherwise the owner GID.
    # Excluding the owner whenever a token exists keeps a pre-auth → authenticated
    # transition from rekeying the row (spec §4 / §17.13).
    module InstanceKey
      # @param wizard [String] the wizard class name
      # @param scope [#to_global_id, String, nil] the portal scoping entity
      # @param anchor [#to_global_id, String, nil] the anchored record
      # @param token [String, nil] the pre-auth / concurrent-instance token
      # @param owner [#to_global_id, String, nil] the owning user
      # @return [String] a hex SHA256 digest
      def self.for(wizard:, scope:, anchor:, token:, owner:)
        principal = token.presence || gid(owner)
        digest_input = [wizard, gid(scope), gid(anchor), principal].map(&:to_s).join("|")
        Digest::SHA256.hexdigest(digest_input)
      end

      # Resolve an object to its GlobalID string. Strings pass through; nils become
      # blank.
      #
      # @param obj [#to_global_id, String, nil]
      # @return [String, nil]
      def self.gid(obj)
        return obj if obj.nil? || obj.is_a?(String)
        obj.to_global_id.to_s
      end
    end
  end
end
