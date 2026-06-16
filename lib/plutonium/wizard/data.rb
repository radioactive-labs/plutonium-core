# frozen_string_literal: true

module Plutonium
  module Wizard
    # Builds the wizard's typed `data` snapshot (§2.6). `data` is **step-keyed**: a
    # container exposing one typed sub-object per step, so fields are addressed as
    # `data.<step>.<field>` (e.g. `data.identity.name`, `data.profile.tier`). Each
    # step sub-object is backed by ActiveModel::Attributes — scalar values are cast
    # to their declared types and uncollected fields read as `nil`. Step namespacing
    # means two steps may declare the same field name without colliding.
    #
    # `structured_input ..., repeat:` collections (which declare no scalar types —
    # their sub-fields come from `input` declarations) are exposed on their step's
    # sub-object as arrays of typed sub-objects responding to the declared sub-field
    # names (`data.members.invites.first.email`).
    module Data
      # A read-only row inside a structured collection. Responds to each declared
      # sub-field; values are exposed as-is (string-typed, since structured inputs
      # carry no scalar type declarations).
      class StructuredRow
        def initialize(fields, values)
          @values = values
          fields.each do |field|
            define_singleton_method(field) { @values[field.to_s] }
          end
        end

        def [](key) = @values[key.to_s]

        def to_h = @values.dup
      end

      # @param schema [Hash{Symbol=>Symbol}] scalar attribute name => type
      # @param options [Hash{Symbol=>Hash}] scalar attribute name => options (default:, etc.)
      # @param structured [Hash{Symbol=>Array<Symbol>}] structured name => sub-field names
      def self.class_for(schema, options: {}, structured: {})
        Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes

          # Anonymous classes have no name, which breaks label/error translation
          # lookups (`human_attribute_name` / `errors.full_messages` call
          # `model_name`). Supply a stable one so the form/display pipelines can
          # humanize attribute labels.
          def self.model_name = ActiveModel::Name.new(self, nil, "Wizard")

          schema.each do |name, type|
            attribute(name, Plutonium::Wizard.safe_attribute_type(type), **(options[name] || {}))
          end

          structured.each do |name, fields|
            # Backed by a plain accessor (not an ActiveModel attribute) so the raw
            # array survives without coercion, then wrapped on read.
            attr_writer name
            define_method(name) do
              rows = Array(instance_variable_get(:"@#{name}"))
              rows.map do |row|
                values = row.respond_to?(:to_h) ? row.to_h.transform_keys(&:to_s) : {}
                StructuredRow.new(fields, values)
              end
            end
          end

          # Accept the union of scalar + structured keys, ignoring unknown keys.
          define_method(:initialize) do |attrs = {}|
            attrs = (attrs || {}).symbolize_keys
            scalar = attrs.slice(*schema.keys)
            super(scalar)
            structured.each_key do |name|
              instance_variable_set(:"@#{name}", attrs[name] || [])
            end
          end

          # Typed plain-hash view: cast scalars + structured rows as hashes.
          define_method(:to_h) do
            h = {}
            schema.each_key { |name| h[name] = public_send(name) }
            structured.each_key { |name| h[name] = public_send(name).map(&:to_h) }
            h
          end
        end
      end

      # The step-keyed `data` snapshot — a thin dispatcher over the per-step typed
      # sub-objects (§2.6). `data.identity` (via method_missing) or `data[:identity]`
      # returns the step's typed sub-object, built lazily from its nested data slice
      # and memoized; an unknown step key returns nil. `to_h` gives the nested
      # `{step => {field => value}}` view.
      #
      # A plain object (not a generated class) so it isn't rebuilt every time the
      # runner reassigns `data_attributes`; the per-step typed classes are built
      # once per wizard class and passed in.
      class Container
        # @param step_classes [Hash{Symbol=>Class}] step key => typed sub-object class
        # @param attrs [Hash] nested staged data ({step_key => {field => value}})
        def initialize(step_classes, attrs = {})
          @step_classes = step_classes
          @attrs = (attrs || {}).transform_keys(&:to_sym)
          @objects = {}
        end

        # The typed sub-object for a step (lazy + memoized); nil for an unknown step.
        def [](key)
          key = key.to_sym
          return nil unless @step_classes.key?(key)
          @objects[key] ||= @step_classes[key].new(@attrs[key] || {})
        end

        # The declared step keys, in order.
        def step_keys = @step_classes.keys

        # Nested typed hash: {step_key => {field => value}}.
        def to_h = @step_classes.keys.index_with { |key| self[key].to_h }

        def respond_to_missing?(name, include_private = false)
          @step_classes.key?(name.to_sym) || super
        end

        # `data.identity` → the identity step's typed sub-object.
        def method_missing(name, *args)
          return self[name] if args.empty? && @step_classes.key?(name.to_sym)
          super
        end
      end
    end
  end
end
