class Blogging::PublishPost < Blogging::ResourceInteraction
  presents label: "Publish Post",
    icon: Phlex::TablerIcons::Send

  attribute :resource

  validate :must_be_draft

  private

  def execute
    resource.update!(status: :published)

    succeed(resource)
      .with_message("Post published successfully!")
  end

  def must_be_draft
    errors.add(:base, "Post must be in draft status to publish") unless resource.draft?
  end
end
