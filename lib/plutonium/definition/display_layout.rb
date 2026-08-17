# frozen_string_literal: true

module Plutonium
  module Definition
    # Declarative display sectioning — the `display_layout` counterpart to
    # {FormLayout}, applied to the show page's field grid instead of the
    # form. Same shape (`section`/`ungrouped`, first-section-wins ownership,
    # `condition:`) and the same resolution semantics, so a section/field
    # author only has to learn the DSL once.
    #
    # Reuses {FormLayout}'s `Section`/`ResolvedSection` structs and its
    # ownership-resolution algorithm ({FormLayout.resolve_sections}) rather
    # than duplicating them — the algorithm has nothing form-specific about
    # it, only the declaring macro and the render target differ.
    #
    # Deliberately does NOT support `columns:`. The display side already has
    # a per-field width pathway — `display :x, wrapper: {class: "col-span-2"}`
    # — and every section renders into the same responsive grid, so a second,
    # section-level column mechanism would be a redundant way to say the same
    # thing. Grouping is what this DSL is for; widths stay on the field. A
    # `columns:` option raises rather than being silently dropped.
    #
    # @example
    #   display_layout do
    #     section :identity, :name, :email, label: "Identification"
    #     section :address, :street, :city, collapsible: true,
    #       condition: -> { object.requires_address? }
    #     ungrouped label: "Other"
    #   end
    module DisplayLayout
      extend ActiveSupport::Concern

      # Collects section/ungrouped calls from a display_layout block, in
      # order. Builds the same Section struct FormLayout uses — the two
      # layouts share a resolver, so they share a value type.
      class Builder
        attr_reader :sections

        def initialize
          @sections = []
          @ungrouped_seen = false
        end

        def section(key, *fields, **options)
          if key == FormLayout::UNGROUPED_KEY
            raise ArgumentError,
              "`section :#{FormLayout::UNGROUPED_KEY}` is reserved — use the `ungrouped` macro"
          end
          reject_columns!(options)
          @sections << FormLayout::Section.new(key:, fields: fields.freeze, options: options.freeze)
        end

        def ungrouped(**options)
          raise ArgumentError, "`ungrouped` may only be declared once" if @ungrouped_seen
          @ungrouped_seen = true
          reject_columns!(options)
          @sections << FormLayout::Section.new(
            key: FormLayout::UNGROUPED_KEY, fields: [].freeze, options: options.freeze
          )
        end

        private

        # `columns:` is a form_layout option only. Raising (rather than
        # ignoring it) means an author who copies a form_layout block across
        # finds out immediately, instead of wondering why the column count
        # had no effect.
        def reject_columns!(options)
          return unless options.key?(:columns)
          raise ArgumentError,
            "display_layout does not support `columns:` — set a width on the field instead, " \
            "e.g. `display :x, wrapper: {class: \"col-span-2\"}`"
        end
      end

      class_methods do
        # Declare the display layout. Re-declaring replaces it as a unit.
        def display_layout(&block)
          raise ArgumentError, "`display_layout` requires a block" unless block
          builder = Builder.new
          builder.instance_exec(&block)
          @defined_display_layout = builder.sections.freeze
        end

        # Ordered Array<FormLayout::Section>, or nil when no layout was declared.
        def defined_display_layout
          @defined_display_layout
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@defined_display_layout, defined_display_layout&.dup)
        end
      end

      # Instance access — the display render path holds a definition
      # instance (mirrors the defineable_prop convention).
      def defined_display_layout
        self.class.defined_display_layout
      end

      # Resolve the policy-filtered field list into ordered ResolvedSections.
      # Returns nil when no layout is declared (caller falls back to one grid).
      def resolve_display_sections(resource_fields)
        layout = defined_display_layout
        return nil unless layout

        FormLayout.resolve_sections(layout, resource_fields)
      end
    end
  end
end
