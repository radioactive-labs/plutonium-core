class Catalog::ProductDefinition < Catalog::ResourceDefinition
  field :description, as: :text
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
