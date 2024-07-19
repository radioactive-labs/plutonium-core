require "test_helper"

module Plutonium
  module Lib
    class SmartCacheTest < Minitest::Test
      def setup
        @test_class = Class.new do
          include SmartCache

          def expensive_operation(arg)
            sleep(0.1) # Simulate an expensive operation
            "Result for #{arg}"
          end

          def cached_method(arg)
            cache_unless_reloading("cached_method_#{arg}") { expensive_operation(arg) }
          end

          def memoized_method(arg)
            expensive_operation(arg)
          end
          memoize_unless_reloading :memoized_method

          def no_arg_method
            sleep(0.1)
            "No arg result"
          end
          memoize_unless_reloading :no_arg_method
        end

        @instance = @test_class.new
        SmartCache.force_caching = nil
        @original_cache_classes = Rails.application.config.cache_classes
      end

      def teardown
        SmartCache.force_caching = nil
        Rails.application.config.cache_classes = @original_cache_classes
        @test_class._smart_cache.clear
      end

      def test_cache_unless_reloading_caches_when_enabled
        SmartCache.force_caching = true

        start_time = Time.now
        result1 = @instance.cached_method("test")
        time1 = Time.now - start_time

        start_time = Time.now
        result2 = @instance.cached_method("test")
        time2 = Time.now - start_time

        assert_equal "Result for test", result1
        assert_equal "Result for test", result2
        assert time2 < time1, "Second call should be faster due to caching"
      end

      def test_cache_unless_reloading_does_not_cache_when_disabled
        SmartCache.force_caching = false

        start_time = Time.now
        result1 = @instance.cached_method("test")
        time1 = Time.now - start_time

        start_time = Time.now
        result2 = @instance.cached_method("test")
        time2 = Time.now - start_time

        assert_equal "Result for test", result1
        assert_equal "Result for test", result2
        assert time2 >= 0.1 && time1 >= 0.1, "Both calls should take similar time when caching is disabled: #{time1.round(2)} vs #{time2.round(2)}"
      end

      def test_memoize_unless_reloading_memoizes_when_enabled
        SmartCache.force_caching = true

        start_time = Time.now
        result1 = @instance.memoized_method("test")
        time1 = Time.now - start_time

        start_time = Time.now
        result2 = @instance.memoized_method("test")
        time2 = Time.now - start_time

        assert_equal "Result for test", result1
        assert_equal "Result for test", result2
        assert time2 < time1, "Second call should be faster due to memoization"
      end

      def test_memoize_unless_reloading_does_not_memoize_when_disabled
        SmartCache.force_caching = false

        start_time = Time.now
        result1 = @instance.memoized_method("test")
        time1 = Time.now - start_time

        start_time = Time.now
        result2 = @instance.memoized_method("test")
        time2 = Time.now - start_time

        assert_equal "Result for test", result1
        assert_equal "Result for test", result2
        assert time2 >= 0.1 && time1 >= 0.1, "Both calls should take similar time when memoization is disabled: #{time1.round(2)} vs #{time2.round(2)}"
      end

      def test_memoize_unless_reloading_caches_separately_for_different_arguments
        SmartCache.force_caching = true

        result1 = @instance.memoized_method("test1")
        result2 = @instance.memoized_method("test2")
        result3 = @instance.memoized_method("test1")
        result4 = @instance.memoized_method("test2")

        assert_equal "Result for test1", result1
        assert_equal "Result for test2", result2
        assert_equal "Result for test1", result3
        assert_equal "Result for test2", result4
      end

      def test_memoize_unless_reloading_optimizes_no_arg_methods
        SmartCache.force_caching = true

        start_time = Time.now
        result1 = @instance.no_arg_method
        time1 = Time.now - start_time

        start_time = Time.now
        result2 = @instance.no_arg_method
        time2 = Time.now - start_time

        assert_equal "No arg result", result1
        assert_equal "No arg result", result2
        assert time1 >= 0.01, "First call to no-arg method should be slow"
        assert time2 < 0.01, "Second call to no-arg method should be very fast due to caching"
      end

      def test_instance_flush_smart_cache_clears_all_caches
        SmartCache.force_caching = true

        @instance.cached_method("test1")
        @instance.memoized_method("test2")

        @instance.send(:flush_smart_cache)

        start_time = Time.now
        @instance.cached_method("test1")
        time1 = Time.now - start_time

        start_time = Time.now
        @instance.memoized_method("test2")
        time2 = Time.now - start_time

        assert time1 >= 0.1, "Cached method should take full time after flush"
        assert time2 >= 0.1, "Memoized method should take full time after flush"
      end

      def test_instance_flush_smart_cache_clears_specific_caches
        SmartCache.force_caching = true

        @instance.cached_method("test1")
        @instance.memoized_method("test2")

        @instance.send(:flush_smart_cache, ["cached_method_test1"])

        start_time = Time.now
        @instance.cached_method("test1")
        time1 = Time.now - start_time

        start_time = Time.now
        @instance.memoized_method("test2")
        time2 = Time.now - start_time

        assert time1 >= 0.1, "Cached method should take full time after specific flush. Took #{time1.round(2)}"
        assert time2 < 0.1, "Memoized method should still be fast after specific flush. Took #{time2.round(2)}"
      end

      def test_class_flush_smart_cache_clears_all_caches
        SmartCache.force_caching = true

        @instance.cached_method("test1")
        @instance.memoized_method("test2")

        @test_class.flush_smart_cache

        start_time = Time.now
        @instance.cached_method("test1")
        time1 = Time.now - start_time

        start_time = Time.now
        @instance.memoized_method("test2")
        time2 = Time.now - start_time

        assert time1 >= 0.1, "Cached method should take full time after class-level flush"
        assert time2 >= 0.1, "Memoized method should take full time after class-level flush"
      end

      def test_class_flush_smart_cache_clears_specific_caches
        SmartCache.force_caching = true

        @instance.cached_method("test1")
        @instance.memoized_method("test2")

        @test_class.flush_smart_cache(["cached_method_test1"])

        start_time = Time.now
        @instance.cached_method("test1")
        time1 = Time.now - start_time

        start_time = Time.now
        @instance.memoized_method("test2")
        time2 = Time.now - start_time

        assert time1 >= 0.1, "Cached method should take full time after specific class-level flush. Took #{time1.round(2)}"
        assert time2 < 0.1, "Memoized method should still be fast after specific class-level flush. Took #{time2.round(2)}"
      end

      def test_smart_cache_is_thread_safe
        SmartCache.force_caching = true

        threads = []
        results = Concurrent::Array.new

        10.times do |i|
          threads << Thread.new do
            # Create a new instance for each thread to avoid shared state
            instance = @test_class.new
            results << instance.cached_method("test#{i}")
          end
        end

        threads.each(&:join)

        assert_equal 10, results.uniq.size, "Each thread should get a unique result"
      end

      def test_force_caching_overrides_rails_config
        Rails.application.config.cache_classes = false
        SmartCache.force_caching = true

        start_time = Time.now
        result1 = @instance.cached_method("test")
        time1 = Time.now - start_time

        start_time = Time.now
        result2 = @instance.cached_method("test")
        time2 = Time.now - start_time

        assert_equal "Result for test", result1
        assert_equal "Result for test", result2
        assert time2 < time1, "Second call should be faster due to caching, even when Rails.application.config.cache_classes is false"
      end

      def test_force_caching_is_thread_local
        thread1 = Thread.new do
          SmartCache.force_caching = true
          assert SmartCache.force_caching, "force_caching should be true in thread1"
        end

        thread2 = Thread.new do
          assert_nil SmartCache.force_caching, "force_caching should be nil in thread2"
        end

        thread3 = Thread.new do
          SmartCache.force_caching = false
          refute SmartCache.force_caching, "force_caching should be false in thread3"
        end

        thread1.join
        thread2.join
        thread3.join
      end
    end
  end
end
