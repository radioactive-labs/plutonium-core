class Blogging::TouchPost < Blogging::ResourceInteraction
  presents label: "Touch",
    icon: Phlex::TablerIcons::Refresh

  attribute :resource

  private

  def execute
    resource.touch
    succeed(resource).with_message("Touched.")
  end
end
