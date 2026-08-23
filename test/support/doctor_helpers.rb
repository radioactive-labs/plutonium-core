# frozen_string_literal: true

# Builds the one input a doctor check takes, so a check test can be about the
# check rather than about portal discovery.
module DoctorHelpers
  def doctor_portal(name = "TestPortal", namespace: nil)
    Plutonium::Doctor::Portals::Portal.new(
      name: name,
      engine: nil,
      namespace: namespace,
      resources: []
    )
  end

  def doctor_target(resource_class:, definition_class:, policy_class:, portal: doctor_portal)
    Plutonium::Doctor::Target.new(
      portal: portal,
      resource_class: resource_class,
      definition_class: definition_class,
      policy_class: policy_class
    )
  end

  def run_check(check_class, target)
    check_class.new(target).call
  end
end
