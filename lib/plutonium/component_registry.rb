require "active_support/core_ext/class/attribute"
require "active_support/core_ext/hash/indifferent_access"

module Plutonium
  class ComponentRegistry
    class_attribute :mappings, instance_accessor: false, instance_predicate: false, default: {}.with_indifferent_access

    class UnregisteredComponent < StandardError; end

    def self.register(*types, to:)
      self.mappings = mappings.merge types.each_with_object({}) { |t, m| m[t] = to }
    end

    def self.resolve(name)
      raise UnregisteredComponent.new("no such component registered: #{name.inspect}") unless mappings[name]
      mappings[name]
    end
  end
end
