module Plutonium
  module Definition
    module Actions
      extend ActiveSupport::Concern

      included do
        defineable_prop :action

        def self.action(name, interaction: nil, **)
          defined_actions[name] = if interaction
            Plutonium::Action::Interactive::Factory.create(name, interaction:, **)
          else
            Plutonium::Action::Simple.new(name, **)
          end
        end

        def action(name, **)
          instance_defined_actions[name] = Plutonium::Action::Simple.new(name, **)
        end

        def defined_actions
          @merged_defined_actions ||= begin
            customize_actions
            merged = self.class.defined_actions.merge(instance_defined_actions)
            merged.sort_by { |k, v| v.position }.to_h
          end
        end

        # standard CRUD actions

        action(:new, route_options: {action: :new},
          resource_action: true, category: :primary,
          icon: Phlex::TablerIcons::Plus, position: 10)

        action(:show, route_options: {action: :show},
          collection_record_action: true,
          icon: Phlex::TablerIcons::Eye, position: 10)

        action(:edit, route_options: {action: :edit},
          record_action: true, collection_record_action: true,
          icon: Phlex::TablerIcons::Edit, position: 20)

        action(:destroy, route_options: {method: :delete},
          record_action: true, collection_record_action: true, category: :danger,
          icon: Phlex::TablerIcons::Trash, position: 100,
          confirmation: "Are you sure?", turbo_frame: "_top")
      end
    end
  end
end