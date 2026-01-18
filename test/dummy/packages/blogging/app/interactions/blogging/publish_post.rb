class Blogging::PublishPost < Blogging::ResourceInteraction
  # Presentation
  presents label: "Publish Post",
    icon: Phlex::TablerIcons::Send

  # Having `attribute :resource` makes this a record action
  attribute :resource

  # Validation
  validate :post_not_already_published

  private

  def execute
    resource.update!(published: true)

    succeed(resource)
      .with_message("Post published successfully!")
  end

  def post_not_already_published
    if resource.published?
      errors.add(:base, "Post is already published")
    end
  end
end
