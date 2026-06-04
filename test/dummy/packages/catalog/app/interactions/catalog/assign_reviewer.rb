class Catalog::AssignReviewer < Catalog::ResourceInteraction
  presents label: "Assign Reviewer",
    icon: Phlex::TablerIcons::UserCheck

  attribute :resource
  attribute :reviewer_id, :string
  validates :reviewer_id, presence: true

  # Registers a resource-dependent select. The `choices:` proc dereferences the
  # action's subject (`resource`), so the form can only render once the subject
  # is bound. This is the regression guard for the param-extraction path, which
  # used to build/render the form on a resource-less throwaway instance — the
  # proc then ran against a nil resource and raised NoMethodError.
  def customize_inputs
    input :reviewer_id, as: :select, choices: -> { reviewer_choices }
  end

  private

  def reviewer_choices
    [["#{resource.name} (owner)", resource.user_id.to_s]]
  end

  def execute
    succeed(resource).with_message("Assigned reviewer #{reviewer_id}")
  end
end
