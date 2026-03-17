class Catalog::DiscontinueProduct < Catalog::ResourceInteraction
  presents label: "Discontinue Product",
    icon: Phlex::TablerIcons::CircleOff

  attribute :resource

  validate :must_be_active

  private

  def execute
    resource.update!(status: :discontinued)

    succeed(resource)
      .with_message("Product discontinued.")
  end

  def must_be_active
    errors.add(:base, "Product must be active to discontinue") unless resource.active?
  end
end
