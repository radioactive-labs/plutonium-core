# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::LoadableTest < ActiveSupport::TestCase
  test "namespace is defined" do
    assert defined?(Plutonium::Testing)
  end

  test "all submodules are defined" do
    %w[DSL AuthHelpers ResourceCrud ResourcePolicy ResourceDefinition
       ResourceInteraction ResourceModel NestedResource PortalAccess].each do |name|
      assert Plutonium::Testing.const_defined?(name), "#{name} not defined"
    end
  end
end
