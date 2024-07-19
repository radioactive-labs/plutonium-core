# frozen_string_literal: true

module Plutonium
  module Lib
    # OverlayedHash provides a hash-like structure that overlays values on top of a base hash.
    #
    # This class allows you to create a new hash-like object that uses a base hash for default values,
    # but can be modified without affecting the original base hash. When a key is accessed, it first
    # checks if the key exists in the overlay; if not, it falls back to the base hash.
    #
    # @example Usage
    #   base = { a: 1, b: 2 }
    #   overlay = OverlayedHash.new(base)
    #   overlay[:b] = 3
    #   overlay[:c] = 4
    #
    #   overlay[:a] # => 1 (from base)
    #   overlay[:b] # => 3 (from overlay)
    #   overlay[:c] # => 4 (from overlay)
    #   base[:b]    # => 2 (unchanged)
    class OverlayedHash
      # Initialize a new OverlayedHash with a base hash.
      #
      # @param base [Hash] The base hash to use for fallback values.
      def initialize(base)
        @base = base
        @overlay = {}
      end

      # Retrieve a value from the overlay hash or the base hash.
      #
      # @param key The key to look up.
      # @return The value associated with the key, or nil if not found.
      def [](key)
        @overlay.key?(key) ? @overlay[key] : @base[key]
      end

      # Set a value in the overlay hash.
      #
      # @param key The key to set.
      # @param value The value to associate with the key.
      def []=(key, value)
        @overlay[key] = value
      end

      # Check if a key exists in either the overlay or base hash.
      #
      # @param key The key to check for.
      # @return [Boolean] true if the key exists, false otherwise.
      def key?(key)
        @overlay.key?(key) || @base.key?(key)
      end

      # Enumerate over all keys in both the overlay and base hash.
      #
      # @yield [key] Gives each key to the block.
      # @return [Enumerator] If no block is given.
      def each_key
        return to_enum(:each_key) unless block_given?

        keys.each { |key| yield key }
      end

      # Retrieve all keys from both the overlay and base hash.
      #
      # @return [Array] An array of all unique keys.
      def keys
        (@overlay.keys + @base.keys).uniq
      end

      # Retrieve all values, prioritizing the overlay over the base.
      #
      # @return [Array] An array of values corresponding to all keys.
      def values
        keys.map { |key| self[key] }
      end

      # Convert the OverlayedHash to a regular Hash.
      #
      # @return [Hash] A new Hash with all keys and values from the OverlayedHash.
      def to_h
        keys.each_with_object({}) { |key, hash| hash[key] = self[key] }
      end
    end
  end
end
