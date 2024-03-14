require "view_component"
require "dry-initializer"

module Plutonium::UI
  class Base < ViewComponent::Base
    extend Dry::Initializer
    include Plutonium::Helpers::ComponentHelper

    delegate_missing_to :helpers

    option :id, optional: true
    option :data, default: proc { {} }
    option :classname, default: proc { "" }

    private

    def url_for(*)
      if respond_to?(:current_package)
        send(current_package.name.underscore.to_sym).url_for(*)
      else
        super(*
        )
      end
    end

    def component_attributes
      attributes = {id:, class: classname.presence}.compact.map { |key, value| "#{key}=\"#{value}\"" }.join " "
      data.each do |key, value|
        attributes = "#{attributes} data-#{key}=\"#{value}\""
      end
      attributes.html_safe
    end
  end
end

# Require components
Dir.glob(File.expand_path("**/*.rb", __dir__)) { |component| load component unless component == __FILE__ }
