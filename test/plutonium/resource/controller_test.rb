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

  # Regression test for submitted_resource_params with nested resources
  # When updating a nested resource, the controller clones the record (id becomes nil)
  # and builds a form for param extraction. This must not raise UrlGenerationError.
  #
  # This test verifies that build_form is called with form_action: false

  def test_submitted_resource_params_builds_form_with_form_action_false
    user = User.create!(email: "controller_test@example.com", status: :verified)
    post = Blogging::Post.create!(title: "Test", body: "Content", user: user)
    comment = Blogging::Comment.create!(body: "Test comment", post: post, user: user)

    controller = build_submitted_params_controller(comment, user)
    controller.test_params = ActionController::Parameters.new({
      "comment" => {"body" => "Updated comment"}
    })

    # Track the form_action argument passed to build_form
    form_action_received = :not_called
    controller.method(:build_form)

    controller.define_singleton_method(:build_form) do |record = nil, action: nil, form_action: nil, **|
      form_action_received = form_action
      # Return a mock form that responds to extract_input
      mock_form = Object.new
      mock_form.define_singleton_method(:extract_input) do |params, view_context:|
        {comment: {body: params["comment"]["body"]}}
      end
      mock_form
    end

    controller.send(:submitted_resource_params)

    # Verify build_form was called with form_action: false
    assert_equal false, form_action_received, "build_form should be called with form_action: false"
  ensure
    Blogging::Comment.delete_all
    Blogging::Post.delete_all
    User.delete_all
  end

  def test_submitted_resource_params_clones_record_for_extraction
    user = User.create!(email: "controller_test2@example.com", status: :verified)
    post = Blogging::Post.create!(title: "Test", body: "Content", user: user)
    comment = Blogging::Comment.create!(body: "Original", post: post, user: user)

    controller = build_submitted_params_controller(comment, user)
    controller.test_params = ActionController::Parameters.new({
      "comment" => {"body" => "Updated"}
    })

    # Track the record passed to build_form
    record_received = nil
    controller.define_singleton_method(:build_form) do |record = nil, **|
      record_received = record
      mock_form = Object.new
      mock_form.define_singleton_method(:extract_input) do |params, view_context:|
        {comment: {body: params["comment"]["body"]}}
      end
      mock_form
    end

    controller.send(:submitted_resource_params)

    # Verify the record passed to build_form is a dup (has nil id)
    assert_nil record_received.id, "build_form should receive a cloned record with nil id"
    # Original record should be unchanged
    assert_equal comment.id, comment.reload.id, "Original record id should be unchanged"
  ensure
    Blogging::Comment.delete_all
    Blogging::Post.delete_all
    User.delete_all
  end

  private

  def build_controller_stub(path, parent_param)
    controller = TestableController.new
    controller.test_request_path = path
    controller.test_parent_route_param = parent_param
    controller
  end

  def build_submitted_params_controller(record, user)
    controller = SubmittedParamsTestController.new
    controller.test_record = record
    controller.test_user = user
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

  # Controller for testing submitted_resource_params
  class SubmittedParamsTestController < ActionController::Base
    include Plutonium::Resource::Controller

    attr_accessor :test_record, :test_user, :test_params

    def resource_class
      Blogging::Comment
    end

    def resource_record?
      test_record
    end

    def resource_record!
      test_record
    end

    def resource_param_key
      :comment
    end

    def params
      test_params
    end

    def action_name
      "update"
    end

    def view_context
      # Create a minimal view context for form extraction
      @view_context ||= ActionView::Base.empty
    end

    def current_parent
      nil
    end

    def scoped_to_entity?
      false
    end

    def current_policy
      @current_policy ||= Blogging::CommentPolicy.new(
        record: test_record,
        user: test_user,
        entity_scope: nil
      )
    end

    def current_definition
      @current_definition ||= Blogging::CommentDefinition.new
    end
  end
end
