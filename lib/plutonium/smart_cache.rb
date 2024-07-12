# frozen_string_literal: true

module Plutonium
  # The SmartCache module provides flexible caching mechanisms for classes and objects,
  # allowing for both inline caching and method-level memoization.
  #
  # This module is designed to optimize performance by caching results
  # when class caching is enabled (typically in production),
  # while ensuring fresh results when caching is disabled (typically in development).
  #
  # This implementation is thread-safe.
  #
  # @example Including SmartCache in a class
  #   class MyClass
  #     include Plutonium::SmartCache
  #
  #     def my_method(arg)
  #       cache_unless_reloading("my_method_#{arg}") { expensive_operation(arg) }
  #     end
  #
  #     def another_method(arg)
  #       # Method implementation
  #     end
  #     memoize_unless_reloading :another_method
  #   end
  module SmartCache
    extend ActiveSupport::Concern

    included do
      class_attribute :_memoized_results, instance_writer: false, default: Concurrent::Map.new
    end

    # Caches the result of the given block unless class caching is disabled.
    #
    # @param cache_key [String] A unique key to identify the cached result
    # @yield The block whose result will be cached
    # @return [Object] The result of the block, either freshly computed or from cache
    #
    # @example Using cache_unless_reloading inline
    #   def fetch_user_data(user_id)
    #     cache_unless_reloading("user_data_#{user_id}") do
    #       UserDataService.fetch(user_id)
    #     end
    #   end
    #
    # @note This method uses Rails.application.config.cache_classes
    #       to determine whether to cache or not. When cache_classes is false
    #       (typical in development), it will always yield to get a fresh result.
    #       When true (typical in production), it will use the cache.
    def cache_unless_reloading(cache_key, &block)
      return yield unless should_cache?

      @cached_results ||= Concurrent::Map.new
      @cached_results.compute_if_absent(cache_key) { yield }
    end

    # Flushes the smart cache for the specified keys or all keys if none are specified.
    #
    # @param keys [Array<Symbol, String>, Symbol, String] The cache key(s) to flush
    # @return [void]
    #
    # @example Flushing specific cache keys
    #   flush_smart_cache([:user_data, :product_list])
    #
    # @example Flushing all cache keys
    #   flush_smart_cache
    #
    # @note This method clears both inline caches and memoized method results.
    def flush_smart_cache(keys = nil)
      keys = Array(keys).map(&:to_sym)
      if keys.present?
        @cached_results&.delete_if { |k, _| keys.include?(k.to_sym) }
        keys.each { |key| self.class._memoized_results.delete(key) }
      else
        @cached_results&.clear
        self.class._memoized_results.clear
      end
    end

    # Determines whether caching should be performed based on the current Rails configuration.
    #
    # @return [Boolean] true if caching should be performed, false otherwise
    # @note This method uses Rails.application.config.cache_classes to determine caching behavior.
    #       When cache_classes is false (typical in development), it returns false.
    #       When true (typical in production), it returns true.
    def should_cache?
      Rails.application.config.cache_classes
    end

    class_methods do
      # Memoizes the result of the specified method unless class caching is disabled.
      #
      # @param method_name [Symbol] The name of the method to memoize
      # @return [void]
      #
      # @example Memoizing a method
      #   class User
      #     include Plutonium::SmartCache
      #
      #     def expensive_full_name_calculation
      #       # Complex name calculation
      #     end
      #     memoize_unless_reloading :expensive_full_name_calculation
      #   end
      #
      # @note This method uses Rails.application.config.cache_classes to determine
      #       whether to memoize or not. When cache_classes is false (typical in development),
      #       it will always call the original method. When true (typical in production),
      #       it will use memoization, caching results for each unique set of arguments.
      def memoize_unless_reloading(method_name)
        original_method = instance_method(method_name)
        define_method(method_name) do |*args|
          if should_cache?
            cache = self.class._memoized_results[method_name] ||= Concurrent::Map.new
            cache.compute_if_absent(args.hash.to_s) { original_method.bind_call(self, *args) }
          else
            original_method.bind_call(self, *args)
          end
        end
      end
    end
  end

  # Configuration:
  #  The caching behavior is controlled by the Rails configuration option config.cache_classes:
  #
  #  - When false (typical in development):
  #    - Classes are reloaded on each request.
  #    - cache_unless_reloading always yields fresh results.
  #    - memoize_unless_reloading always calls the original method.
  #
  #  - When true (typical in production):
  #    - Classes are cached.
  #    - cache_unless_reloading uses cached results.
  #    - memoize_unless_reloading uses memoized results, caching for each unique set of arguments.
  #
  # Best Practices:
  #  - Use meaningful and unique cache keys to avoid collisions.
  #  - Be mindful of memory usage, especially with large cached results.
  #  - Consider cache expiration strategies for long-running processes.
  #  - Use cache_unless_reloading for fine-grained control within methods.
  #  - Use memoize_unless_reloading for entire methods, especially those with expensive computations.
  #
  # Thread Safety:
  #  - This implementation is thread-safe.
  #  - It uses Concurrent::Map from the concurrent-ruby gem for thread-safe caching.
  #
  # Testing:
  #  - In your test environment, you may want to control caching behavior explicitly.
  #  - You can mock or stub Rails.application.config.cache_classes or override should_cache? as needed in your tests.
end
