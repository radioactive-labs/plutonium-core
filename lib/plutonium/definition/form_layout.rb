# frozen_string_literal: true

module Plutonium
  module Definition
    # Declarative form sectioning. Mixed into both resource definitions and
    # interactions (mirrors StructuredInputs). The layout references field KEYS
    # only and carries section-level options; per-field config stays on `input`.
    #
    # @example
    #   form_layout do
    #     section :identity, :name, :email, label: "Your identification"
    #     section :address, :street, :city, collapsible: true, columns: 2,
    #       condition: -> { object.requires_address? }
    #     ungrouped label: "Other"
    #   end
    module FormLayout
      extend ActiveSupport::Concern

      UNGROUPED_KEY = :ungrouped

      # One declared section, or the implicit `ungrouped` bucket (empty `fields`).
      Section = Struct.new(:key, :fields, :options) do
        def ungrouped? = key == UNGROUPED_KEY
        def label = options[:label] || key.to_s.humanize
        def description = options[:description]
        def collapsible? = !!options[:collapsible]
        def collapsed? = !!options[:collapsed]
        def columns = options[:columns]
        def condition = options[:condition]
      end

      # A section paired with the concrete fields it will render (after policy
      # filtering). Produced by #resolve_form_sections (a later task).
      ResolvedSection = Struct.new(:section, :fields)

      # First-section-wins ownership, shared by every layout resolver (the resource
      # form via {#resolve_form_sections}, and the wizard's {StepAdapter} /
      # {FieldImporter}). Each field is claimed by the FIRST explicit section that
      # lists it, restricted to the currently-permitted `fields`; a listed field
      # outside that set is simply skipped (never renders, never an error).
      #
      # @param layout [Array<Section>]
      # @param fields [Array<Symbol,String>] the permitted field set, in order
      # @return [Array(Hash, Array<Symbol>)] `[owner_by_field, leftover_fields]`
      def self.assign_ownership(layout, fields)
        fields = fields.map(&:to_sym)
        known = fields.to_set
        owner = {}
        layout.each do |section|
          next if section.ungrouped?
          section.fields.map(&:to_sym).each { |f| owner[f] ||= section.key if known.include?(f) }
        end
        leftovers = fields.reject { |f| owner.key?(f) }
        [owner, leftovers]
      end

      # The canonical resolution: first-section-wins ownership, with unclaimed
      # permitted fields falling into the (explicit, or a synthesized trailing)
      # ungrouped bucket so nothing silently disappears. Every declared section is
      # kept (empty ones are dropped at render). Shared by {#resolve_form_sections}
      # and the wizard {StepAdapter}'s raw-layout path so the two never drift.
      #
      # @param layout [Array<Section>]
      # @param fields [Array<Symbol,String>] the permitted field set, in order
      # @return [Array<ResolvedSection>]
      def self.resolve_sections(layout, fields)
        owner, leftovers = assign_ownership(layout, fields)

        resolved = layout.map do |section|
          section_fields =
            if section.ungrouped?
              leftovers
            else
              section.fields.map(&:to_sym).select { |f| owner[f] == section.key }
            end
          ResolvedSection.new(section:, fields: section_fields)
        end

        unless layout.any?(&:ungrouped?)
          resolved.push(ResolvedSection.new(
            section: Section.new(key: UNGROUPED_KEY, fields: [].freeze, options: {}.freeze),
            fields: leftovers
          ))
        end

        resolved
      end

      # Collects section/ungrouped calls from a form_layout block in order.
      class Builder
        attr_reader :sections

        def initialize
          @sections = []
          @ungrouped_seen = false
        end

        def section(key, *fields, **options)
          if key == UNGROUPED_KEY
            raise ArgumentError,
              "`section :#{UNGROUPED_KEY}` is reserved — use the `ungrouped` macro"
          end
          validate_columns!(options)
          @sections << Section.new(key:, fields: fields.freeze, options: options.freeze)
        end

        def ungrouped(**options)
          raise ArgumentError, "`ungrouped` may only be declared once" if @ungrouped_seen
          @ungrouped_seen = true
          validate_columns!(options)
          @sections << Section.new(key: UNGROUPED_KEY, fields: [].freeze, options: options.freeze)
        end

        private

        def validate_columns!(options)
          return unless options.key?(:columns)
          value = options[:columns]
          unless Integer === value && value > 0
            raise ArgumentError,
              "form_layout :columns must be a positive Integer, got #{value.inspect}"
          end
        end
      end

      class_methods do
        # Declare the form layout. Re-declaring replaces it as a unit.
        def form_layout(&block)
          raise ArgumentError, "`form_layout` requires a block" unless block
          builder = Builder.new
          builder.instance_exec(&block)
          @defined_form_layout = builder.sections.freeze
        end

        # Ordered Array<Section>, or nil when no layout was declared.
        def defined_form_layout
          @defined_form_layout
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@defined_form_layout, defined_form_layout&.dup)
        end
      end

      # Instance access — the form render path holds a definition/interaction
      # instance (mirrors the defineable_prop convention).
      def defined_form_layout
        self.class.defined_form_layout
      end

      # Resolve the policy-filtered field list into ordered ResolvedSections.
      # Returns nil when no layout is declared (caller falls back to one grid).
      def resolve_form_sections(resource_fields)
        layout = defined_form_layout
        return nil unless layout

        FormLayout.resolve_sections(layout, resource_fields)
      end
    end
  end
end
