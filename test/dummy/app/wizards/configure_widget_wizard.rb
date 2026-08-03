# frozen_string_literal: true

# A hand-written ANCHORED dummy wizard (§3 / Fix A). Launched against an existing
# Widget through the resource-mounted member route
# (`/org/:org/widgets/:id/wizards/configure/:step`), so the anchor is resolved by
# the resource controller's scoped, policy-gated `resource_record!` — never an
# unscoped `find_by` (the IDOR fix). `execute` mutates THAT widget.
class ConfigureWidgetWizard < Plutonium::Wizard::Base
  presents label: "Configure widget"

  anchored with: Widget

  step :rename do
    attribute :name, :string
    # A proc-valued input option is resolved on every render, so the value can
    # depend on the run. It takes the form because a step block is instance_exec'd
    # against a field recorder at class load — the same reason a `form_layout`
    # section option takes it — and `form.wizard` is this run. A zero-arity
    # `-> { anchor.name }` would look up `anchor` on the recorder and raise.
    input :name, placeholder: ->(form) { "Currently #{form.wizard.anchor.name}" }
    validates :name, presence: true

    # The case that motivated it: choices drawn from the anchor. Left optional so
    # the other tests can post this step without supplying it.
    attribute :rename_reason, :string
    input :rename_reason, as: :select,
      choices: ->(form) { ["#{form.wizard.anchor.name} was wrong", "Other"] }

    # A step is NOT an exception to the arity rule: a zero-argument proc keeps
    # its own binding here exactly as it does on any other form. Nothing rebinds
    # it to the wizard — which is why the option above has to ask for the form.
    # This closes over a class-body local, the only binding a step block has.
    banner = "declared at class load"
    attribute :note, :string
    input :note, placeholder: -> { banner }
  end

  review label: "Review"

  def execute
    anchor.update!(name: data.rename.name)
    succeed(anchor).with_message("Widget configured")
  end
end
