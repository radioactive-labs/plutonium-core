class Catalog::SpecDefinition < Catalog::ResourceDefinition
  # `using:` versions — sourced from standalone fields classes:
  #   payload → single hash, with `fields:` restricting `sku` away
  #   rows    → repeater (array of hashes)
  structured_input :payload, using: Catalog::SpecPayloadFields, fields: %i[title notes]
  structured_input :rows, repeat: 5, using: Catalog::SpecRowFields

  # Inline-block versions — same two shapes, fields declared in a block:
  #   meta  → single hash
  #   items → repeater (array of hashes)
  structured_input :meta do |f|
    f.input :heading
    f.input :body
  end

  structured_input :items, repeat: 5 do |f|
    f.input :label
    f.input :amount
  end
end
