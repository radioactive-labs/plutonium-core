# frozen_string_literal: true

module Plutonium
  module Wizard
    # Lazy view over a wizard run's persisted records (§2.2 / §4.5).
    #
    # The stored state only holds GIDs ({ "step_key" => [gid, ...] }); resolving
    # them back into live records costs a `GlobalID::Locator.locate` per GID. Most
    # requests (a GET render, a `back`, any step whose `condition:`/render never
    # reads `persisted`) don't need those records at all, so we resolve LAZILY:
    #
    # - `persisted[:key]` returns the memoized live records when the key was SET
    #   this request (records created via the `persist` macro in `on_submit`) — no
    #   locate.
    # - Otherwise it locates the GIDs stored under that key ONCE, memoizes the
    #   result, and returns it. A request that never reads `persisted` issues zero
    #   locate queries.
    #
    # `gid_source` is the `{ "step_key" => [gids] }` hash the runner injects from
    # the stored state. Writes (`persisted[k] = records`) memoize live records
    # directly and shadow any stored GIDs for that key.
    class LazyPersisted
      def initialize(gid_source = {})
        @gid_source = gid_source || {}
        @memo = {}
      end

      # Live records for a step key. Memoized records (set this request) are
      # returned as-is; otherwise the key's stored GIDs are located once.
      def [](key)
        key = key.to_sym
        return @memo[key] if @memo.key?(key)

        @memo[key] = locate(@gid_source[key.to_s] || @gid_source[key])
      end

      # Memoize live records for a key directly (the runner's post-`on_submit`
      # set, or an author assigning into `persisted`). No locate on later reads.
      def []=(key, records)
        @memo[key.to_sym] = Array(records)
      end

      # Whether this key has records available — either set this request or stored
      # as GIDs. Does NOT trigger a locate.
      def key?(key)
        key = key.to_sym
        @memo.key?(key) || @gid_source.key?(key.to_s) || @gid_source.key?(key)
      end
      alias_method :has_key?, :key?

      # Resolve every known key to its located records (forces locates). Used where
      # the full map is genuinely needed.
      def to_h
        keys.each_with_object({}) { |key, acc| acc[key] = self[key] }
      end

      # All known step keys (memoized + stored), as symbols, without locating.
      def keys
        (@memo.keys + @gid_source.keys.map(&:to_sym)).uniq
      end

      private

      def locate(gids)
        Array(gids).filter_map { |gid| GlobalID::Locator.locate(gid) }
      end
    end
  end
end
