class Catalog::PublishProduct < Catalog::ResourceInteraction
  presents label: "Publish Product",
    icon: Phlex::TablerIcons::Rocket

  attribute :resource

  # (file-input height demo): a text input + a file input so the
  # two heights can be compared side by side in the slideover.
  attribute :reference
  attribute :file
  input :file, as: :file

  form_layout do
    section :details, :reference, :file, label: "Details"
    ungrouped
  end

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
