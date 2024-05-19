require "view_component"
require "dry-initializer"

module Plutonium::Ui
  class Base < ViewComponent::Base
    extend Dry::Initializer
    include Plutonium::Helpers::ComponentHelper

    delegate_missing_to :helpers

    option :id, optional: true
    option :data, default: proc { {} }
    option :classname, optional: true
    option :tooltip, optional: true
    option :attributes, default: proc { {} }

    private

    def base_classname = nil

    def merged_classname
      [base_classname, classname].compact.join.presence
    end

    def component_attributes
      {id:, data:, class: merged_classname, title: tooltip}.merge(attributes).compact
    end

    def render_component_attributes
      attributes_to_string(component_attributes).html_safe
    end

    def render_icon(icon)
      Plutonium::Icons.render(icon)
    end

    def attributes_to_string(attributes, prefix = nil)
      attributes.map do |key, value|
        if value.is_a?(Hash)
          attributes_to_string(value, "#{prefix ? "#{prefix}-" : ""}#{key}")
        else
          "#{prefix ? "#{prefix}-" : ""}#{key}=\"#{value}\""
        end
      end.join(" ")
    end
  end
end

# Require components
Dir.glob(File.expand_path("**/*.rb", __dir__)) { |component| load component unless component == __FILE__ }
