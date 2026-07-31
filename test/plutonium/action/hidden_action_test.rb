# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Action
    class HiddenActionTest < Minitest::Test
      def test_actions_are_visible_by_default
        refute Plutonium::Action::Simple.new(:archive).hidden?
      end

      def test_hidden_flag_is_readable
        assert Plutonium::Action::Simple.new(:reposition, hidden: true).hidden?
      end

      # `with` reconstructs an action from to_options — anything missing there is
      # silently dropped on round-trip, which would un-hide the action.
      def test_hidden_survives_a_with_round_trip
        action = Plutonium::Action::Simple.new(:reposition, hidden: true)
        assert action.with(label: "Move").hidden?
      end

      def test_hidden_can_be_turned_off_via_with
        action = Plutonium::Action::Simple.new(:reposition, hidden: true)
        refute action.with(hidden: false).hidden?
      end
    end
  end
end

# A hidden action is auto-classified by its interaction's shape, so a
# collection-shaped one lands in `defined_actions` as a bulk action. Both bulk
# bars must therefore filter `hidden?` themselves — historically neither did,
# and the only thing keeping such an action out of the bar was a definition-time
# ArgumentError in Kanban::Column. These pin the filtering at the render site.
module Plutonium
  module UI
    class HiddenBulkActionTest < Minitest::Test
      def test_table_bulk_bar_excludes_hidden_actions
        assert_equal [:archive], table_bulk_action_names
      end

      def test_grid_bulk_bar_excludes_hidden_actions
        assert_equal [:archive], grid_bulk_action_names
      end

      private

      def bulk_actions
        {
          archive: Plutonium::Action::Simple.new(:archive, bulk_action: true),
          reposition: Plutonium::Action::Simple.new(:reposition, bulk_action: true, hidden: true)
        }
      end

      def stub_definition
        definition = Object.new
        actions = bulk_actions
        definition.define_singleton_method(:defined_actions) { actions }
        definition
      end

      def table_bulk_action_names
        bulk_action_names_for(Plutonium::UI::Table::Resource)
      end

      def grid_bulk_action_names
        bulk_action_names_for(Plutonium::UI::Grid::Resource)
      end

      # Both selectors call `condition_met?(view_context)`; the argument is
      # evaluated before the (nil-condition) short circuit, so it must be stubbed.
      def bulk_action_names_for(component_class)
        component = component_class.new(
          [], resource_fields: [], resource_definition: stub_definition
        )
        component.define_singleton_method(:view_context) { nil }
        component.send(:bulk_actions).map(&:name)
      end
    end
  end
end
