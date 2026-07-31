# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      # Turns a resolved `as:` into a component, for every surface that renders a
      # field: forms, displays, tables, filter forms and the wizard summary.
      #
      # `as:` is a union — a built-in alias (Symbol/String, dispatched to the
      # builder's `#{alias}_tag` method) or a component Class rendered directly
      # (see {Plutonium::Definition::InputAliases}). Every surface has to handle
      # BOTH, so the branch lives here instead of being re-implemented per view —
      # a table or filter form that hand-rolled only the alias half raised
      # `NoMethodError: MyPickerComponent_tag` on an `as:` a form rendered
      # happily.
      #
      # A component Class is instantiated with the field builder (the contract
      # every built-in tag component follows), so `as:` takes FIELD components; a
      # component with its own constructor goes through the block form
      # (`input :x do |field| MyComponent.new(value: field.value) end`).
      #
      # Mixed into the form and display field builders, so it is available on
      # every `f` a view yields (including the table's display builder).
      module ResolvesTags
        # @param tag [Symbol, String, Class, nil] a built-in alias, a component
        #   class, or nil to infer the tag from the field's type.
        # @param attributes [Hash] tag attributes. Reach a component class the
        #   same way they reach an alias tag — via `Components::Base#attributes`
        #   — so `as:` declarations honour the surface's own attributes (the
        #   filter panel's `class: "w-full"`, a form's `pre_submit` action)
        #   instead of silently dropping them.
        # @return [Phlex::SGML] the component to render.
        def component_for(tag, **attributes, &)
          tag ||= inferred_field_component
          return create_component(tag, component_theme_key(tag), **attributes, &) if tag.is_a?(Class)

          send(:"#{tag}_tag", **attributes, &)
        end

        private

        # Theme key for a directly-rendered component class:
        # `Admin::ColorPickerComponent` themes off `:color_picker`.
        #
        # The `_?` matters — dropping a bare `component$` left the separator
        # behind, so the key was `:color_picker_` and a theme entry written for
        # the obvious `:color_picker` silently never matched. Nothing in the
        # framework keys off this (built-in tags pass their key to
        # `create_component` explicitly); it is reached only for a user's `as:`
        # class, which is exactly the case that was broken.
        def component_theme_key(component_class)
          component_class.name.demodulize.underscore.sub(/_?component$/, "").to_sym
        end
      end
    end
  end
end
