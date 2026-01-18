class Blogging::SchedulePost < Blogging::ResourceInteraction
  # Presentation
  presents label: "Schedule Post",
    icon: Phlex::TablerIcons::Calendar

  # Having `attribute :resource` makes this a record action
  attribute :resource
  attribute :scheduled_at, :datetime

  # Validation
  validate :post_not_already_published
  validate :scheduled_at_in_future

  private

  def execute
    resource.update!(published: false)

    succeed(resource)
      .with_message("Post scheduled successfully!")
  end

  def post_not_already_published
    if resource.published?
      errors.add(:base, "Cannot schedule an already published post")
    end
  end

  def scheduled_at_in_future
    if scheduled_at.present? && scheduled_at <= Time.current
      errors.add(:scheduled_at, "must be in the future")
    end
  end
end
