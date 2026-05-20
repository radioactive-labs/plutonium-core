module Plutonium
  module Resource
    class Definition < Plutonium::Definition::Base
      class_attribute :modal_mode, default: :slideover, instance_accessor: false
      class_attribute :modal_size_mode, default: :md, instance_accessor: false

      VALID_MODAL_MODES = [:centered, :slideover, false].freeze

      # Sets how :new / :edit actions render. Also becomes the default
      # for interactive actions registered on this definition; per-action
      # `modal:` / `size:` overrides still win. Call this BEFORE
      # `action :foo, interaction: ...` — actions defined earlier are
      # not retroactively re-derived.
      #
      # - :slideover (default) — slide-in panel from the right
      # - :centered — centered dialog
      # - false — no modal; new/edit are full standalone pages
      #
      # The optional `size:` controls the width of the rendered modal.
      # See Plutonium::UI::Modal::Base::VALID_SIZES. Pass `size: :auto`
      # to let the modal hug its form's natural width — useful for
      # resources whose form is too wide for the default `:md`.
      def self.modal(mode, size: :md)
        unless VALID_MODAL_MODES.include?(mode)
          raise ArgumentError, "modal must be one of #{VALID_MODAL_MODES.inspect}, got #{mode.inspect}"
        end
        unless Plutonium::UI::Modal::Base::VALID_SIZES.include?(size)
          raise ArgumentError,
            "modal size must be one of #{Plutonium::UI::Modal::Base::VALID_SIZES.inspect}, got #{size.inspect}"
        end
        self.modal_mode = mode
        self.modal_size_mode = size
        configure_crud_modal_targets!
      end

      # Re-derives the default :new / :edit actions so their turbo_frame
      # matches the current `modal_mode`. Called when `.modal` is set
      # and once at Resource::Definition load (so the default
      # :slideover state propagates to the action records). Subclasses
      # inherit those records via DefineableProps#inherited (deep_dup);
      # calling `.modal` on a subclass re-runs this method locally.
      def self.configure_crud_modal_targets!
        target = (modal_mode == false) ? nil : Plutonium::REMOTE_MODAL_FRAME
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

      def modal_size
        self.class.modal_size_mode
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
