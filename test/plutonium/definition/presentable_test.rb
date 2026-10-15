# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::PresentableTest < ActiveSupport::TestCase
  def interaction_named(name, &body)
    Class.new(Plutonium::Interaction::Base, &body).tap do |klass|
      klass.define_singleton_method(:name) { name }
    end
  end

  test "the default label drops the Interaction suffix" do
    assert_equal "Import Posts", interaction_named("Blogging::ImportPostsInteraction").label
  end

  # Stripping the whole name would leave a blank button.
  test "a class named just Interaction keeps its name" do
    assert_equal "Interaction", interaction_named("Billing::Archive::Interaction").label
  end

  test "presents label wins over the class name" do
    assert_equal "Import CSV", interaction_named("ImportPostsInteraction") { presents label: "Import CSV" }.label
  end
end
