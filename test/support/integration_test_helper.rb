# frozen_string_literal: true

module IntegrationTestHelper
  extend ActiveSupport::Concern

  include AuthHelpers
  include DataHelpers

  included do
    teardown :cleanup_test_data
  end

  private

  # Every application row, in foreign-key order — see Purge, which derives that
  # order from the schema.
  #
  # Replaces a hand-written list of ~30 models. The list worked, but only
  # because it was wrapped in PRAGMA foreign_keys = OFF: any model added to the
  # dummy app was silently left behind by it, and the symptom (a count assertion
  # failing in an unrelated file, under some random seeds) is expensive to trace
  # back. The derived order needs no pragma, so a genuine ordering bug would
  # surface here instead of being suppressed.
  def cleanup_test_data
    purge_data!
  end
end
