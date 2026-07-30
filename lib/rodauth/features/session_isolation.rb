require "rodauth"

# Keeps each Rodauth configuration's session state independent of the others, so a
# person can be signed into more than one portal at a time.
#
# Rodauth calls +clear_session+ from +update_session+ on *every* login - including
# the +remember+ feature's +load_memory+ autologin - to defend against session
# fixation. rodauth-rails implements that as a full +reset_session+, which drops the
# entire Rails session rather than just the keys belonging to the configuration
# doing the login.
#
# In a Plutonium app that breaks multi-portal access. Each portal authenticates
# through its own configuration (+:user+, +:admin+, ...), so signing into one portal
# evicts every other portal's session. Worse, with +after_login { remember_login }+
# enabled the +load_memory+ calls in +RodauthApp#route+ then re-authenticate the
# evicted configuration from its remember cookie on the very next request - and
# evict the new one in turn. The last +load_memory+ in the route block wins
# permanently, so the other portal can never hold a session at all.
#
# This feature carries the *other* configurations' session entries across the
# reset. The Rails session id is still rotated and this configuration's own state is
# still dropped, so session fixation is still defeated; application session data is
# still cleared, exactly as before.
#
# Ownership is decided by +session_key_prefix+, so every configuration that wants to
# coexist must set one. A configuration without a prefix uses Rodauth's unprefixed
# default key names - the same names every other unprefixed configuration uses - so
# there is no way to tell its entries apart and nothing is carried for it.
module Rodauth
  Feature.define(:session_isolation, :SessionIsolation) do
    def clear_session
      carried = sibling_session_data
      super
      carried.each { |key, value| session[key] = value }
    end

    private

    # The session entries owned by the app's other Rodauth configurations.
    #
    # Keys are matched by prefix rather than by asking each configuration to
    # enumerate them. Deriving them from method names (e.g. everything matching
    # /_session_key\z/) would mean blind-sending methods that are not readers at
    # all: +single_session+ exposes +reset_single_session_key+ and
    # +update_single_session_key+ as public auth methods, both of which UPDATE the
    # database with a fresh random key - signing the sibling out, the exact opposite
    # of this feature's purpose.
    def sibling_session_data
      data = session.to_hash

      sibling_rodauths.each_with_object({}) do |sibling, carried|
        prefix = sibling.session_key_prefix.to_s
        # Unprefixed sibling: its key names are indistinguishable from ours, and
        # carrying them would restore our own pre-login auth state across the reset,
        # defeating the session fixation protection.
        next if prefix.empty?

        keys = data.keys.select { |key| key.to_s.start_with?(prefix) }
        # Courtesy for a hand-written config that sets an explicit `session_key`
        # alongside its prefix: that value bypasses `convert_session_key` and so is
        # unprefixed. Do NOT read this as endorsing that shape - it leaves the account
        # id rotating separately from every other key, which is a crash waiting to
        # happen (see the note on session_key_prefix in the auth guide). Generated
        # configs set the prefix only, and for them this line never matches.
        account_key = sibling.session_key.to_s
        keys << account_key if data.key?(account_key)

        keys.each do |key|
          carried[key] = data[key] unless own_session_key?(key)
        end
      end
    end

    # Guards against a misconfiguration in which a sibling shares our prefix: we must
    # never restore our own entries, or the reset would be a no-op for us.
    def own_session_key?(key)
      key = key.to_s
      return true if key == session_key.to_s

      prefix = session_key_prefix.to_s
      prefix.present? && key.start_with?(prefix)
    end

    # Only base-Rodauth methods are called on siblings (+session_key_prefix+ and
    # +session_key+), so configurations that do not enable this feature - or do not
    # descend from the app's base plugin at all - still work.
    def sibling_rodauths
      names = scope.opts[:rodauths].keys - [self.class.configuration_name]
      names.map { |name| scope.rodauth(name) }
    end
  end
end
