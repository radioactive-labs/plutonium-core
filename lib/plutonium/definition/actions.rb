module Plutonium
  module Definition
    module Actions
      extend ActiveSupport::Concern

      included do
        defineable_prop :action

        def self.action(name, interaction: nil, **opts)
          opts = inherited_modal_options.merge(opts) if interaction
          defined_actions[name] = if interaction
            Plutonium::Action::Interactive::Factory.create(name, interaction:, **opts)
          else
            Plutonium::Action::Simple.new(name, **opts)
          end
        end

        def action(name, interaction: nil, **opts)
          opts = self.class.send(:inherited_modal_options).merge(opts) if interaction
          instance_defined_actions[name] = if interaction
            Plutonium::Action::Interactive::Factory.create(name, interaction:, **opts)
          else
            Plutonium::Action::Simple.new(name, **opts)
          end
        end

        # Defaults inherited by interactive actions from the definition's
        # `modal` config. Per-action `modal:` / `size:` still wins because
        # the caller's opts merge over these. When `modal false` is set,
        # we clear `turbo_frame` so the action renders as a full page
        # instead of inside the remote-modal frame.
        private_class_method def self.inherited_modal_options
          return {} unless respond_to?(:modal_mode)
          return {turbo_frame: nil} if modal_mode == false
          {modal: modal_mode, size: modal_size_mode}
        end

        def defined_actions
          @merged_defined_actions ||= begin
            customize_actions
            merged = self.class.defined_actions.merge(instance_defined_actions)
            merged.sort_by { |k, v| v.position }.to_h
          end
        end

        # standard CRUD actions

        # turbo_frame for :new and :edit is set by
        # Resource::Definition.configure_crud_modal_targets! based on the
        # `modal` config. Don't hard-code it here.
        action(:new, route_options: {action: :new},
          resource_action: true, category: :primary,
          icon: Phlex::TablerIcons::Plus, position: 10)

        action(:show, route_options: {action: :show},
          collection_record_action: true, category: :primary,
          icon: Phlex::TablerIcons::Eye, position: 10)

        action(:edit, route_options: {action: :edit},
          record_action: true, collection_record_action: true, category: :primary,
          icon: Phlex::TablerIcons::Edit, position: 20)

        action(:destroy, route_options: {method: :delete},
          record_action: true, collection_record_action: true, category: :danger,
          icon: Phlex::TablerIcons::Trash, position: 100,
          confirmation: "Are you sure?", turbo_frame: "_top")

        # Example of dynamic route options using custom url_resolver:
        #
        # action(:create_deployment,
        #   label: "Create Deployment",
        #   icon: Phlex::TablerIcons::Rocket,
        #   record_action: true,
        #   route_options: Plutonium::Action::RouteOptions.new(
        #     url_resolver: ->(subject) {
        #       resource_url_for(UniversalFlow::Deployment, action: :new, parent: subject)
        #     }
        #   ))
      end
    end
  end
end
