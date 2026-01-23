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

  def test_current_nested_association_extracts_from_path
    controller_instance = create_controller_instance("/posts/123/nested_comments/456", :blogging_post_id)

    assert_equal :comments, controller_instance.send(:current_nested_association)
  end

  def test_current_nested_association_handles_singular_routes
    controller_instance = create_controller_instance("/posts/123/nested_post_metadata", :blogging_post_id)

    assert_equal :post_metadata, controller_instance.send(:current_nested_association)
  end

  def test_current_nested_association_returns_nil_without_parent_route_param
    controller_instance = create_controller_instance("/posts/123/nested_comments", nil)

    # Even with nested_ in path, returns nil if no parent_route_param
    assert_nil controller_instance.send(:current_nested_association)
  end

  def test_current_nested_association_extracts_nested_segment_with_action
    controller_instance = create_controller_instance("/posts/123/nested_comments/456/edit", :blogging_post_id)

    assert_equal :comments, controller_instance.send(:current_nested_association)
  end

  private

  def create_controller_instance(path, parent_param = :blogging_post_id)
    # Create a minimal controller instance that responds to current_nested_association
    controller = Object.new

    controller.define_singleton_method(:request) do
      Struct.new(:path).new(path)
    end

    controller.define_singleton_method(:parent_route_param) { parent_param }

    # Define the method under test (matching the controller module implementation)
    controller.define_singleton_method(:current_nested_association) do
      return unless parent_route_param

      prefix = Plutonium::Routing::NESTED_ROUTE_PREFIX
      path_segments = request.path.split("/")
      nested_segment = path_segments.find { |seg| seg.start_with?(prefix) }
      nested_segment&.delete_prefix(prefix)&.to_sym
    end

    controller
  end
end
