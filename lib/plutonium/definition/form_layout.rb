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
      Section = Struct.new(:key, :fields, :options, keyword_init: true) do
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
      ResolvedSection = Struct.new(:section, :fields, keyword_init: true)

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

        resource_fields = resource_fields.map(&:to_sym)
        known = resource_fields.to_set

        # First-section-wins assignment: map each field to the first section key.
        owner = {}
        layout.each do |section|
          next if section.ungrouped?
          section.fields.each do |f|
            unless known.include?(f)
              raise ArgumentError,
                "form_layout section :#{section.key} references unknown field :#{f}"
            end
            owner[f] ||= section.key
          end
        end
        leftovers = resource_fields.reject { |f| owner.key?(f) }

        resolved = layout.map do |section|
          fields =
            if section.ungrouped?
              leftovers
            else
              section.fields.select { |f| owner[f] == section.key }
            end
          ResolvedSection.new(section:, fields:)
        end

        unless layout.any?(&:ungrouped?)
          implicit = ResolvedSection.new(
            section: Section.new(key: UNGROUPED_KEY, fields: [].freeze, options: {}.freeze),
            fields: leftovers
          )
          resolved.push(implicit)
        end

        resolved
      end
    end
  end
end
