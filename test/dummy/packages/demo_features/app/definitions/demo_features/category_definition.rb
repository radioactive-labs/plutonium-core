class DemoFeatures::CategoryDefinition < DemoFeatures::ResourceDefinition
  action :bulk_set_description, interaction: DemoFeatures::BulkSetCategoryDescription
end
