# frozen_string_literal: true

module Plutonium
  module Wizard
    # Resolves a step's `using:` option (§2.4) — importing a field surface from an
    # **interaction** or a **resource definition** instead of re-declaring it.
    #
    # The imported surface is:
    #   - **attribute_schema** ({name => type}) — types from the interaction's
    #     `attribute` declarations, or (for a definition) from the backing record
    #     class's `attribute_types`.
    #   - **inputs** ({name => {options:, block:}}) — the source's `input` config,
    #     sliced to the imported names.
    #   - **form_layout** — the source's `defined_form_layout`, filtered to the
    #     imported fields (skipped when `layout: false`).
    #   - **validate_fn** — runs the source's `valid?` over a data slice and keeps
    #     errors only on the imported fields **plus `:base`** (skipped when
    #     `validate: false`).
    #
    # Validation is *run-and-filtered* rather than cloned: AR/ActiveModel validators
    # can't be cloned cleanly, and one mechanism covers both targets. Filtering to
    # imported fields + `:base` is what prevents a partial model reporting presence
    # errors for columns this step never collects.
    module FieldImporter
      # The resolved import surface for one `using:` declaration.
      Spec = Struct.new(:attribute_schema, :inputs, :form_layout, :validate_fn, keyword_init: true) do
        # Run the imported validation over a staged data slice, returning a hash of
        # {attribute => [messages]} for the imported fields + :base. Empty when
        # `validate: false`.
        def validate(data_slice)
          validate_fn ? validate_fn.call(data_slice) : {}
        end
      end

      class << self
        # @param using [Class] an interaction or resource definition class
        # @param opts [Hash] fields:/only:/except:/validate:/layout:/validation_context:
        # @return [Spec]
        def resolve(using:, opts:)
          opts ||= {}
          only = normalize(opts[:fields] || opts[:only])
          except = normalize(opts[:except]) || []
          do_validate = opts.fetch(:validate, true)
          do_layout = opts.fetch(:layout, true)
          context = opts[:validation_context]

          if interaction?(using)
            from_interaction(using, only:, except:, do_validate:, do_layout:, context:)
          else
            from_definition(using, only:, except:, do_validate:, do_layout:, context:)
          end
        end

        private

        def interaction?(klass)
          klass.is_a?(Class) && klass < Plutonium::Interaction::Base
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

        # --- interaction target ---
        #
        # Types come straight from the interaction's `attribute :x, :type`
        # declarations; validation instantiates the interaction and runs `valid?`.
        def from_interaction(klass, only:, except:, do_validate:, do_layout:, context:)
          names = select(klass.attribute_names.map(&:to_sym), only:, except:)
          schema = names.index_with { |n| klass.attribute_types[n.to_s].type }

          validate_fn = build_validate(do_validate) do |slice|
            obj = klass.new(view_context: nil)
            obj.attributes = string_slice(slice, names)
            run_and_filter(obj, names, context)
          end

          Spec.new(
            attribute_schema: schema,
            inputs: klass.defined_inputs.slice(*names),
            form_layout: do_layout ? layout_for(klass, names) : nil,
            validate_fn:
          )
        end

        # --- resource-definition target ---
        #
        # The field's TYPE comes from the backing record class
        # (`Model.attribute_types`); the definition's `field`/`input` config (as:,
        # options, label) is overlaid (input wins, matching the form pipeline).
        # Validation runs against a transient `Model.new(slice)`.
        #
        # The importable surface is the union of the definition's `field` and
        # `input` declarations — both render on the form — in field-then-input
        # declaration order.
        def from_definition(defn, only:, except:, do_validate:, do_layout:, context:)
          model = model_class_for(defn)
          fields = defn.defined_fields
          inputs = defn.defined_inputs

          available = (fields.keys + inputs.keys).map(&:to_sym).uniq
          names = select(available, only:, except:)
          schema = names.index_with { |n| record_type(model, n) }
          imported_inputs = names.index_with { |n| overlay_field_input(fields[n], inputs[n]) }

          validate_fn = build_validate(do_validate) do |slice|
            record = model.new(string_slice(slice, names))
            run_and_filter(record, names, context)
          end

          Spec.new(
            attribute_schema: schema,
            inputs: imported_inputs,
            form_layout: do_layout ? layout_for(defn, names) : nil,
            validate_fn:
          )
        end

        # Merge a definition's `field` and `input` declaration for one name into a
        # single {options:, block:} input spec — the `input` declaration wins on
        # conflicting options (matching the resource form pipeline).
        def overlay_field_input(field, input)
          field ||= {}
          input ||= {}
          options = (field[:options] || {}).merge(input[:options] || {})
          block = input[:block] || field[:block]
          {options:, block:}.compact
        end

        # A resource definition carries no model reference; the framework binds them
        # by name convention (`FooDefinition` ↔ `Foo`), the same mapping the resource
        # controller uses (`"#{resource_class}Definition".constantize`).
        def model_class_for(defn)
          name = defn.name
          unless name&.end_with?("Definition")
            raise ArgumentError,
              "cannot infer a record class for #{defn.inspect}: a `using:` definition " \
              "must be a named `*Definition` class"
          end
          name.delete_suffix("Definition").constantize
        end

        def record_type(model, name)
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

        # Inherit the source's form_layout, filtered to the imported fields: each
        # declared section keeps only the imported fields it lists; sections that
        # resolve to zero imported fields are dropped.
        def layout_for(source, names)
          layout = source.defined_form_layout
          return nil unless layout

          keep = names.to_set
          layout.filter_map do |section|
            next if section.ungrouped?
            fields = section.fields.map(&:to_sym).select { |f| keep.include?(f) }
            next if fields.empty?
            Plutonium::Definition::FormLayout::ResolvedSection.new(section, fields)
          end
        end
      end
    end
  end
end
