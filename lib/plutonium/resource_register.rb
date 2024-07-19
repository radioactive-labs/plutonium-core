# frozen_string_literal: true

module Plutonium
  # ResourceRegister manages the registration and lookup of resources.
  class ResourceRegister
    include Plutonium::Lib::SmartCache
    include Concerns::ResourceValidatable

    # Custom error class for frozen register operations
    class FrozenRegisterError < StandardError; end

    def initialize
      @resources = Set.new
      @frozen = false
    end

    # Registers a new resource with the register.
    #
    # @param resource [Class] The resource class to be registered.
    # @raise [Plutonium::Concerns::ResourceValidatable::InvalidResourceError] If the resource is not a valid Plutonium::Resource::Record.
    # @raise [FrozenRegisterError] If the register is frozen.
    # @return [void]
    def register(resource)
      raise FrozenRegisterError, "Cannot modify frozen resource register" if @frozen

      validate_resource!(resource)
      @resources.add(resource.to_s)
    end

    # Returns an array of all registered resource classes and freezes the register.
    #
    # @return [Array<Class>] An array of registered resource classes.
    def resources
      freeze
      @resources.map(&:constantize)
    end
    memoize_unless_reloading :resources

    # Returns a hash mapping route keys to their corresponding resource classes.
    # This method will freeze the register if it hasn't been frozen already.
    #
    # @return [Hash{Symbol => Class}] A hash where keys are route keys and values are resource classes.
    def route_key_lookup
      freeze
      resources.to_h do |resource|
        [resource.model_name.singular_route_key.to_sym, resource]
      end
    end
    memoize_unless_reloading :route_key_lookup

    # Clears all registered resources and invalidates the cache.
    #
    # @return [void]
    def clear
      @resources.clear
      @frozen = false
      invalidate_cache
    end

    # Checks if the register is frozen.
    #
    # @return [Boolean] True if the register is frozen, false otherwise.
    def frozen?
      @frozen
    end

    private

    # Freezes the register
    #
    # @return [Boolean] Always returns true
    def freeze
      @frozen ||= true
    end

    # Invalidates the memoization cache
    #
    # @return [void]
    def invalidate_cache
      flush_smart_cache
    end
  end
end
