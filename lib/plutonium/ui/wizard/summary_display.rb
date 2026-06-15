# frozen_string_literal: true

module Plutonium
  module UI
    module Wizard
      # A tiny read-only display over the wizard's typed `data` snapshot, used by
      # the review step's auto-summary (§2.5). Reuses the Plutonium display
      # pipeline (`Display::Base` + its inferred-type builder + `field(...).wrapped`)
      # so each field's label and value formatting match the rest of the app,
      # rather than re-implementing value rendering.
      class SummaryDisplay < Plutonium::UI::Display::Base
        # @param object [Object] the wizard `data` snapshot.
        # @param fields [Array<Symbol>] scalar field names to summarize.
        # @param inputs [Hash] the step's input config ({name => {options:}}), so a
        #   field's declared `as:` informs the display component (e.g. a `:text`
        #   input renders via the markdown/text display tag).
        def initialize(object, fields:, inputs: {}, **options)
          options[:key] = :wizard
          @summary_fields = fields
          @summary_inputs = inputs
          super(object, **options)
        end

        def display_template
          dl(class: "grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3") do
            @summary_fields.each { |name| render_summary_field(name) }
          end
        end

        private

        def render_summary_field(name)
          input_options = @summary_inputs[name]&.dig(:options) || {}
          field_options = input_options[:label] ? {label: input_options[:label]} : {}
          render field(name, **field_options).wrapped do |f|
            # Wizard `data` holds plain typed scalars, so a string display covers
            # every value — no association/attachment components are in play.
            render f.string_tag
          end
        end
      end
    end
  end
end
