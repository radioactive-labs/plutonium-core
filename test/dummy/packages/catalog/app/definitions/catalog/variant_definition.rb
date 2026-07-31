class Catalog::VariantDefinition < Catalog::ResourceDefinition
  # Mode A drag-reorder. The model owns the storage
  # (`positioned_on :position, scope: :product_id`); this says the UI can be
  # reordered — including the NESTED variants table on a product show page,
  # which is where the reposition endpoint has to resolve the collection URL
  # through current_parent rather than the top-level /catalog_variants.
  position_on
end
