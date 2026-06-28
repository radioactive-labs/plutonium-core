# frozen_string_literal: true

# Exercises wizard STAGE-PHASE attachment validation: a server-side Shrine file
# field with `uploader: LimitedUploader`. The uploader's `validate_max_size` runs
# on the STEP — an over-size file is rejected there (a field error + re-render),
# not deferred to `execute`. A small file passes and advances to review.
class ValidatedUploadWizard < Plutonium::Wizard::Base
  presents label: "Validated upload"

  step :doc, label: "Upload a document" do
    attribute :file, :string
    input :file, as: :uppy, backend: :shrine, uploader: LimitedUploader,
      hint: "Server-side staged via LimitedUploader — max 1 KB."
  end

  review label: "Review & finish"

  def execute
    ShrineDoc.create!(title: "Validated demo").update!(file: data.doc.file) if data.doc.file.present?
    succeed.with_message("Uploaded.")
  end
end
