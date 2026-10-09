class KitchenSink < ::ResourceRecord
  include Plutonium::Positioning::Model
  include NoFlyList::TaggableRecord

  positioned_on :position, scope: :status
  # add concerns above.

  # add constants above.

  # Every field below is a real column (see the create_kitchen_sinks
  # migration). status/plan/tier are integer-backed enums so the resource
  # exercises badge displays and select/slim-select inputs end to end.
  enum :status, {active: 0, pending: 1, archived: 2}, default: :active
  enum :plan, {free: 0, pro: 1, enterprise: 2}, default: :pro
  enum :tier, {a: 0, b: 1, c: 2}, default: :b
  # add enums above.

  has_cents :price_cents, unit: "$" # virtual :price decimal accessor (cents <-> dollars); unit drives currency symbol
  # Tags are per organization (no_fly_list `scope:`): each tenant keeps its
  # own vocabulary. `zones` only accepts tags that already exist.
  has_tags :labels, scope: :organization
  has_tags :zones, scope: :organization, restrict_to_existing: true, limit: 2
  # add model configurations above.

  belongs_to :organization
  belongs_to :user, optional: true            # association input/display
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  has_rich_text :notes                        # Action Text (Trix, or Lexxy when the gem is installed)
  # add attachments above.

  # add scopes above.

  validates :name, presence: true
  # add validations above.

  # add methods above. add private methods below.
end
