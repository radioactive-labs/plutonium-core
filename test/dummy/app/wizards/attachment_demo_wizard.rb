# frozen_string_literal: true

# Exercises wizard ATTACHMENT fields against BOTH backends in one flow: a bare
# `as: :uppy` field stages its backend's direct-upload token (an ActiveStorage
# signed_id, or active_shrine/Shrine cached-file JSON) into the wizard's `data` as
# a plain string. The review summary + the step preview resolve those tokens for
# display via `Plutonium::Wizard::Attachments`; `execute` assigns each token to its
# model's attachment (both backends accept their own token).
class AttachmentDemoWizard < Plutonium::Wizard::Base
  presents label: "Upload demo"

  # Plain (no direct_upload): the file rides the step POST and is staged
  # SERVER-SIDE to ActiveStorage's cache. `backend:` pins it to AS (auto-detect
  # would pick Shrine here, since active_shrine is loaded).
  step :as_step, label: "ActiveStorage file" do
    attribute :file, :string
    input :file, as: :uppy, backend: :active_storage,
      hint: "Stored with ActiveStorage (server-side staged)."
  end

  # Direct upload: the browser uploads to Shrine's endpoint and posts a token.
  step :shrine_step, label: "Shrine file" do
    attribute :file, :string
    input :file, as: :uppy, direct_upload: true,
      endpoint: "/shrine/upload",
      hint: "Stored with active_shrine (Shrine, direct upload)."
  end

  review label: "Review & finish"

  def execute
    if data.as_step.file.present?
      AsDoc.create!(title: "AS demo").file.attach(data.as_step.file)
    end

    if data.shrine_step.file.present?
      ShrineDoc.create!(title: "Shrine demo").update!(file: data.shrine_step.file)
    end

    succeed.with_message("Files uploaded.")
  end
end
