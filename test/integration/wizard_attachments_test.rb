# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"
require "base64"
require "tempfile"
require "rack/test"

# End-to-end wizard ATTACHMENT flow against BOTH backends (ActiveStorage +
# active_shrine), via AttachmentDemoWizard at /uploads. A bare `as: :uppy` field
# stages its backend's direct-upload token as a plain string; this proves the token
# round-trips: it stages, the review summary + the step preview RESOLVE it for
# display, and `execute` assigns it to the model's attachment.
class WizardAttachmentsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    Plutonium::Wizard::Session.delete_all
    @user = create_user!
    login_as(@user, portal: :user)
  end

  def as_token
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("as-bytes"), filename: "as-logo.png", content_type: "image/png"
    ).signed_id
  end

  def shrine_token
    io = StringIO.new("shrine-bytes")
    io.define_singleton_method(:original_filename) { "shrine-photo.jpg" }
    io.define_singleton_method(:content_type) { "image/jpeg" }
    Shrine.upload(io, :cache).to_json
  end

  # A 1x1 PNG as a real multipart upload (no client-side token).
  def multipart_png(filename)
    bytes = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
    file = Tempfile.new([filename, ".png"], binmode: true)
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "image/png", original_filename: "#{filename}.png")
  end

  test "a plain (non-direct) upload is staged SERVER-SIDE and attaches on finish (ActiveStorage)" do
    get "/uploads"
    base = URI(response.location).path[%r{\A/uploads/[A-Za-z0-9]{32}}]
    follow_redirect! # → as_step

    # No client token — a real file rides the multipart POST. The wizard uploads it
    # to ActiveStorage's cache during staging and stages the signed_id.
    assert_difference "ActiveStorage::Blob.count", 1 do
      post "#{base}/as_step", params: {wizard: {file: multipart_png("plain-as")}, _direction: "next"}
    end
    follow_redirect! # → shrine_step
    post "#{base}/shrine_step", params: {_direction: "next"} # skip
    follow_redirect! # → review
    assert_includes response.body, "plain-as.png", "the server-staged file shows in review"

    assert_difference "AsDoc.count", 1 do
      post "#{base}/review", params: {_direction: "next"}
    end
    assert AsDoc.last.file.attached?, "the server-side staged token attached on finish"
    assert_equal "plain-as.png", AsDoc.last.file.filename.to_s
  end

  test "active_shrine is the default backend: a plain upload stages via Shrine and attaches" do
    get "/uploads"
    base = URI(response.location).path[%r{\A/uploads/[A-Za-z0-9]{32}}]
    follow_redirect! # → as_step
    post "#{base}/as_step", params: {_direction: "next"} # skip AS
    follow_redirect! # → shrine_step

    # No `backend:` on the Shrine field → the default applies. Since active_shrine
    # is loaded, that default is Shrine.
    post "#{base}/shrine_step", params: {wizard: {file: multipart_png("plain-shrine")}, _direction: "next"}

    staged = Plutonium::Wizard::Session.where(status: "in_progress").last.data.dig("shrine_step", "file")
    assert_kind_of Hash, JSON.parse(staged), "the default backend staged a Shrine cached-file JSON token"

    follow_redirect! # → review
    assert_includes response.body, "plain-shrine.png"

    assert_difference "ShrineDoc.count", 1 do
      post "#{base}/review", params: {_direction: "next"}
    end
    assert ShrineDoc.last.file.attached?, "the Shrine-staged token attached on finish"
    assert_equal "plain-shrine.png", ShrineDoc.last.file.filename
  end

  test "tokens stage, render in review + preview, and attach on finish — both backends" do
    get "/uploads"
    assert_response :redirect
    base = URI(response.location).path[%r{\A/uploads/[A-Za-z0-9]{32}}]
    assert base, "launch redirects into a tokened run (#{response.location})"
    follow_redirect! # → as_step
    assert_response :success
    assert_includes response.body, %(name="wizard[file]"), "the as_step renders an uppy file input"

    # Stage the ActiveStorage token.
    post "#{base}/as_step", params: {wizard: {file: as_token}, _direction: "next"}
    follow_redirect! # → shrine_step
    assert_response :success

    # Stage the Shrine token.
    post "#{base}/shrine_step", params: {wizard: {file: shrine_token}, _direction: "next"}
    follow_redirect! # → review
    assert_response :success

    # The review summary resolves BOTH tokens to filenames (not raw token strings).
    assert_includes response.body, "as-logo.png", "review shows the resolved ActiveStorage filename"
    assert_includes response.body, "shrine-photo.jpg", "review shows the resolved Shrine filename"
    # Resolved to a real preview, not dumped as the raw token string.
    assert_match %r{<img[^>]+as-logo\.png}, response.body, "the AS image renders as a thumbnail"

    # Going BACK rehydrates the step's uppy preview from the staged token.
    get "#{base}/as_step"
    assert_response :success
    assert_includes response.body, "as-logo.png", "the step preview rehydrates the staged file"

    # Finish: each token is assigned to its model's attachment.
    assert_difference ["AsDoc.count", "ShrineDoc.count"], 1 do
      post "#{base}/review", params: {_direction: "next"}
    end
    assert_response :redirect

    assert AsDoc.last.file.attached?, "the ActiveStorage attachment was assigned on finish"
    assert_equal "as-logo.png", AsDoc.last.file.filename.to_s
    assert ShrineDoc.last.file.attached?, "the active_shrine attachment was assigned on finish"
    assert_equal "shrine-photo.jpg", ShrineDoc.last.file.filename
  end
end
