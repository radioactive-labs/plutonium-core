module Plutonium
  module Interaction
    module Concerns
      # DO NOT USE
      #
      # Provides a Domain Specific Language (DSL) for defining workflows in interactions.
      #
      # This module allows interactions to define a series of steps that can be executed
      # in sequence, with optional conditions for each step.
      #
      # @example
      #   class MyWorkflow < Plutonium::Interaction::Base
      #     include Plutonium::Interaction::Concerns::WorkflowDSL
      #
      #     workflow do
      #       step :validate_input, ValidateInputInteraction
      #       step :process_data, ProcessDataInteraction, if: ->(ctx) { ctx[:data_valid] }
      #       step :send_notification, SendNotificationInteraction
      #     end
      #
      #     private
      #
      #     def execute
      #       execute_workflow(attributes.to_h)
      #     end
      #   end
      module WorkflowDSL
        extend ActiveSupport::Concern

        included do
          class_attribute :workflow_steps, default: []
        end

        class_methods do
          # Defines the workflow for the interaction.
          #
          # @yield The block where workflow steps are defined.
          def workflow(&block)
            WorkflowBuilder.new(self).instance_eval(&block)
          end
        end

        # Helper class for building workflows.
        class WorkflowBuilder
          # @param use_case_class [Class] The interaction class where the workflow is being defined.
          def initialize(use_case_class)
            @use_case_class = use_case_class
          end

          # Adds a step to the workflow.
          #
          # @param name [Symbol] The name of the step.
          # @param use_case [Class] The interaction class to be executed for this step.
          # @param if [Proc, nil] An optional condition for executing the step.
          def step(name, use_case, if: nil)
            @use_case_class.workflow_steps << {
              name:,
              use_case:,
              condition: binding.local_variable_get(:if)
            }
          end
        end

        # Executes the defined workflow.
        #
        # @param context [Hash] The initial context for the workflow.
        # @return [Plutonium::Interaction::Outcome] The outcome of the last executed step.
        def execute_workflow(context = {})
          self.class.workflow_steps.reduce(Success.new(context)) do |result, step|
            result.and_then do |ctx|
              if step[:condition].nil? || instance_exec(ctx, &step[:condition])
                step[:use_case].call(context: ctx).map { |outcome| ctx[step[:name]] = outcome }
              else
                Success.new(ctx)
              end
            end
          end
        end
      end
    end
  end
end
