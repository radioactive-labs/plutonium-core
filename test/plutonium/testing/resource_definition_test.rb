# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceDefinitionTest < ActiveSupport::TestCase
  include Plutonium::Testing::ResourceDefinition

  resource_tests_for Blogging::Post, portal: :admin
end
