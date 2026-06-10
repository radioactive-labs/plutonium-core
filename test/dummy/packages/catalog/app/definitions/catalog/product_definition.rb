class Catalog::ProductDefinition < Catalog::ResourceDefinition
  field :description, as: :text

  # Regression fixture: `tier` is an attr_accessor (not a DB column) so it won't
  # appear in attribute_names. The `status` input is conditioned on it and its
  # choices: lambda depends on it. This verifies that virtual attr_accessor
  # fields are pre-populated before extraction so conditions and choices resolve
  # correctly.
  input :tier, as: :select,
    choices: [["Basic", "basic"], ["Pro", "pro"]],
    pre_submit: true

  # Block syntax is required here: the choices lambda must be created inside the
  # form's instance_exec context so `object` resolves to the form's resource
  # record. A class-level `choices:` option would only have the definition class
  # as `self` and would fail to find `object`.
  input :status,
    condition: -> { object.tier.present? } do |f|
      f.select_tag(choices: -> { (object.tier == "pro") ? %w[active discontinued] : %w[draft] })
    end
  # `featured` auto-renders: switch in forms, boolean pill in show/index.

  # Opt into the Grid index view alongside the default Table. Keeps :table as
  # the default (grid_fields only *adds* :grid), so existing table-based tests
  # are unaffected; reach the grid with `?view=grid`.
  grid_fields(
    header: :name,
    subheader: :description,
    meta: [:status]
  )

  nested_input :variants do |definition|
    definition.input :name
    definition.input :sku
    definition.input :stock_count
  end
  nested_input :product_detail do |definition|
    definition.input :specifications
    definition.input :warranty_info
  end

  search do |scope, query|
    scope.where("name LIKE ? OR description LIKE ?", "%#{query}%", "%#{query}%")
  end

  scope :active
  scope :draft
  scope :discontinued

  filter :name, with: :text, predicate: :contains
  filter :status, with: :select, choices: Catalog::Product.statuses.keys
  filter :category, with: :association, class_name: "Catalog::Category"

  sort :name
  sort :price_cents
  sort :status
  sort :created_at
  default_sort :created_at, :desc

  action :publish, interaction: Catalog::PublishProduct
  action :discontinue, interaction: Catalog::DiscontinueProduct
  action :collect_spec, interaction: Catalog::CollectSpec
  # Record-typed interaction (has `attribute :resource`) surfaced on collection
  # rows only via `record_action: false`. collection_record_action? stays true,
  # so it still operates on a single row's record.
  action :collect_spec_row, interaction: Catalog::CollectSpec, record_action: false
  # Record action whose select `choices:` proc dereferences the subject. Guards
  # the param-extraction path: the extraction instance must be given the record
  # before its form is rendered.
  action :assign_reviewer, interaction: Catalog::AssignReviewer
  # Regression guard: a conditioned select whose choices: proc returns [] on a
  # fresh instance must not nullify the submitted value during param extraction.
  action :conditioned_select, interaction: Catalog::ConditionedSelect
  # Display-only `condition:` — defined (route exists) but only rendered when the
  # proc is truthy. `object` is the row/shown record (record & collection-record
  # actions).
  action :draft_only_demo, interaction: Catalog::PublishProduct,
    label: "Draft Only Demo",
    condition: -> { object.draft? }
  # `condition:` also delegates to the view context — here it reads params.
  action :param_gated_demo, interaction: Catalog::PublishProduct,
    label: "Param Gated Demo",
    condition: -> { params[:show_demo] == "1" }
end
