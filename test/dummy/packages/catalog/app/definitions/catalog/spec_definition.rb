class Catalog::SpecDefinition < Catalog::ResourceDefinition
  # `payload` exercises the `using:` + `fields:` path (`sku` is declared on the
  # fields class but restricted away here); `rows` exercises the inline block.
  structured_input :payload, using: Catalog::SpecPayloadFields, fields: %i[title notes]

  structured_input :rows, repeat: 5 do |f|
    f.input :key
    f.input :value
  end
end
