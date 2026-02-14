# frozen_string_literal: true

module GeneratorTestHelper
  extend ActiveSupport::Concern

  included do
    teardown :git_restore_dummy_app
  end

  private

  # Restores the test/dummy app to its git state
  # This cleans up all generated files and reverts any modifications
  def git_restore_dummy_app
    repo_root = File.expand_path("../..", __dir__)
    dummy_path = "test/dummy"

    Dir.chdir(repo_root) do
      # Restore tracked files in test/dummy to their git state
      system("git checkout -- #{dummy_path}", out: File::NULL, err: File::NULL)
      # Remove untracked files and directories in test/dummy (but not ignored ones)
      system("git clean -fd #{dummy_path}", out: File::NULL, err: File::NULL)
    end
  end

  # Optionally call this in setup to ensure clean state before test
  def git_ensure_clean_dummy_app
    git_restore_dummy_app
  end
end
