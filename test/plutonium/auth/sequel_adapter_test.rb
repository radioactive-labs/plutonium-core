# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Auth
    class SequelAdapterTest < Minitest::Test
      def setup
        @original_adapter = nil
        if ActiveRecord::Base.respond_to?(:connection_db_config)
          @original_adapter = ActiveRecord::Base.connection_db_config.adapter
        end
      end

      # Tests for SEQUEL_ADAPTERS constant
      def test_sequel_adapters_constant_is_frozen
        assert SequelAdapter::SEQUEL_ADAPTERS.frozen?
      end

      def test_sequel_adapters_contains_postgresql_mapping
        expected = RUBY_ENGINE == "jruby" ? "postgresql" : "postgres"
        assert_equal expected, SequelAdapter::SEQUEL_ADAPTERS["postgresql"]
      end

      def test_sequel_adapters_contains_mysql2_mapping
        expected = RUBY_ENGINE == "jruby" ? "mysql" : "mysql2"
        assert_equal expected, SequelAdapter::SEQUEL_ADAPTERS["mysql2"]
      end

      def test_sequel_adapters_contains_sqlite3_mapping
        assert_equal "sqlite", SequelAdapter::SEQUEL_ADAPTERS["sqlite3"]
      end

      def test_sequel_adapters_contains_oracle_enhanced_mapping
        assert_equal "oracle", SequelAdapter::SEQUEL_ADAPTERS["oracle_enhanced"]
      end

      def test_sequel_adapters_contains_sqlserver_mapping
        expected = RUBY_ENGINE == "jruby" ? "mssql" : "tinytds"
        assert_equal expected, SequelAdapter::SEQUEL_ADAPTERS["sqlserver"]
      end

      # Tests for sequel_adapter method
      def test_sequel_adapter_returns_mapped_adapter_for_known_adapters
        # Test that it correctly maps the current adapter
        result = SequelAdapter.sequel_adapter
        assert_kind_of String, result
        refute_empty result
      end

      def test_sequel_adapter_returns_activerecord_adapter_for_unknown_adapters
        # Stub the activerecord_adapter to return an unknown adapter
        SequelAdapter.stub(:activerecord_adapter, "custom_db") do
          assert_equal "custom_db", SequelAdapter.sequel_adapter
        end
      end

      # Tests for db method
      def test_db_returns_sequel_database_connection
        result = SequelAdapter.db
        assert_instance_of Sequel::Database, result
      end

      def test_db_raises_helpful_error_on_failure
        # Stub sequel_adapter to return an invalid adapter
        SequelAdapter.stub(:sequel_adapter, "invalid_nonexistent_adapter_xyz") do
          error = assert_raises(RuntimeError) do
            SequelAdapter.db
          end
          assert_match(/Failed to initialize Sequel/, error.message)
          assert_match(/invalid_nonexistent_adapter_xyz/, error.message)
        end
      end

      # Tests for activerecord_adapter detection
      def test_activerecord_adapter_detection_works
        # This test verifies that we can detect the current adapter
        # The test environment should have a valid database config
        result = SequelAdapter.sequel_adapter
        assert_kind_of String, result
        refute_empty result
      end

      # Integration test
      def test_full_integration_with_active_record
        # Verify the full chain works: detect AR adapter -> map to Sequel -> create connection
        db = SequelAdapter.db
        assert_instance_of Sequel::Database, db
        assert_respond_to db, :run
      end
    end
  end
end
