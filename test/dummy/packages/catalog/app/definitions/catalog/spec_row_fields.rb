# Fieldset class referenced by `structured_input :rows, repeat:, using:` —
# exercises the `using:` path on a repeater (array-of-hashes) structured input.
class Catalog::SpecRowFields < Plutonium::Definition::StructuredInputs::FieldsDefinition
  input :key
  input :value
end
