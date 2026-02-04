require "test_helper"

module Plutonium
  module Definition
    class ScopingTest < Minitest::Test
      def setup
        @definition_class = Class.new(Plutonium::Definition::Base)
      end

      def test_default_scope_is_nil_by_default
        assert_nil @definition_class.default_scope
        assert_nil @definition_class.new.default_scope
      end

      def test_default_scope_can_be_set
        @definition_class.default_scope :active

        assert_equal :active, @definition_class.default_scope
        assert_equal :active, @definition_class.new.default_scope
      end

      def test_default_scope_converts_to_symbol
        @definition_class.default_scope "published"

        assert_equal :published, @definition_class.default_scope
      end

      def test_default_scope_is_inherited
        @definition_class.default_scope :active
        subclass = Class.new(@definition_class)

        assert_equal :active, subclass.default_scope
        assert_equal :active, subclass.new.default_scope
      end

      def test_default_scope_can_be_overridden_in_subclass
        @definition_class.default_scope :active
        subclass = Class.new(@definition_class)
        subclass.default_scope :published

        assert_equal :active, @definition_class.default_scope
        assert_equal :published, subclass.default_scope
      end

      def test_default_scope_returns_current_value_when_called_without_args
        @definition_class.default_scope :active

        assert_equal :active, @definition_class.default_scope
      end
    end
  end
end
