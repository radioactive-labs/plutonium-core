# frozen_string_literal: true

module GeneratorTestHelper
  extend ActiveSupport::Concern

  included do
    setup :git_restore_dummy_app
    teardown :git_restore_dummy_app
  end

  private

  # Restores the test/dummy app to its git state
  # This cleans up all generated files and reverts any modifications
  #
  # NOTE: teardown does not run when a generator shells out and the child fails
  # — Rails' `generate` action passes abort_on_failure: true, so Thor calls
  # `abort` in this process. The `test_generators` rake task repeats this
  # restore between files to cover that case; see the comment there.
  def git_restore_dummy_app
    repo_root = File.expand_path("../..", __dir__)
    dummy_path = "test/dummy"

    Dir.chdir(repo_root) do
      system("git checkout -- #{dummy_path}", out: File::NULL, err: File::NULL)
      system("git clean -fd #{dummy_path}", out: File::NULL, err: File::NULL)
    end
  end
end
