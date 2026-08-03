class ReconfigureKitchenSink < ::ResourceInteraction
  presents label: "Reconfigure",
    icon: Phlex::TablerIcons::Refresh

  attribute :resource
  attribute :name
  attribute :favorite_color
  attribute :website

  input :favorite_color, as: :color
  input :website, as: :url

  # Exercises form_layout inside an interaction form. On an interaction form the
  # form's `object` is the interaction instance and `object.resource` is the
  # record the action runs on — so section options can be record-aware here too,
  # once the proc has been handed the form to read it from.
  form_layout do
    section :basics, :name, label: "Basics", description: "Rename it"
    section :appearance, :favorite_color, :website,
      label: "Appearance",
      collapsible: true,
      # dynamic: collapsed for archived records
      collapsed: ->(form) { form.object.resource.archived? },
      columns: 2
    ungrouped label: "Anything else"
  end

  def execute
    resource.update!(name:, favorite_color:, website:)
    succeed(resource).with_message("Reconfigured #{resource.name}")
  end
end
