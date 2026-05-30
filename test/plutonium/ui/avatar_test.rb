# frozen_string_literal: true

require "test_helper"
require "digest"

class Plutonium::UI::AvatarTest < ActiveSupport::TestCase
  # Minimal stand-in for an ActiveRecord-ish record.
  Record = Struct.new(:id)

  def render_html(*args, **kwargs)
    Plutonium::UI::Avatar.new(*args, **kwargs).call
  end

  # ---------------------------------------------------------------------------
  # resolve_image_src (shared resolver)
  # ---------------------------------------------------------------------------

  test "resolve_image_src returns nil for nil" do
    assert_nil Plutonium::UI::Avatar.resolve_image_src(nil)
  end

  test "resolve_image_src passes through http url strings" do
    assert_equal "https://x/y.png", Plutonium::UI::Avatar.resolve_image_src("https://x/y.png")
  end

  test "resolve_image_src passes through root-relative url strings" do
    assert_equal "/uploads/y.png", Plutonium::UI::Avatar.resolve_image_src("/uploads/y.png")
  end

  test "resolve_image_src ignores non-url strings" do
    assert_nil Plutonium::UI::Avatar.resolve_image_src("just a name")
  end

  test "resolve_image_src uses an uploader's url" do
    uploader = Object.new
    def uploader.url = "https://cdn/file.png"
    assert_equal "https://cdn/file.png", Plutonium::UI::Avatar.resolve_image_src(uploader)
  end

  test "resolve_image_src resolves an attached ActiveStorage attachment via helpers.url_for" do
    attachment = ActiveStorage::Attached::One.allocate
    def attachment.attached? = true
    helpers = Object.new
    def helpers.url_for(_value) = "https://as/blob.png"
    assert_equal "https://as/blob.png", Plutonium::UI::Avatar.resolve_image_src(attachment, helpers)
  end

  test "resolve_image_src returns nil for an unattached ActiveStorage attachment" do
    attachment = ActiveStorage::Attached::One.allocate
    def attachment.attached? = false
    assert_nil Plutonium::UI::Avatar.resolve_image_src(attachment)
  end

  # active_shrine (and other ActiveStorage-compatible wrappers) respond to BOTH
  # attached? and url. They must resolve via their own #url, never url_for,
  # since they aren't Rails-routable like ActiveStorage blobs.
  test "resolve_image_src uses #url for an attached active_shrine-style wrapper, not url_for" do
    attachment = Object.new
    def attachment.attached? = true
    def attachment.url = "https://shrine/avatar.png"
    helpers = Object.new
    def helpers.url_for(_value) = raise("url_for must not be called for active_shrine")
    assert_equal "https://shrine/avatar.png", Plutonium::UI::Avatar.resolve_image_src(attachment, helpers)
  end

  test "resolve_image_src returns nil for an unattached active_shrine-style wrapper" do
    attachment = Object.new
    def attachment.attached? = false
    def attachment.url = "https://shrine/avatar.png"
    assert_nil Plutonium::UI::Avatar.resolve_image_src(attachment)
  end

  # ---------------------------------------------------------------------------
  # src: direct values, symbol-on-subject, precedence
  # ---------------------------------------------------------------------------

  test "renders an img with a direct url src" do
    html = render_html(src: "https://x/pic.png")
    assert_includes html, "<img"
    assert_includes html, "https://x/pic.png"
  end

  test "a symbol src is sent to the subject to obtain the image" do
    subject = Object.new
    def subject.photo = "https://x/from-method.png"
    html = render_html(subject, src: :photo)
    assert_includes html, "https://x/from-method.png"
  end

  test "src takes precedence over the navii fallback" do
    html = render_html(Record.new(7), src: "https://x/pic.png")
    assert_includes html, "https://x/pic.png"
    refute_includes html, "navii"
  end

  test "a url-shaped positional subject is treated as the image, not a seed" do
    html = render_html("https://example.com/photo.png")
    assert_includes html, "https://example.com/photo.png"
    refute_includes html, "navii"
  end

  test "a root-relative positional subject is treated as the image" do
    html = render_html("/uploads/photo.png")
    assert_includes html, "/uploads/photo.png"
    refute_includes html, "navii"
  end

  test "an explicit src wins over a url-shaped subject" do
    src = render_html("https://example.com/subject.png", src: "https://example.com/explicit.png")[/src="([^"]*)"/, 1]
    assert_equal "https://example.com/explicit.png", src
  end

  test "a non-url string subject is still a navii seed" do
    html = render_html("acme-team")
    assert_includes html, "api.navii.dev/avatar/"
  end

  test "a symbol src with no subject falls back to the icon" do
    html = render_html(src: :photo)
    refute_includes html, "<img"
    assert_includes html, "<svg"
  end

  # A Symbol src is a contract: the subject must respond to the named method.
  test "a symbol src raises when the subject does not respond to it" do
    assert_raises(NoMethodError) { render_html("Guest", src: :avatar) }
  end

  test "applies the default circular classes and merges a custom class" do
    html = render_html(src: "https://x/pic.png", class: "ring-2")
    assert_includes html, "rounded-full"
    assert_includes html, "object-cover"
    assert_includes html, "ring-2"
  end

  # ---------------------------------------------------------------------------
  # Navii fallback + seed derivation
  # ---------------------------------------------------------------------------

  test "falls back to a navii url seeded from a record subject" do
    html = render_html(Record.new(7))
    assert_includes html, "https://api.navii.dev/avatar/"
    assert_includes html, "size=40"
  end

  test "a record seed is an opaque hash, never raw record data" do
    record = Record.new(7)
    expected = Digest::SHA256.hexdigest("#{record.class.name}:7")[0, 16]
    html = render_html(record)
    assert_includes html, "/avatar/#{expected}?"
    refute_includes html, record.class.name
  end

  test "a string subject is hashed in the navii url, never sent verbatim" do
    expected = Digest::SHA256.hexdigest("acme-team")[0, 16]
    src = render_html("acme-team")[/src="([^"]*)"/, 1]
    assert_includes src, "/avatar/#{expected}?"
    refute_includes src, "acme-team"
  end

  test "the same string subject produces a deterministic avatar" do
    assert_equal render_html("acme"), render_html("acme")
  end

  test "the same record produces a deterministic avatar" do
    assert_equal render_html(Record.new(7)), render_html(Record.new(7))
  end

  test "different records produce different avatars" do
    refute_equal render_html(Record.new(7)), render_html(Record.new(8))
  end

  test "uses the configured navii host url and appends the /avatar route" do
    original = Plutonium.configuration.navii_host_url
    Plutonium.configuration.navii_host_url = "https://avatars.example.com"
    html = render_html(Record.new(7))
    assert_includes html, "https://avatars.example.com/avatar/"
  ensure
    Plutonium.configuration.navii_host_url = original
  end

  # ---------------------------------------------------------------------------
  # Size
  # ---------------------------------------------------------------------------

  test "defaults to the md semantic size" do
    html = render_html(Record.new(7))
    assert_includes html, "size=40"
    assert_includes html, "w-10 h-10"
  end

  test "a semantic size maps to pixels, the size param, and width/height classes" do
    html = render_html(Record.new(7), size: :sm)
    assert_includes html, "size=32"
    assert_includes html, "w-8 h-8"
    assert_includes html, 'width="32"'
  end

  test "an integer size is used as raw pixels via an inline style" do
    html = render_html(Record.new(7), size: 96)
    assert_includes html, "size=96"
    assert_includes html, "width: 96px"
  end

  # ---------------------------------------------------------------------------
  # alt
  # ---------------------------------------------------------------------------

  test "alt defaults to a string subject" do
    html = render_html("Acme", src: "https://x/pic.png")
    assert_includes html, 'alt="Acme"'
  end

  test "an explicit alt overrides the default" do
    html = render_html("Acme", src: "https://x/pic.png", alt: "Company logo")
    assert_includes html, 'alt="Company logo"'
  end

  test "an image with no subject and no alt still carries an empty alt attribute" do
    html = render_html(src: "https://x/pic.png")
    assert_includes html, 'alt=""'
  end

  # ---------------------------------------------------------------------------
  # Last-resort fallback icon
  # ---------------------------------------------------------------------------

  test "renders a fallback user icon when there is no src and no subject" do
    html = render_html
    refute_includes html, "<img"
    assert_includes html, "<svg"
  end

  test "a record subject without an id falls back to the icon" do
    html = render_html(Record.new(nil))
    refute_includes html, "<img"
    assert_includes html, "<svg"
  end
end
