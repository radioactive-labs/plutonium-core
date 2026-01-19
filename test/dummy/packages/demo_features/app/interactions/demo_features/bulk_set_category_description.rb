# Define your interaction
class DemoFeatures::BulkSetCategoryDescription < DemoFeatures::ResourceInteraction
  # Presentation
  presents label: "Set Description",
    icon: Phlex::TablerIcons::Edit

  # Having `attribute :resources` (plural) makes this a bulk action
  attribute :resources

  # User input
  attribute :description, :string

  validates :description, presence: true

  private

  def execute
    resources.update_all(description:)

    succeed(resources)
      .with_message("Updated description for #{resources.size} category(s)!")
  end
end

# Register it
class DemoFeatures::CategoryDefinition < DemoFeatures::ResourceDefinition
  action :bulk_set_description, interaction: DemoFeatures::BulkSetCategoryDescription
end
