class KitchenSinkPolicy < ::ResourcePolicy
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
    balance description bio active featured plan tier birthday meeting_at
    alarm_time phone config prefs status balance_cents secret_token
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
