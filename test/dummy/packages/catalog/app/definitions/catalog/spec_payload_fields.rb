# Fieldset class referenced by `structured_input :payload, using:` — exercises
# the `using:` path (vs the inline-block path used by `rows`).
class Catalog::SpecPayloadFields < Plutonium::Definition::StructuredInputs::FieldsDefinition
  input :title
  input :notes
  input :sku # declared here but restricted away by `fields:` in the definition
end
