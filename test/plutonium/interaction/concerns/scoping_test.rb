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

        # Mirrors the real controller, INCLUDING its visibility: both readers are
        # PRIVATE controller methods published with `helper_method`, so an
        # interaction can only reach them through `helpers`. A mock that exposed
        # them publicly would pass whether or not the concern goes through the
        # right door — and the wrong door returns nil for the tenant, which reads
        # as "no tenant" rather than as a failure.
        class MockController
          attr_writer :current_scoped_entity, :current_parent, :scoped_to_entity

          def initialize
            @scoped_to_entity = true
          end

          def scoped_to_entity? = @scoped_to_entity

          def helpers = @helpers ||= HelperProxy.new(self)

          private

          attr_reader :current_parent

          # Mirrors EntityScoping#current_scoped_entity, which RAISES on an
          # un-scoped portal rather than returning nil.
          def current_scoped_entity
            raise NotImplementedError, "this request is not scoped to an entity" unless scoped_to_entity?

            @current_scoped_entity
          end

          class HelperProxy
            def initialize(controller)
              @controller = controller
            end

            def current_scoped_entity = @controller.send(:current_scoped_entity)

            def current_parent = @controller.send(:current_parent)
          end
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

        test "current_scoped_entity returns nil when the portal is not entity-scoped" do
          @controller.scoped_to_entity = false
          @controller.current_scoped_entity = MockEntity.new(1)

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

        # The concern states a precondition — it reads a Plutonium controller —
        # and a caller that does not meet it must find out. Answering nil would
        # be indistinguishable from "this portal has no tenant", which is how a
        # broken call silently drops the entity filter.
        test "a controller that cannot answer raises rather than reporting no tenant" do
          interaction = TestInteraction.new(MockViewContext.new(Object.new))

          assert_raises(NoMethodError) { interaction.current_scoped_entity }
        end

        test "a controller that cannot answer raises rather than reporting no parent" do
          interaction = TestInteraction.new(MockViewContext.new(Object.new))

          assert_raises(NoMethodError) { interaction.current_parent }
        end
      end
    end
  end
end
