# frozen_string_literal: true

module Plutonium
  module Wizard
    # Resolves a step's `using:` option (§2.4) — importing a field surface from a
    # **model (ActiveRecord class)** instead of re-declaring it.
    #
    # `using:` targets a model only. A `Plutonium::Resource::Definition` carries no
    # link to its model (it's an empty class the controller binds at request time),
    # so the only reliable direction is **model → definition**: the importer
    # auto-resolves `"#{Model}Definition"` to overlay input styling, best-effort.
    #
    # The imported surface is:
    #   - **attribute_schema** ({name => type}) — the field universe is
    #     `Model.attribute_names` (filtered by selectors); types are
    #     `Model.attribute_types[name].type`.
    #   - **inputs** ({name => {options:, block:}}) — overlaid from the resolved
    #     `<Model>Definition`'s `field`/`input` config (`as:`, options, labels),
    #     sliced to the imported names. No definition → empty input config.
    #   - **form_layout** — the resolved `<Model>Definition`'s `defined_form_layout`,
    #     filtered to the imported fields, **plus a trailing ungrouped section** for
    #     imported fields not named in any explicit section (skipped when
    #     `layout: false`).
    #   - **validate_fn** — runs a transient `Model.new(slice).valid?` and keeps
    #     errors only on the imported fields **plus `:base`** (skipped when
    #     `validate: false`).
    #
    # Validation is *run-and-filtered* rather than cloned: AR validators can't be
    # cloned cleanly. Filtering to imported fields + `:base` is what prevents a
    # partial model reporting presence errors for columns this step never collects.
    module FieldImporter
      # The validator kinds the form pipeline reads for field metadata (required
      # marker, maxlength/minlength, min/max, pattern, auto-choices). Other kinds
      # (uniqueness, custom EachValidators) carry no form meaning, so we skip them
      # — and replaying a custom kind through `validates` would raise.
      FORM_VALIDATOR_KINDS = %i[presence length numericality format inclusion].freeze

      # The resolved import surface for one `using:` declaration.
      Spec = Struct.new(:attribute_schema, :inputs, :form_layout, :validate_fn, :form_validators) do
        # Run the imported validation over a staged data slice, returning a hash of
        # {attribute => [messages]} for the imported fields + :base. Empty when
        # `validate: false`.
        def validate(data_slice)
          validate_fn ? validate_fn.call(data_slice) : {}
        end
      end

      class << self
        # @param using [Class] an ActiveRecord model class
        # @param opts [Hash] fields:/only:/except:/validate:/layout:/validation_context:
        # @return [Spec]
        def resolve(using:, opts:)
          model = model!(using)
          opts ||= {}
          only = normalize(opts[:fields] || opts[:only])
          except = normalize(opts[:except]) || []
          do_validate = opts.fetch(:validate, true)
          do_layout = opts.fetch(:layout, true)
          context = opts[:validation_context]

          names = select(model.attribute_names.map(&:to_sym), only:, except:)
          definition = "#{model.name}Definition".safe_constantize

          schema = names.index_with { |n| record_type(model, n) }

          validate_fn = build_validate(do_validate) do |slice|
            record = model.new(string_slice(slice, names))
            run_and_filter(record, names, context)
          end

          Spec.new(
            attribute_schema: schema,
            inputs: inputs_for(definition, names),
            form_layout: do_layout ? layout_for(definition, names) : nil,
            validate_fn:,
            form_validators: form_validators_for(model, names)
          )
        end

        private

        # The imported fields' form-relevant validators, as raw `[[name], options]`
        # pairs replayable through `validates` onto the typed data class — so the
        # form pipeline surfaces imported required/length/etc. the same as inline
        # `validates`. Kept SEPARATE from `validate_fn`: the runner validates
        # imported fields through the transient model, so these must not feed it.
        def form_validators_for(model, names)
          names.flat_map do |name|
            model.validators_on(name).filter_map do |validator|
              next unless FORM_VALIDATOR_KINDS.include?(validator.kind)
              [[name], {validator.kind => validator.options.presence || true}]
            end
          end
        end

        # `using:` accepts a model class only. Anything else is a programming error.
        def model!(using)
          unless using.is_a?(Class) && using < ActiveRecord::Base
            raise ArgumentError,
              "using: expects a model class (an ActiveRecord::Base subclass), got #{using.inspect}"
          end
          using
        end

        def normalize(value)
          return nil if value.nil?
          Array(value).map(&:to_sym).presence
        end

        # `names & only` preserves source order while restricting to the selection.
        def select(names, only:, except:)
          names = names.select { |n| only.include?(n) } if only
          names - except
        end

        def record_type(model, name)
          # AR enum columns are integer-backed, but forms submit the string enum
          # *key* ("active"), not the integer. Importing the raw :integer type would
          # cast the key to 0. Keep enum fields as :string so the key round-trips —
          # the author's `Model.new(field: data.field)` then lets AR map key → int,
          # and the review summary shows the key, not a meaningless integer.
          return :string if model.defined_enums.key?(name.to_s)
          model.attribute_types[name.to_s]&.type || :string
        end

        def string_slice(slice, names)
          slice = (slice || {}).stringify_keys
          slice.slice(*names.map(&:to_s))
        end

        def build_validate(do_validate, &block)
          do_validate ? block : nil
        end

        # Run `valid?` (with the optional context) and keep only the errors on the
        # imported fields + :base.
        def run_and_filter(obj, names, context)
          context ? obj.valid?(context) : obj.valid?
          keep = names + [:base]
          obj.errors.group_by_attribute.slice(*keep)
        end

        # Build an input config for every imported name (so each gets rendered),
        # overlaying styling from the resolved `<Model>Definition` where present. A
        # definition's `field` and `input` declarations both render on the form;
        # merge them per name (input wins on conflicting options, matching the
        # resource form pipeline). No definition → each name maps to an empty config.
        def inputs_for(definition, names)
          fields = definition&.defined_fields || {}
          inputs = definition&.defined_inputs || {}
          names.index_with { |n| overlay_field_input(fields[n], inputs[n]) }
        end

        def overlay_field_input(field, input)
          field ||= {}
          input ||= {}
          options = (field[:options] || {}).merge(input[:options] || {})
          block = input[:block] || field[:block]
          {options: options.presence, block:}.compact
        end

        # Inherit the resolved definition's form_layout, filtered to the imported
        # fields. Mirrors the canonical `resolve_form_sections` leftover handling
        # (form_layout.rb): each imported field is claimed by the first explicit
        # section that lists it; imported fields no section names fall into a
        # trailing **ungrouped** section, so none silently disappears.
        def layout_for(definition, names)
          return nil unless definition
          layout = definition.defined_form_layout
          return nil unless layout

          imported = names.to_set

          # First-section-wins ownership among imported fields.
          owner = {}
          layout.each do |section|
            next if section.ungrouped?
            section.fields.map(&:to_sym).each do |f|
              owner[f] ||= section.key if imported.include?(f)
            end
          end
          leftovers = names.reject { |f| owner.key?(f) }

          resolved = layout.filter_map do |section|
            fields =
              if section.ungrouped?
                leftovers
              else
                section.fields.map(&:to_sym).select { |f| owner[f] == section.key }
              end
            # Drop explicit sections that resolve to zero imported fields; keep an
            # explicit ungrouped section as the leftover home even when empty-listed.
            next if fields.empty? && !section.ungrouped?
            Plutonium::Definition::FormLayout::ResolvedSection.new(section, fields)
          end

          # No explicit ungrouped section, but leftover imported fields exist →
          # synthesize a trailing ungrouped section so nothing disappears.
          if leftovers.any? && layout.none?(&:ungrouped?)
            ungrouped = Plutonium::Definition::FormLayout::Section.new(
              key: Plutonium::Definition::FormLayout::UNGROUPED_KEY,
              fields: [].freeze,
              options: {}.freeze
            )
            resolved.push(Plutonium::Definition::FormLayout::ResolvedSection.new(ungrouped, leftovers))
          end

          resolved
        end
      end
    end
  end
end
