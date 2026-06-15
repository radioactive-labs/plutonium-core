# frozen_string_literal: true

module Plutonium
  module Wizard
    # Presents a wizard {Step} in the shape the existing resource-form pipeline
    # (`Plutonium::UI::Form::Resource`) consumes from a definition (§7). The form
    # renders a step exactly like a resource/interaction definition by reading:
    #
    #   - `defined_fields`            — empty; a step carries no separate field
    #                                   config, only `input`s.
    #   - `defined_inputs`            — the step's merged inline + imported inputs
    #                                   (`{name => {options:, block:}}`).
    #   - `defined_structured_inputs` — the step's structured inputs.
    #   - `resolve_form_sections`     — the step's resolved form layout (inline
    #                                   `form_layout` or one inherited from `using:`),
    #                                   normalized to ResolvedSections; nil → single
    #                                   grid.
    #
    # This is the seam that lets a wizard step ride the resource-form rendering
    # path unchanged — seeded from the wizard's typed `data` (the form `object`),
    # which is what makes resume/back rehydration (including repeater rows) work.
    class StepAdapter
      def initialize(step)
        @step = step
      end

      attr_reader :step

      # The form's per-field config map. A step declares inputs, not fields, so
      # there is no separate `field` config — return an empty map. The form merges
      # `defined_fields[name]` (here {}) with `defined_inputs[name]`.
      def defined_fields = {}

      # `{name => {options:, block:}}` — inline + `using:`-imported inputs.
      def defined_inputs = step.inputs

      # `{name => {options:, block:}}` — structured (single/repeater) inputs.
      def defined_structured_inputs = step.structured_inputs

      # The resource form never imports nested-resource inputs from a wizard step.
      def defined_nested_inputs = {}

      # Auto-detect submit-and-continue is disabled for wizards (the wizard owns
      # its own Back/Next/Finish navigation).
      def submit_and_continue = false

      # Resolve the step's form layout into ordered ResolvedSections (the shape the
      # resource form's `resolve_form_layout` expects), or nil for a single grid.
      #
      # The step's `form_layout` is either:
      #   - inline  → an Array<FormLayout::Section> (unresolved), or
      #   - imported → an Array<FormLayout::ResolvedSection> (already resolved by
      #     the FieldImporter, filtered to imported fields).
      # Normalize both to ResolvedSections claiming only currently-permitted fields.
      def resolve_form_sections(resource_fields)
        layout = step.form_layout
        return nil if layout.blank?

        resource_fields = resource_fields.map(&:to_sym)
        return resolve_resolved_sections(layout, resource_fields) if layout.first.is_a?(Plutonium::Definition::FormLayout::ResolvedSection)

        resolve_raw_sections(layout, resource_fields)
      end

      private

      # An imported layout is already ResolvedSections; just restrict each section's
      # fields to the currently-permitted set (and drop emptied non-ungrouped ones).
      def resolve_resolved_sections(layout, resource_fields)
        known = resource_fields.to_set
        layout.filter_map do |resolved|
          fields = resolved.fields.map(&:to_sym).select { |f| known.include?(f) }
          next if fields.empty? && !resolved.section.ungrouped?
          Plutonium::Definition::FormLayout::ResolvedSection.new(resolved.section, fields)
        end
      end

      # Raw inline Sections — mirror Definition::FormLayout#resolve_form_sections:
      # first-section-wins ownership; unlisted permitted fields fall into a trailing
      # ungrouped bucket so nothing silently disappears.
      def resolve_raw_sections(layout, resource_fields)
        known = resource_fields.to_set

        owner = {}
        layout.each do |section|
          next if section.ungrouped?
          section.fields.map(&:to_sym).each { |f| owner[f] ||= section.key if known.include?(f) }
        end
        leftovers = resource_fields.reject { |f| owner.key?(f) }

        resolved = layout.map do |section|
          fields =
            if section.ungrouped?
              leftovers
            else
              section.fields.map(&:to_sym).select { |f| owner[f] == section.key }
            end
          Plutonium::Definition::FormLayout::ResolvedSection.new(section, fields)
        end

        unless layout.any?(&:ungrouped?)
          implicit = Plutonium::Definition::FormLayout::ResolvedSection.new(
            Plutonium::Definition::FormLayout::Section.new(
              key: Plutonium::Definition::FormLayout::UNGROUPED_KEY,
              fields: [].freeze, options: {}.freeze
            ),
            leftovers
          )
          resolved.push(implicit)
        end

        resolved
      end
    end
  end
end
