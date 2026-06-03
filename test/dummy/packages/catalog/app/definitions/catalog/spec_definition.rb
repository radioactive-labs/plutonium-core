class Catalog::SpecDefinition < Catalog::ResourceDefinition
  # Both versions are sourced from `using:` fields classes:
  #   payload → single hash, with `fields:` restricting `sku` away
  #   rows    → repeater (array of hashes)
  structured_input :payload, using: Catalog::SpecPayloadFields, fields: %i[title notes]
  structured_input :rows, repeat: 5, using: Catalog::SpecRowFields
end
