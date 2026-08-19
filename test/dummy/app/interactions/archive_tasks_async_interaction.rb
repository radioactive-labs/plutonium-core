# frozen_string_literal: true

# Bulk archive, done OUT OF BAND — the browser-drivable counterpart to
# ArchiveTasksInteraction, which does the same work inline.
#
# The `sleep` is deliberate: without it the run completes before the progress
# page has polled once, and there is nothing to watch.
class ArchiveTasksAsyncInteraction < ::ResourceInteraction
  presents label: "Archive all (async)",
    icon: Phlex::TablerIcons::Archive

  attribute :resources
  attribute :reason, :string
  # A file that has to reach the JOB — it cannot ride the options column, so
  # dispatch stages it to the backend's cache and carries the token.
  attribute :evidence

  input :evidence, as: :file, uploader: LimitedUploader

  validates :reason, presence: true

  async do
    on_failure :continue

    def perform_on(task)
      sleep 0.4
      evidence = attachment(:evidence)
      suffix = evidence ? " (#{evidence.filename}: #{evidence.download.bytesize}b)" : ""
      task.update!(status: "archived", title: "#{task.title} [#{options["reason"]}]#{suffix}")
    end
  end
end
