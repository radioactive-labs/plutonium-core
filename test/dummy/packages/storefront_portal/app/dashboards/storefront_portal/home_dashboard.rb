module StorefrontPortal
  # The storefront's root page, replacing the generated `dashboard#index`. The
  # portal is public, so nothing here may touch `current_user`.
  class HomeDashboard < Plutonium::Dashboard::Base
    presents label: "Home", description: "What's in the store"

    metric(:products, icon: Phlex::TablerIcons::Package, href: -> { resource_url_for(::Catalog::Product, parent: nil) }) do
      ::Catalog::Product.count
    end

    metric(:categories) { ::Catalog::Category.count }

    card(:welcome, span: :full) { p { "Welcome to the storefront." } }
  end
end
