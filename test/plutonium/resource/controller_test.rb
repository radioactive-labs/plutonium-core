# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::ControllerTest < Minitest::Test
  # Test inflection error detection
  # This tests the logic that detects when Rails' singularization causes issues

  def test_inflection_mismatch_detection_logic
    # Test the detection logic that runs when singularization produces a different name
    # This simulates what happens when we have a class like "Foobar" and
    # Rails singularizes it unexpectedly (e.g., "Foobara" -> "Foobar" works,
    # but a hypothetical "FoobarCriteria" -> "FoobarCriterium" would fail)

    # Define test class
    Object.const_set(:FooCriteria, Class.new) unless defined?(::FooCriteria)

    # The Rails inflection for Latin words: "criteria" -> "criterium"
    base_name = "FooCriteria"
    singularized_name = base_name.singularize.camelize

    # Without a custom inflection rule, criteria becomes criterium
    refute_equal base_name, singularized_name
    assert_equal "FooCriterium", singularized_name

    # Verify the original name resolves but singularized doesn't
    assert base_name.camelize.safe_constantize
    assert_nil singularized_name.safe_constantize

    # This is the condition in the controller's rescue block that
    # triggers the helpful error message
    assert base_name != singularized_name && base_name.camelize.safe_constantize
  ensure
    Object.send(:remove_const, :FooCriteria) if defined?(::FooCriteria)
  end

  def test_inflection_rule_fixes_metadata_singularization
    # Verify that with the inflection rule in place, PostMetadata works correctly
    # The inflection rule: inflect.singular(/(M)etadata$/i, '\1etadata')

    assert_equal "PostMetadata", "PostMetadata".singularize
    assert_equal "metadata", "metadata".singularize
    assert_equal "Metadata", "Metadata".singularize
  end

  # Test current_nested_association extraction from path
  # Uses the real Plutonium::Resource::Controller module

  def test_current_nested_association_extracts_from_path
    controller = build_controller_stub("/posts/123/nested_comments/456", :blogging_post_id)

    assert_equal :comments, controller.send(:current_nested_association)
  end

  def test_current_nested_association_handles_singular_routes
    controller = build_controller_stub("/posts/123/nested_post_metadata", :blogging_post_id)

    assert_equal :post_metadata, controller.send(:current_nested_association)
  end

  def test_current_nested_association_returns_nil_without_parent_route_param
    controller = build_controller_stub("/posts/123/nested_comments", nil)

    assert_nil controller.send(:current_nested_association)
  end

  def test_current_nested_association_extracts_nested_segment_with_action
    controller = build_controller_stub("/posts/123/nested_comments/456/edit", :blogging_post_id)

    assert_equal :comments, controller.send(:current_nested_association)
  end

  def test_current_nested_association_strips_format_extension
    controller = build_controller_stub("/posts/123/nested_comments.json", :blogging_post_id)

    assert_equal :comments, controller.send(:current_nested_association)
  end

  # Test extraction_record logic for submitted_resource_params

  def test_extraction_record_preserves_context_from_existing_record
    existing_record = Struct.new(:id, :entity_id, :name).new(1, 42, "Test")

    extraction_record = existing_record&.dup

    assert_equal 42, extraction_record.entity_id
    assert_equal "Test", extraction_record.name
  end

  def test_extraction_record_nil_safe_navigation
    existing_record = nil

    extraction_record = existing_record&.dup

    assert_nil extraction_record
  end

  private

  def build_controller_stub(path, parent_param)
    controller = TestableController.new
    controller.test_request_path = path
    controller.test_parent_route_param = parent_param
    controller
  end

  # Controller class that includes the real module with minimal stubs
  class TestableController < ActionController::Base
    include Plutonium::Resource::Controller

    attr_accessor :test_request_path, :test_parent_route_param

    # Stub the dependencies that current_nested_association needs
    def request
      @request ||= Struct.new(:path).new(test_request_path)
    end

    def parent_route_param
      test_parent_route_param
    end

    # Stub other required dependencies
    def current_engine
      nil
    end

    def scoped_to_entity?
      false
    end
  end
end
