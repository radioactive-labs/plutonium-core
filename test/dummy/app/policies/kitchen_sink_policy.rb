class KitchenSinkPolicy < ::ResourcePolicy
  # Interactive action — gated in the policy (record-typed), per house style.
  def reconfigure?
    record.is_a?(KitchenSink)
  end

  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  ATTRIBUTES = %i[
    name organization user email_address secret website favorite_color age
    balance price description bio active featured plan tier birthday meeting_at
    alarm_time phone config prefs status secret_token
  ].freeze

  def permitted_attributes_for_create
    ATTRIBUTES
  end

  def permitted_attributes_for_read
    ATTRIBUTES
  end

  # Associations

  def permitted_associations
    %i[user organization]
  end
end
