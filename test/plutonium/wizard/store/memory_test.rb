# frozen_string_literal: true

require "test_helper"
require_relative "shared"

class Plutonium::Wizard::Store::MemoryTest < Minitest::Test
  include WizardStoreBehavior

  def setup
    @store = Plutonium::Wizard::Store::Memory.new
  end
end
