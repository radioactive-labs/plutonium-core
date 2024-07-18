# Configure plutonium

Plutonium.configure do |config|
  config.load_defaults 1.0

  # config.assets.logo = "logo.png"
  # Configure plutonium above.
end

Rails.application.config.to_prepare do
  # Register components here

  # e.g
  # Plutonium::Core::Fields::Renderers::Factory.map_type :mapped_collection, to: Fields::Renderers::MappedCollectionRenderer
end
