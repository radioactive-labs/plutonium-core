class Catalog::PublishProduct < Catalog::ResourceInteraction
  presents label: "Publish Product",
    icon: Phlex::TablerIcons::Rocket

  attribute :resource

  validate :must_be_draft

  private

  def execute
    resource.update!(status: :active)

    succeed(resource)
      .with_message("Product published successfully!")
  end

  def must_be_draft
    errors.add(:base, "Product must be in draft status to publish") unless resource.draft?
  end
end
