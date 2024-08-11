# file: /Users/stefan/code/plutonium/starters/vulcan/gems/plutonium/test/plutonium/action/interactive_test.rb

require "test_helper"

module Plutonium
  module Action
    class InteractiveTest < Minitest::Test
      class RecordInteraction
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :resource
        attribute :test_filter, :string
      end

      class CollectionInteraction
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :resources
        attribute :test_filter, :string
      end

      class RecordlessInteraction
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :test_filter, :string
      end

      class InlineInteraction
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :resources
        attribute :resource
      end

      def setup
        @action = Interactive::Factory.create(:test_interactive,
          interaction: RecordInteraction,
          label: "Test Interactive",
          inline: true)
      end

      def test_initialization
        assert_equal :test_interactive, @action.name
        assert_equal "Test Interactive", @action.label
        assert_equal RecordInteraction, @action.interaction
      end

      def test_confirmation
        assert_equal "Test Interactive?", @action.confirmation

        non_inline_action = Interactive::Factory.create(:non_inline, interaction: RecordInteraction, inline: false)
        assert_nil non_inline_action.confirmation
      end

      def test_route_options
        assert_instance_of RouteOptions, @action.route_options
        assert_equal :post, @action.route_options.method
        assert_equal({action: :interactive_resource_record_action, interactive_action: :test_interactive}, @action.route_options.url_options)
      end

      def test_action_types
        assert @action.record_action?
        assert @action.collection_record_action?
        refute @action.collection_action?
        refute @action.global_action?
      end

      def test_record_action_types
        action = Interactive::Factory.create(:collection, interaction: RecordInteraction)

        assert action.record_action?
        assert action.collection_record_action?
        refute action.collection_action?
        refute action.global_action?
      end

      def test_collection_action_types
        action = Interactive::Factory.create(:collection, interaction: CollectionInteraction)

        refute action.record_action?
        refute action.collection_record_action?
        assert action.collection_action?
        refute action.global_action?
      end

      def test_global_action_types
        action = Interactive::Factory.create(:global, interaction: RecordlessInteraction)

        refute action.record_action?
        refute action.collection_record_action?
        refute action.collection_action?
        assert action.global_action?
      end

      def test_auto_inline_detection
        action_with_inputs = Interactive::Factory.create(:with_inputs, interaction: RecordInteraction)
        refute action_with_inputs.send(:instance_variable_get, :@inline)

        action_without_inputs = Interactive::Factory.create(:without_inputs, interaction: InlineInteraction)
        assert action_without_inputs.send(:instance_variable_get, :@inline)
      end

      def test_build_route_options
        inline_action = Interactive::Factory.create(:inline, interaction: RecordInteraction, inline: true)
        assert_equal :post, inline_action.route_options.method

        non_inline_action = Interactive::Factory.create(:non_inline, interaction: RecordInteraction, inline: false)
        assert_equal :get, non_inline_action.route_options.method
      end
    end
  end
end
