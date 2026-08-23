# frozen_string_literal: true

module Plutonium
  # Inspection of a booted Plutonium application, for the class of mistake the
  # framework cannot raise on: code that is legal, runs, and quietly does
  # nothing.
  #
  # Plutonium already fails loudly wherever it can. `Policy.method_added`
  # catches an instance-method `relation_scope` the moment it is defined,
  # `display_layout` raises on a `columns:` copied from a form layout, the
  # resource register refuses a model that never included Record. What is left
  # over is the residue those guards deliberately do not cover: a policy
  # predicate nobody wrote (the action is simply never offered), a `condition:`
  # standing in for authorization (the button hides, the POST still lands), a
  # field redeclared exactly as it was already inferred.
  #
  # That is the selection rule for everything in here, and the rule for anything
  # added later: **if a mistake can be made to raise, it belongs in the
  # framework, not in the doctor.** A raise reaches every application at the
  # moment the mistake is made. A check reaches only the people who run it. The
  # doctor is for what is left when raising would be wrong — because the shape
  # is legal in another context, or because the code is merely untidy rather
  # than broken.
  module Doctor
    class << self
      # @return [Plutonium::Doctor::Report]
      def run(**) = Runner.new(**).call
    end
  end
end
