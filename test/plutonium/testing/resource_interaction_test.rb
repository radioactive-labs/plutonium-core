# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceInteractionTest < ActiveSupport::TestCase
  include Plutonium::Testing::ResourceInteraction

  class HelloInteraction < Plutonium::Interaction::Base
    attribute :name, :string
    validates :name, presence: true

    private

    def execute
      succeed("Hello, #{name}")
    end
  end

  class FailingInteraction < Plutonium::Interaction::Base
    private

    def execute
      failed("nope")
    end
  end

  test "assert_interaction_success returns success outcome" do
    outcome = assert_interaction_success(HelloInteraction, name: "World")
    assert_equal "Hello, World", outcome.value
  end

  test "assert_interaction_failure returns failure outcome on validation error" do
    outcome = assert_interaction_failure(HelloInteraction, name: "")
    assert outcome.failure?
  end

  test "assert_interaction_failure returns failure outcome on execute failure" do
    outcome = assert_interaction_failure(FailingInteraction)
    assert outcome.failure?
  end

  test "stub raises NotImplementedError" do
    klass = Class.new do
      include Plutonium::Testing::ResourceInteraction
    end
    assert_raises(NotImplementedError) { klass.new.interaction_class }
    assert_raises(NotImplementedError) { klass.new.valid_interaction_input }
  end
end
