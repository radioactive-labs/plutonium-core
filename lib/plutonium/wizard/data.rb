# frozen_string_literal: true

module Plutonium
  module Wizard
    # Builds a typed, dot-accessible snapshot class from a wizard's union schema
    # (§2.6). Backed by ActiveModel::Attributes so scalar values are cast to their
    # declared types and uncollected fields read as `nil`.
    #
    # `structured_input ..., repeat:` collections (which declare no scalar types —
    # their sub-fields come from `input` declarations) are exposed as arrays of
    # typed sub-objects responding to the declared sub-field names
    # (`data.invites.first.email`).
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

          schema.each { |name, type| attribute(name, type, **(options[name] || {})) }

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
        end
      end
    end
  end
end
