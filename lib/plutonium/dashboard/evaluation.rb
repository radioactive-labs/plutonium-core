# frozen_string_literal: true

module Plutonium
  module Dashboard
    # How a card or toolbar link runs its author-supplied procs and
    # `condition:` against the dashboard instance, so both accept the same
    # forms.
    module Evaluation
      private

      # A zero-arity proc runs on the dashboard instance; a proc taking an
      # argument also receives the dashboard.
      def evaluate_on(dashboard, callable)
        callable.arity.zero? ? dashboard.instance_exec(&callable) : dashboard.instance_exec(dashboard, &callable)
      end

      # `condition:` is nil (always), a proc (see {#evaluate_on}), a symbol
      # naming a dashboard method, or a plain value.
      def condition_passes?(dashboard, condition)
        result = case condition
        when nil then true
        when Symbol then dashboard.send(condition)
        when Proc then evaluate_on(dashboard, condition)
        else condition
        end
        result ? true : false
      end
    end
  end
end
