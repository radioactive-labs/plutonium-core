# Configure plutonium

Plutonium.configure do |config|
  config.load_defaults 1.0

  # Enable the DB-backed wizard subsystem so its migration runs in the test DB.
  config.wizards.enabled = true

  # Enable persisted interaction runs so their migration runs in the test DB.
  config.async_runs.enabled = true

  # Configure plutonium above.
end
