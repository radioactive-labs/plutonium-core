# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      module Behaviour
        extend ActiveSupport::Concern
        include Phlexi::Field::Common::Tokens
        include Methods
        include Kit
        include Tokens

        # Phlexi field-builder options that configure the field itself, not the
        # rendered tag. Each surface routes its OWN keys to `field()` (displays
        # say :description, forms say :hint) and strips the UNION from the tag
        # attributes, so a key declared on the wrong surface is dropped rather
        # than leaked as an HTML attribute.
        DISPLAY_FIELD_LEVEL_KEYS = %i[label description placeholder].freeze
        FORM_FIELD_LEVEL_KEYS = %i[hint label placeholder].freeze
        FIELD_LEVEL_KEYS = (DISPLAY_FIELD_LEVEL_KEYS | FORM_FIELD_LEVEL_KEYS).freeze

        # Table-column options that configure the header, not the cell. They may
        # be declared on `field`, `display` or `column` and flow to the column
        # without making the column "render alone" (see Table::Resource).
        COLUMN_FIELD_LEVEL_KEYS = %i[label align].freeze

        if Rails.env.development?
          def around_template(&)
            comment { "open:#{self.class.name}" }
            super
            comment { "close:#{self.class.name}" }
          end
        end

        protected

        # Translate one of Plutonium's own strings. Full keys only
        # (`t("plutonium.ui.table.filters")`), so every call site is greppable.
        def t(key, **options)
          Plutonium::Translation.t(key, **options)
        end

        # Resolve proc-valued help / header options (label, hint, description,
        # placeholder, align) for this render, so `label: t("...")` and other
        # lazy values work on displays, tables and forms alike. Other option
        # keys are left alone: a `formatter:` or `condition:` proc is a
        # callback, not a value. Same arity rule as Form::Resource: a zero-arity
        # proc keeps its own binding, a one-arity proc receives this component.
        def resolve_field_level_procs(options)
          return options if options.blank?

          resolvable_keys = FIELD_LEVEL_KEYS | COLUMN_FIELD_LEVEL_KEYS
          options.to_h do |key, value|
            next [key, value] unless value.is_a?(Proc) && resolvable_keys.include?(key)

            [key, value.arity.zero? ? value.call : value.call(self)]
          end
        end

        def phlexi_render(arg, &)
          return unless arg
          raise ArgumentError, "phlexi_render requires a default render block" unless block_given?

          # Handle Phlex components or Rails Renderables
          if arg.class < Phlex::SGML || arg.respond_to?(:render_in)
            render arg
          # Handle procs
          elsif arg.respond_to?(:to_proc)
            instance_exec(&arg)
          else
            yield arg
          end
        end
      end
    end
  end
end
