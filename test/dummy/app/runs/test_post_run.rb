# frozen_string_literal: true

# A targeted run over Blogging::Post, used by the framework's own tests.
#
# It lives in the dummy app rather than inside a test file because target_type
# is stored as a plain string and resolved back to a constant at perform time —
# the same Zeitwerk round-trip a host app's run makes. A run class defined at
# the top of a test file would exercise a different loading path than the one
# that actually ships.
class TestPostRun < Plutonium::Interaction::Async::Run
  # Presence of perform_on is what marks a run as targeted (see Run#targeted?),
  # so this has to exist even though the context never calls it.
  def perform_on(record) = record
end
