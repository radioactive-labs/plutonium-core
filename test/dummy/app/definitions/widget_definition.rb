class WidgetDefinition < ::ResourceDefinition
  # An anchored wizard auto-mounted as a record action on the Widget resource
  # controller (§5.1 / Fix A). The anchor comes from the scoped `resource_record!`.
  wizard :configure, ConfigureWidgetWizard, description: "Set this widget up"
end
