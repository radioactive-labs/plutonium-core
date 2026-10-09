# frozen_string_literal: true

require "test_helper"

# A bare base64 digest with no `sha384-` prefix is not a valid SRI value, so
# browsers skip the check entirely and the CDN asset loads unverified.
class Plutonium::UI::Layout::SubresourceIntegrityTest < ActiveSupport::TestCase
  test "every integrity hash names its algorithm" do
    source = File.read(File.expand_path("../../../../lib/plutonium/ui/layout/base.rb", __dir__))
    hashes = source.scan(/integrity:\s*"([^"]+)"/).flatten

    refute_empty hashes
    assert_empty hashes.grep_v(/\Asha(256|384|512)-/)
  end
end
