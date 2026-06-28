# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"
require "tempfile"
require "rack/test"

# End-to-end proof of STAGE-PHASE attachment validation: a server-side Shrine file
# field with `uploader: LimitedUploader` (max 1 KB). A real multipart upload rides
# the step POST; an over-size file is rejected ON THE STEP (422 + re-render), a
# small one passes and advances — exercising the full controller → driving
# (`stage_wizard_uploads!`) → runner (`validate`) path with a real file.
class WizardUploaderValidationTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    Plutonium::Wizard::Session.delete_all
    @user = create_user!
    login_as(@user, portal: :user)
  end

  def upload(name, bytes)
    file = Tempfile.new([name, ".bin"], binmode: true)
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/octet-stream", original_filename: "#{name}.bin")
  end

  def start
    get "/validated-upload"
    base = URI(response.location).path[%r{\A/validated-upload/[A-Za-z0-9]{32}}]
    follow_redirect! # → :doc step
    base
  end

  test "an over-size file is rejected ON THE STEP (uploader validation runs at staging)" do
    base = start

    assert_no_difference "ShrineDoc.count", "the run never reaches execute" do
      post "#{base}/doc", params: {wizard: {file: upload("big", "x" * 2048)}, _direction: "next"}
    end

    assert_response :unprocessable_content, "the step does not advance — it re-renders with the error"
    assert_match(/too large|max 1 KB/i, response.body, "the uploader's validation message is shown")
  end

  test "a small file passes stage validation and advances to review" do
    base = start

    post "#{base}/doc", params: {wizard: {file: upload("ok", "tiny")}, _direction: "next"}
    assert_response :redirect
    follow_redirect! # → review

    assert_match(/Review/i, response.body, "the valid upload advanced past the doc step")
  end
end
