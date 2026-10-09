# frozen_string_literal: true

require "test_helper"

# A `data-controller` with no registered Stimulus controller fails silently in
# the browser. `timeago` shipped that way for a long time after its npm package
# was dropped, so assert every controller the Ruby views name is registered.
class Plutonium::UI::StimulusControllersRegisteredTest < ActiveSupport::TestCase
  ROOT = Pathname.new(__dir__).join("../../..").expand_path
  VIEW_SOURCES = %w[lib/plutonium/ui lib/plutonium/helpers app].freeze

  def referenced_controllers
    VIEW_SOURCES.flat_map { |dir| Dir[ROOT.join(dir, "**/*.rb")] }.flat_map { |path|
      File.read(path).scan(/\b(?:data_)?controller:\s*"([a-z0-9-]+)"/).flatten
    }.uniq
  end

  def registered_controllers
    ROOT.join("src/js/controllers/register_controllers.js").read.scan(/register\("([a-z0-9-]+)"/).flatten
  end

  test "every controller referenced from Ruby is registered" do
    assert_empty referenced_controllers - registered_controllers
  end
end
