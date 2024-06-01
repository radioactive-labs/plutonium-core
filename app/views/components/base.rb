require "view_component"
require "dry-initializer"

module Plutonium::Ui
  class Base < ViewComponent::Base
    extend Dry::Initializer
    include Plutonium::Helpers::ComponentHelper

    delegate_missing_to :helpers

    option :id, optional: true
    # these will be merged with base_attributes
    option :data, default: proc { {} }
    option :classname, optional: true
    option :controllers, optional: true
    option :tooltip, optional: true
    # this will override values set in base_attributes
    option :attributes, default: proc { {} }

    private

    def base_attributes = {}

    def attributes_hash
      @attributes_hash ||= begin
        merged_attributes = base_attributes.deep_merge(attributes)
        classname = (Array(merged_attributes.delete(:classname)) + Array(self.classname)).compact.join(" ").presence
        controllers = (Array(merged_attributes.delete(:controller)) + Array(self.controllers)).compact.join(" ").presence
        data = (merged_attributes.delete(:data) || {}).merge(self.data)
        data[:controller] = controllers
        data.compact!

        {
          id:,
          title: tooltip,
          class: classname,
          data: data
        }.deep_merge(merged_attributes).compact
      end
    end

    def attributes_html
      attributes_to_string(attributes_hash).html_safe
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
