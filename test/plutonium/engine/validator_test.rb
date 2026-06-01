# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Engine
    class ValidatorTest < Minitest::Test
      # Minimal host that mixes in the validator's class methods.
      class Host
        include Plutonium::Engine::Validator
      end

      # A plain engine class that does not mix in Plutonium::Engine, so it is
      # unsupported under both the development and production checks.
      def unsupported_engine
        Class.new
      end

      def test_validate_engine_raises_for_unsupported_engine
        error = assert_raises(ArgumentError) do
          Host.validate_engine!(unsupported_engine)
        end
        assert_match(/must include Plutonium::Engine/, error.message)
      end

      def test_error_message_links_to_documentation
        error = assert_raises(ArgumentError) do
          Host.validate_engine!(unsupported_engine)
        end
        assert_match(
          %r{https://radioactive-labs\.github\.io/plutonium-core/reference/app/packages},
          error.message
        )
      end

      def test_supported_engine_recognizes_plutonium_engines
        engine = Class.new { include Plutonium::Engine }

        assert Host.supported_engine?(engine)
        assert_nil Host.validate_engine!(engine)
      end

      def test_supported_engine_rejects_plain_classes
        refute Host.supported_engine?(unsupported_engine)
      end

      # Reload safety: in development the framework is reloaded, so the
      # `Plutonium::Engine` constant is reassigned to a fresh module while an
      # already-loaded engine still includes the previous one. An
      # identity-based `include?` check would spuriously return false; the
      # name-based check must keep recognizing the engine.
      def test_supported_engine_survives_constant_reassignment
        engine = Class.new { include Plutonium::Engine }
        orphaned = engine.ancestors.find { |a| a.name == "Plutonium::Engine" }

        # Stand in for the reloaded constant: a different object, same name.
        reloaded = Module.new
        reloaded.define_singleton_method(:name) { "Plutonium::Engine" }

        refute_equal orphaned, reloaded, "sanity: distinct module objects"
        refute engine.include?(reloaded), "identity check would fail post-reload"
        assert Host.supported_engine?(engine), "name-based check stays correct"
      end
    end
  end
end
