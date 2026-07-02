class KitchenSinkDefinition < ::ResourceDefinition
  # Open the show page in a (centered) modal from any record link — table rows,
  # grid cards, and kanban cards. The kanban board inherits this (it sets no
  # show_in of its own). new/edit still use the default slideover modal_mode.
  show_in :modal

  # Interactive record action — exercises form_layout (incl. a dynamic
  # `collapsed:`) inside an interaction form. See ReconfigureKitchenSink.
  action :reconfigure, interaction: ReconfigureKitchenSink

  form_layout do
    section :identity, :name, :email_address, label: "Identity",
      description: "Who this is"
    # `collapsed:` is a proc resolved at render in the form/record context —
    # existing records open collapsed, new records open expanded.
    section :appearance, :favorite_color, :active, :website,
      collapsible: true, collapsed: -> { object.persisted? }, columns: 2
    section :secret, :secret_token, label: "Secret stuff", condition: -> { false }
    # Lists only a field that is never in the permitted set, so it resolves to
    # zero fields on every render — its chrome must not be emitted.
    section :all_absent, :never_permitted, label: "All Absent Section"
    ungrouped label: "Everything else"
  end

  # A deliberate "kitchen sink" exercising every available input and display
  # type — especially the JS widgets that mutate the DOM after connect
  # (intl-tel-input, flatpickr, slim-select, easymde, key-value, json), which
  # is what dirty-form-guard has to cope with.
  #
  # `field`  — renders on both the show/index display AND the form.
  # `input`  — form only (used where there is no display renderer, e.g. the
  #            plain/slim selects and the hidden field).
  # `display`— show/index only (badge, currency).

  # Grid index view (?view=grid) — exercises the card slots across types:
  # enum badges (meta), a datetime footer that may be blank (em-dash), and a
  # possibly-blank text body.
  grid_fields(
    header: :name,
    subheader: :price,
    body: :description,
    meta: [:status, :plan, :tier],
    footer: :meeting_at
  )

  # Kanban index view (?view=kanban) — groups by the status enum. Cards reuse
  # grid_fields above. Drag a card between columns to flip its status; a wip
  # on Pending; an "Archive all" column action on Archived.
  kanban do
    # Meta badges exercise the type-aware badge path: a has_cents field renders
    # as currency and a belongs_to association renders as its label (not a raw
    # decimal / object inspect). Enums still humanize + get semantic colors.
    card_fields header: :name, meta: [:status, :plan, :tier, :price, :user]

    column :active, label: "Active", role: :backlog,
      scope: -> { where(status: :active) },
      on_drop: ->(ks) { ks.status = :active }

    column :pending, label: "Pending", color: :amber, wip: 5,
      scope: -> { where(status: :pending) },
      on_drop: ->(ks) { ks.status = :pending }

    column :archived, label: "Archived", role: :done,
      scope: -> { where(status: :archived) },
      on_drop: ->(ks) { ks.status = :archived }

    per_column 10
  end

  field :name                                                  # string

  # Basic scalar inputs
  input :email_address, as: :email
  input :secret, as: :password
  # In the 2-column :appearance section, but opts back to full width via an
  # explicit col-span — which must survive the section's `columns:` default.
  input :website, as: :url, wrapper: {class: "col-span-full"}
  field :favorite_color, as: :color                            # color input + swatch display
  field :age, as: :integer
  input :balance, as: :decimal
  input :price, as: :decimal                                   # has_cents: edit dollars, stored as price_cents
  field :description, as: :text                                # textarea + text display

  # DOM-mutating widgets
  field :bio, as: :markdown                                    # easymde + rendered markdown
  field :active, as: :boolean                                  # checkbox + boolean display
  input :featured, as: :switch                                 # toggle
  input :plan, as: :slim_select, choices: %w[free pro enterprise]
  input :tier, as: :select, choices: %w[a b c]                 # plain <select>
  input :birthday, as: :date                                   # flatpickr
  input :meeting_at, as: :datetime                             # flatpickr
  input :alarm_time, as: :time                                 # flatpickr
  input :phone, as: :phone, initial_country: "gh"              # intl-tel-input; default country + strictMode
  field :config, as: :json                                     # json editor
  field :prefs, as: :key_value                                 # key-value store
  field :user                                                  # association (slim-select) + link display

  # Display-only renderers
  display :status, as: :badge
  display :price, as: :currency, unit: "$"                     # has_cents: 123456 cents -> $1,234.56

  # Hidden
  input :secret_token, as: :hidden
end
