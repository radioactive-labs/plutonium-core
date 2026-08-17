# frozen_string_literal: true

module Plutonium
  module Definition
    # Per-resource width for detail-style pages. `page_width` sets both the
    # form and the show page; `form_width` / `display_width` override one
    # surface without disturbing the other.
    #
    #   Plutonium.configure { |c| c.default_page_width = :md }   # global
    #
    #   class PostDefinition < ResourceDefinition
    #     page_width    :lg      # this resource's form AND show page
    #     display_width :full    # ...except the show page, which goes full
    #   end
    #
    # Resolution, most specific first: the surface-specific setting, then
    # `page_width`, then `Plutonium.configuration.default_page_width`. All
    # three inherit to subclasses (so a portal-specific definition keeps its
    # parent's width unless it says otherwise), which is why these are
    # `inheritable_config_attr` rather than plain class attributes.
    module PageWidths
      extend ActiveSupport::Concern

      # `inheritable_config_attr` appends the `_config` suffix itself and
      # defines the bare name as a singleton method on the class. A
      # `class_methods` module would sit BEHIND that in the ancestor chain and
      # never be called, so the validating versions are defined here, after
      # generation, to replace it — the same ordering `show_in` relies on.
      included do
        inheritable_config_attr :page_width, :form_width, :display_width

        # Reader with no argument, validated writer with one, so an unknown
        # token raises at declaration rather than silently rendering at some
        # other width.
        %i[page_width form_width display_width].each do |name|
          define_singleton_method(name) do |value = :__not_set__|
            return public_send(:"#{name}_config") if value == :__not_set__

            public_send(:"#{name}_config=", Plutonium::UI::PageWidth.validate!(value))
          end
        end
      end

      # The resolved token for each surface. Nil-coalescing rather than
      # `||`-on-a-boolean, so an explicit `:full` (a legitimate choice) is
      # honoured instead of being treated as "unset".
      def resolved_form_width
        self.class.form_width_config ||
          self.class.page_width_config ||
          Plutonium.configuration.default_page_width
      end

      def resolved_display_width
        self.class.display_width_config ||
          self.class.page_width_config ||
          Plutonium.configuration.default_page_width
      end

      # The classes to put on the surface, or nil for `:full`.
      def form_width_classes = Plutonium::UI::PageWidth.classes_for(resolved_form_width)

      def display_width_classes = Plutonium::UI::PageWidth.classes_for(resolved_display_width)
    end
  end
end
