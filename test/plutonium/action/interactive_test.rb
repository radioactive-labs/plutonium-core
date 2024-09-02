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
          immediate: true)
      end

      def test_initialization
        assert_equal :test_interactive, @action.name
        assert_equal "Test Interactive", @action.label
        assert_equal RecordInteraction, @action.interaction
      end

      def test_confirmation
        assert_equal "Test Interactive?", @action.confirmation

        non_immediate_action = Interactive::Factory.create(:non_immediate, interaction: RecordInteraction, immediate: false)
        assert_nil non_immediate_action.confirmation
      end

      def test_route_options
        assert_instance_of RouteOptions, @action.route_options
        assert_equal :post, @action.route_options.method
        assert_equal({action: :interactive_resource_record_action, interactive_action: :test_interactive}, @action.route_options.url_options)
      end

      def test_action_types
        assert @action.record_action?
        assert @action.collection_record_action?
        refute @action.bulk_action?
        refute @action.resource_action?
      end

      def test_record_action_types
        action = Interactive::Factory.create(:collection, interaction: RecordInteraction)

        assert action.record_action?
        assert action.collection_record_action?
        refute action.bulk_action?
        refute action.resource_action?
      end

      def test_bulk_action_types
        action = Interactive::Factory.create(:bulk, interaction: CollectionInteraction)

        refute action.record_action?
        refute action.collection_record_action?
        assert action.bulk_action?
        refute action.resource_action?
      end

      def test_resource_action_types
        action = Interactive::Factory.create(:resource, interaction: RecordlessInteraction)

        refute action.record_action?
        refute action.collection_record_action?
        refute action.bulk_action?
        assert action.resource_action?
      end

      def test_auto_immediate_detection
        action_with_inputs = Interactive::Factory.create(:with_inputs, interaction: RecordInteraction)
        refute action_with_inputs.send(:instance_variable_get, :@immediate)

        action_without_inputs = Interactive::Factory.create(:without_inputs, interaction: InlineInteraction)
        assert action_without_inputs.send(:instance_variable_get, :@immediate)
      end

      def test_build_route_options
        immediate_action = Interactive::Factory.create(:immediate, interaction: RecordInteraction, immediate: true)
        assert_equal :post, immediate_action.route_options.method

        non_immediate_action = Interactive::Factory.create(:non_immediate, interaction: RecordInteraction, immediate: false)
        assert_equal :get, non_immediate_action.route_options.method
      end
    end
  end
end
