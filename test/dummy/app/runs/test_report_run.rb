# frozen_string_literal: true

# Opaque (untargeted) work: it defines perform rather than perform_on, so
# Run#targeted? is false. Used to check that the context's policy and predicate
# requirements apply only to runs that actually have targets.
class TestReportRun < Plutonium::Interaction::AsyncRun
  def perform = :done
end
