# file: /Users/stefan/code/plutonium/starters/vulcan/gems/plutonium/test/plutonium/action/base_test.rb

require "test_helper"

module Plutonium
  module Action
    class BaseTest < Minitest::Test
      # Minimal stand-in for a Plutonium::Resource::Definition. The lazy
      # accessors only need `modal_mode`, `modal_size`, and `show_in`.
      def stub_definition(modal_mode: :slideover, modal_size: :md, show_in: :page)
        Struct.new(:modal_mode, :modal_size, :show_in).new(modal_mode, modal_size, show_in)
      end

      def setup
        @action = Base.new(
          :test_action,
          label: "Test Action",
          icon: "test-icon",
          color: :blue,
          confirmation: "Are you sure?",
          route_options: RouteOptions.new(action: :test, method: :post),
          turbo_frame: "test_frame",
          bulk_action: true,
          category: :test_category,
          position: 10
        )
      end

      def test_initialization
        assert_equal :test_action, @action.name
        assert_equal "Test Action", @action.label
        assert_equal "test-icon", @action.icon
        assert_equal :blue, @action.color
        assert_equal "Are you sure?", @action.confirmation
        assert_instance_of RouteOptions, @action.route_options
        assert_equal "test_frame", @action.turbo_frame(stub_definition)
        assert_equal "test_category", @action.category
        assert @action.category.test_category?
        assert_equal 10, @action.position
      end

      def test_default_values
        action = Base.new(:default_action)
        assert_equal "Default Action", action.label
        assert_equal Phlex::TablerIcons::ChevronRight, action.icon
        assert_nil action.color
        assert_nil action.confirmation
        assert_instance_of RouteOptions, action.route_options
        assert_nil action.turbo_frame(stub_definition)
        assert_equal 50, action.position
      end

      def test_action_types
        assert @action.bulk_action?
        refute @action.collection_record_action?
        refute @action.record_action?
        refute @action.resource_action?

        resource_action = Base.new(:resource, resource_action: true)
        assert resource_action.resource_action?
      end

      def test_frozen_instance
        assert @action.frozen?
      end

      def test_name_symbol_conversion
        action = Base.new("string_name")
        assert_equal :string_name, action.name
      end

      def test_label_fallback_to_humanized_name
        action = Base.new(:test_action_name)
        assert_equal "Test Action Name", action.label
      end

      def test_multiple_action_types
        action = Base.new(:multi, bulk_action: true, record_action: true)
        assert action.bulk_action?
        assert action.record_action?
        refute action.resource_action?
        refute action.collection_record_action?
      end

      def test_immutability
        assert_raises(FrozenError) { @action.instance_variable_set(:@name, :new_name) }
      end

      def test_route_options_as_hash
        action = Base.new(:hash_route,
          route_options: {method: :put, action: :custom, key: "value"})
        assert_instance_of RouteOptions, action.route_options
        assert_equal :put, action.route_options.method
        assert_equal({action: :custom, key: "value"}, action.route_options.url_options)
      end

      def test_route_options_as_route_options_object
        route_options = RouteOptions.new(action: :predefined, method: :patch)
        action = Base.new(:object_route, route_options: route_options)
        assert_equal route_options, action.route_options
      end

      def test_route_options_default
        action = Base.new(:default_route)
        assert_instance_of RouteOptions, action.route_options
        assert_equal RouteOptions.new, action.route_options
      end

      def test_route_options_invalid_input
        assert_raises(ArgumentError) do
          Base.new(:invalid_route, route_options: "invalid")
        end
      end

      def test_modal_mode_inherits_from_definition_when_unset
        action = Base.new(:default_action)
        assert_equal :slideover, action.modal_mode(stub_definition(modal_mode: :slideover))
        assert_equal :centered, action.modal_mode(stub_definition(modal_mode: :centered))
      end

      def test_modal_mode_accepts_centered
        action = Base.new(:modal_action, modal: :centered)
        assert_equal :centered, action.modal_mode(stub_definition(modal_mode: :slideover))
      end

      def test_modal_mode_accepts_slideover
        action = Base.new(:modal_action, modal: :slideover)
        assert_equal :slideover, action.modal_mode(stub_definition(modal_mode: :centered))
      end

      def test_modal_raises_on_invalid_value
        assert_raises(ArgumentError) do
          Base.new(:modal_action, modal: :fullscreen)
        end
      end

      def test_modal_size_inherits_from_definition_when_unset
        action = Base.new(:default_action)
        assert_equal :lg, action.modal_size(stub_definition(modal_size: :lg))
      end

      def test_modal_size_accepts_explicit_value
        action = Base.new(:modal_action, size: :xl)
        assert_equal :xl, action.modal_size(stub_definition(modal_size: :md))
      end

      def test_size_raises_on_invalid_value
        assert_raises(ArgumentError) do
          Base.new(:modal_action, size: :huge)
        end
      end

      def test_turbo_frame_downgrades_to_nil_when_modal_false
        action = Base.new(:a, turbo_frame: Plutonium::REMOTE_MODAL_FRAME)
        assert_nil action.turbo_frame(stub_definition(modal_mode: false))
        assert_equal Plutonium::REMOTE_MODAL_FRAME,
          action.turbo_frame(stub_definition(modal_mode: :slideover))
      end

      def test_turbo_frame_passes_through_non_modal_frames
        action = Base.new(:a, turbo_frame: "_top")
        assert_equal "_top", action.turbo_frame(stub_definition(modal_mode: false))
      end

      # The canonical :show action carries no explicit frame; it reads the
      # definition's show_in so a resource can open show in a modal or full-page.
      def test_show_action_full_page_when_show_in_page
        show = Base.new(:show)
        assert_nil show.turbo_frame(stub_definition(show_in: :page))
      end

      def test_show_action_targets_modal_when_show_in_modal
        show = Base.new(:show)
        assert_equal Plutonium::REMOTE_MODAL_FRAME,
          show.turbo_frame(stub_definition(show_in: :modal))
      end

      # show_in is independent of modal_mode (which styles new/edit): a :modal
      # show opens even when modal_mode is false.
      def test_show_action_modal_is_independent_of_modal_mode
        show = Base.new(:show)
        assert_equal Plutonium::REMOTE_MODAL_FRAME,
          show.turbo_frame(stub_definition(show_in: :modal, modal_mode: false))
      end

      # A show action with an explicit frame keeps it (show_in does not apply).
      def test_explicit_frame_on_show_action_wins_over_show_in
        show = Base.new(:show, turbo_frame: "_top")
        assert_equal "_top", show.turbo_frame(stub_definition(show_in: :modal))
      end

      # Minimal stand-in for the view context. The condition runs inside a
      # ConditionContext that exposes object/record and delegates the rest here.
      def stub_view(current_user: nil)
        Struct.new(:current_user).new(current_user)
      end

      def test_condition_met_true_when_no_condition
        assert Base.new(:a).condition_met?(stub_view)
        assert Base.new(:a).condition_met?(stub_view, record: Object.new)
      end

      def test_condition_met_evaluates_proc_result
        shown = Base.new(:a, condition: -> { true })
        hidden = Base.new(:a, condition: -> { false })
        assert shown.condition_met?(stub_view)
        refute hidden.condition_met?(stub_view)
      end

      def test_condition_can_access_record_via_object_and_record
        record = Struct.new(:draft).new(true)
        via_object = Base.new(:a, condition: -> { object.draft })
        via_record = Base.new(:a, condition: -> { record.draft })
        assert via_object.condition_met?(stub_view, record:)
        assert via_record.condition_met?(stub_view, record:)

        record.draft = false
        refute via_object.condition_met?(stub_view, record:)
      end

      def test_condition_object_is_nil_without_record
        action = Base.new(:a, condition: -> { object.nil? })
        assert action.condition_met?(stub_view)
      end

      def test_condition_delegates_missing_to_the_view_context
        action = Base.new(:a, condition: -> { current_user == "alice" })
        assert action.condition_met?(stub_view(current_user: "alice"))
        refute action.condition_met?(stub_view(current_user: "bob"))
      end

      def test_condition_round_trips_through_with
        condition = -> { object.draft }
        action = Base.new(:a, condition:)
        cloned = action.with(label: "Renamed")
        assert_equal "Renamed", cloned.label
        assert_same condition, cloned.condition
      end
    end
  end
end
