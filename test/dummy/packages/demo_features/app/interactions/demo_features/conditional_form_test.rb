module DemoFeatures
  # Test interaction for conditional form fields with pre_submit
  class ConditionalFormTest < DemoFeatures::ResourceInteraction
    presents label: "Test Conditional Form",
      description: "Tests pre_submit and conditional field rendering",
      icon: Phlex::TablerIcons::TestPipe

    # Form type determines which fields are shown
    attribute :form_type, :string, default: "basic"
    input :form_type, pre_submit: true, as: :slim_select, choices: %w[basic detailed scheduled]

    # Basic fields - always shown
    attribute :name, :string
    input :name

    # Email - always shown (tests validation)
    attribute :email, :string
    input :email

    # Priority - only shown for detailed and scheduled types
    attribute :priority, :string
    input :priority,
      choices: %w[low medium high urgent],
      condition: -> { object.form_type.in?(%w[detailed scheduled]) }

    # Scheduled at - only shown for scheduled type (tests Flatpickr)
    attribute :scheduled_at, :datetime
    input :scheduled_at,
      condition: -> { object.form_type == "scheduled" }

    # Description - shown for detailed and scheduled types
    attribute :description, :string
    input :description,
      as: :text,
      condition: -> { object.form_type.in?(%w[detailed scheduled]) }

    # Phone - shown for detailed type (tests intl-tel-input)
    attribute :phone, :string
    input :phone,
      as: :int_tel_input,
      condition: -> { object.form_type == "detailed" }

    validates :name, presence: true
    validates :email, presence: true
    validates :priority, presence: true, if: -> { form_type.in?(%w[detailed scheduled]) }
    validates :scheduled_at, presence: true, if: -> { form_type == "scheduled" }
    validate :email_format

    private

    def execute
      # Just return success with a summary of what was submitted
      succeed(
        form_type: form_type,
        name: name,
        email: email,
        priority: priority,
        scheduled_at: scheduled_at,
        description: description,
        phone: phone
      ).with_message("Form submitted successfully with type: #{form_type}")
    end

    def email_format
      return if email.blank?

      errors.add(:email, :invalid) unless email.match?(URI::MailTo::EMAIL_REGEXP)
    end
  end
end
