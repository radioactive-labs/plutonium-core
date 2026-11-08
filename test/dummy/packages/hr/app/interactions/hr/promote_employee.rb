class Hr::PromoteEmployee < Hr::ResourceInteraction
  presents label: "Promote"

  attribute :resource

  private

  def execute
    resource.update!(name: "#{resource.name} (promoted)")

    succeed(resource)
      .with_message("Promoted")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
