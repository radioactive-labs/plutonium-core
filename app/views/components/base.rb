require "view_component"
require "dry-initializer"
require "active_support/notifications"

require_relative "attributes"

module Plutonium
  module Ui
    # Base class for all Plutonium UI components.
    # This class inherits from `ViewComponent::Base` and includes additional functionality
    # provided by `Dry::Initializer` for managing component options, and the
    # `Plutonium::Ui::Attributes` module for handling UI attributes.
    #
    # It also includes `Plutonium::Helpers::ComponentHelper` for additional helper methods
    # and delegates missing methods to the Rails helpers.
    class Base < ViewComponent::Base
      extend Dry::Initializer
      include Plutonium::Helpers::ComponentHelper
      include Plutonium::Ui::Attributes

      delegate_missing_to :helpers
    end
  end
end

def load_component(file_path)
  # sidebar_menu_item/sidebar_menu_item_component
  # skeleton/table/table_component
  relative_path = file_path.sub(%r{^#{__dir__}/}, "").sub(/\.rb$/, "")

  # sidebar_menu_item
  # skeleton/table
  constant_prefix = relative_path.split("/")[0...-1].join("/")

  # SidebarMenuItemComponent
  # Skeleton::TableComponent
  constant_name = "#{constant_prefix.camelize}Component"

  begin
    # Remove constant if defined
    names = constant_name.split("::")
    constant = names.pop
    parent_module = names.inject(Plutonium::Ui) do |mod, name|
      mod.const_get(name)
    end
    parent_module.send(:remove_const, constant) if parent_module.const_defined?(constant)
  rescue NameError
    # do nothing
  end

  load file_path
end

ActiveSupport::Notifications.instrument("plutonium.components.load") do
  # Require all component files within the same directory and subdirectories
  Dir.glob(File.expand_path("**/*.rb", __dir__)) do |component_file_path|
    load_component component_file_path unless component_file_path == __FILE__
  end
end
