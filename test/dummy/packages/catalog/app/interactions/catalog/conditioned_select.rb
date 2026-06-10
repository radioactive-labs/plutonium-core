class Catalog::ConditionedSelect < Catalog::ResourceInteraction
  presents label: "Conditioned Select",
    icon: Phlex::TablerIcons::Filter

  attribute :resource
  attribute :connection_id, :string
  attribute :value_id, :string

  validates :value_id, presence: true, if: -> { connection_id.present? }

  def customize_inputs
    input :connection_id, as: :select, choices: -> { [["Workspace A", "1"]] }, pre_submit: true

    # condition: is false on a fresh extraction instance (connection_id nil).
    # choices: returns [] on that same instance.
    # Bug: AcceptsChoices#normalize_simple_input then nullifies the submitted value_id.
    input :value_id,
      as: :select,
      choices: -> { value_choices },
      condition: -> { object.connection_id.present? }
  end

  private

  def value_choices
    connection_id.present? ? [["Option X", "42"]] : []
  end

  def execute
    succeed(resource).with_message("Selected value #{value_id} for connection #{connection_id}")
  end
end
