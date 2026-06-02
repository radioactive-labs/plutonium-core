class Catalog::CollectSpec < Catalog::ResourceInteraction
  presents label: "Collect Spec",
    icon: Phlex::TablerIcons::ClipboardList

  attribute :resource

  structured_input :address do |f|
    f.input :street
    f.input :city
  end

  structured_input :contacts, repeat: 3 do |f|
    f.input :label
    f.input :phone_number
  end

  private

  def execute
    succeed(resource)
      .with_message("Collected #{contacts.size} contacts")
  end
end
