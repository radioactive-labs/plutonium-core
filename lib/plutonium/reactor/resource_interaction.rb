require "active_interaction"

module Plutonium
  module Reactor
    class ResourceInteraction < ActiveInteraction::Base
      # def self.resource_class
      #   (filters[:resources]&.filters&.[](:'0') || filters[:resource])&.options&.[](:class)
      # end

      # def resource_class
      #   self.class.resource_class
      # end
    end
  end
end
