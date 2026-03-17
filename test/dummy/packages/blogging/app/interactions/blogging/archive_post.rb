class Blogging::ArchivePost < Blogging::ResourceInteraction
  presents label: "Archive Post",
    icon: Phlex::TablerIcons::Archive

  attribute :resource

  validate :must_be_published

  private

  def execute
    resource.update!(status: :archived)

    succeed(resource)
      .with_message("Post archived successfully.")
  end

  def must_be_published
    errors.add(:base, "Post must be published to archive") unless resource.published?
  end
end
