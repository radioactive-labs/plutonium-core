class KitchenSinkDefinition < ::ResourceDefinition
  form_layout do
    section :identity, :name, :email_address, label: "Identity",
      description: "Who this is"
    section :appearance, :favorite_color, :active, collapsible: true, columns: 2
    section :secret, :secret_token, label: "Secret stuff", condition: -> { false }
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

  field :name                                                  # string

  # Basic scalar inputs
  input :email_address, as: :email
  input :secret, as: :password
  input :website, as: :url
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
  input :phone, as: :phone                                     # intl-tel-input
  field :config, as: :json                                     # json editor
  field :prefs, as: :key_value                                 # key-value store
  field :user                                                  # association (slim-select) + link display

  # Display-only renderers
  display :status, as: :badge
  display :price, as: :currency, unit: "$"                     # has_cents: 123456 cents -> $1,234.56

  # Hidden
  input :secret_token, as: :hidden
end
