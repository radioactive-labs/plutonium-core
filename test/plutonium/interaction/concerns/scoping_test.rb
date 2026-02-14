# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Interaction
    module Concerns
      class ScopingTest < ActiveSupport::TestCase
        class MockEntity
          attr_reader :id

          def initialize(id)
            @id = id
          end
        end

        class MockParent
          attr_reader :id

          def initialize(id)
            @id = id
          end
        end

        class MockController
          attr_accessor :current_scoped_entity, :current_parent
        end

        class MockViewContext
          attr_reader :controller

          def initialize(controller)
            @controller = controller
          end
        end

        class TestInteraction
          include Scoping

          attr_accessor :view_context

          def initialize(view_context)
            @view_context = view_context
          end

          # Expose private methods for testing
          public :scoped_record_of_type, :current_parent, :current_scoped_entity, :scoped_parent
        end

        def setup
          @controller = MockController.new
          @view_context = MockViewContext.new(@controller)
          @interaction = TestInteraction.new(@view_context)
        end

        test "current_scoped_entity returns entity from controller" do
          entity = MockEntity.new(1)
          @controller.current_scoped_entity = entity

          assert_equal entity, @interaction.current_scoped_entity
        end

        test "current_scoped_entity returns nil when controller has no entity" do
          @controller.current_scoped_entity = nil

          assert_nil @interaction.current_scoped_entity
        end

        test "current_parent returns parent from controller" do
          parent = MockParent.new(2)
          @controller.current_parent = parent

          assert_equal parent, @interaction.current_parent
        end

        test "current_parent returns nil when controller has no parent" do
          @controller.current_parent = nil

          assert_nil @interaction.current_parent
        end

        test "scoped_record_of_type finds entity when it matches class" do
          entity = MockEntity.new(1)
          @controller.current_scoped_entity = entity
          @controller.current_parent = nil

          result = @interaction.scoped_record_of_type(MockEntity)

          assert_equal entity, result
        end

        test "scoped_record_of_type finds parent when it matches class" do
          parent = MockParent.new(2)
          @controller.current_scoped_entity = nil
          @controller.current_parent = parent

          result = @interaction.scoped_record_of_type(MockParent)

          assert_equal parent, result
        end

        test "scoped_record_of_type prefers entity over parent" do
          entity = MockEntity.new(1)
          parent = MockEntity.new(2) # Same class as entity
          @controller.current_scoped_entity = entity
          @controller.current_parent = parent

          result = @interaction.scoped_record_of_type(MockEntity)

          assert_equal entity, result
        end

        test "scoped_record_of_type returns nil when no match" do
          entity = MockEntity.new(1)
          @controller.current_scoped_entity = entity
          @controller.current_parent = nil

          result = @interaction.scoped_record_of_type(MockParent)

          assert_nil result
        end

        test "scoped_parent returns entity when present" do
          entity = MockEntity.new(1)
          parent = MockParent.new(2)
          @controller.current_scoped_entity = entity
          @controller.current_parent = parent

          assert_equal entity, @interaction.scoped_parent
        end

        test "scoped_parent returns parent when no entity" do
          parent = MockParent.new(2)
          @controller.current_scoped_entity = nil
          @controller.current_parent = parent

          assert_equal parent, @interaction.scoped_parent
        end

        test "scoped_parent returns nil when neither present" do
          @controller.current_scoped_entity = nil
          @controller.current_parent = nil

          assert_nil @interaction.scoped_parent
        end

        test "handles controller without current_scoped_entity method" do
          controller_without_entity = Object.new
          view_context = MockViewContext.new(controller_without_entity)
          interaction = TestInteraction.new(view_context)

          assert_nil interaction.current_scoped_entity
        end

        test "handles controller without current_parent method" do
          controller_without_parent = Object.new
          view_context = MockViewContext.new(controller_without_parent)
          interaction = TestInteraction.new(view_context)

          assert_nil interaction.current_parent
        end
      end
    end
  end
end
