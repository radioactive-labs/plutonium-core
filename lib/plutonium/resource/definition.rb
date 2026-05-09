module Plutonium
  module Resource
    class Definition < Plutonium::Definition::Base
      class_attribute :modal_mode, default: :slideover, instance_accessor: false

      VALID_MODAL_MODES = [:centered, :slideover, false].freeze

      # Sets how :new / :edit actions render.
      # - :slideover (default) — slide-in panel from the right
      # - :centered — centered dialog
      # - false — no modal; new/edit are full standalone pages
      def self.modal(mode)
        unless VALID_MODAL_MODES.include?(mode)
          raise ArgumentError, "modal must be one of #{VALID_MODAL_MODES.inspect}, got #{mode.inspect}"
        end
        self.modal_mode = mode
        configure_crud_modal_targets!
      end

      # Re-derives the default :new / :edit actions so their turbo_frame
      # matches the current `modal_mode`. Called when `.modal` is set
      # and once at Resource::Definition load (so the default
      # :slideover state propagates to the action records). Subclasses
      # inherit those records via DefineableProps#inherited (deep_dup);
      # calling `.modal` on a subclass re-runs this method locally.
      def self.configure_crud_modal_targets!
        target = (modal_mode == false) ? nil : "remote_modal"
        [:new, :edit].each do |name|
          action = defined_actions[name]
          next unless action
          next if action.turbo_frame == target
          defined_actions[name] = action.with(turbo_frame: target)
        end
      end

      def modal
        self.class.modal_mode
      end

      # Apply the default modal target ("remote_modal") to :new / :edit
      # so resources that never call `.modal` still get the slideover
      # behavior. Subclasses inherit the configured actions via
      # DefineableProps' deep_dup; calling `.modal` on a subclass
      # re-runs the configuration locally.
      configure_crud_modal_targets!
    end
  end
end
