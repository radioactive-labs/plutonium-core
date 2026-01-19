class DemoFeatures::MorphDemoDefinition < DemoFeatures::ResourceDefinition
  # Resource action for testing conditional forms in interactions
  action :conditional_form_demo, interaction: DemoFeatures::ConditionalFormDemo

  # Record type determines which fields are shown
  input :record_type, choices: DemoFeatures::MorphDemo.record_types.keys, pre_submit: true

  # Status - always shown (tests SlimSelect)
  input :status, choices: %w[draft pending active completed archived]

  # Priority - only shown for detailed and scheduled types
  input :priority,
    choices: %w[low medium high urgent],
    condition: -> { object.record_type.in?(%w[detailed scheduled]) }

  # Scheduled at - only shown for scheduled type (tests Flatpickr)
  input :scheduled_at,
    condition: -> { object.scheduled? }

  # Description - shown for detailed and scheduled types
  input :description,
    as: :markdown,
    condition: -> { object.record_type.in?(%w[detailed scheduled]) }

  # Phone - shown for detailed type (tests intl-tel-input)
  input :phone,
    as: :int_tel_input,
    condition: -> { object.detailed? }
end
