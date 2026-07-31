# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/pu/lite/litestream/litestream_generator"
require "tmpdir"
require "fileutils"

class MountsEnginesTest < ActiveSupport::TestCase
  def with_generator(rodauth_app: nil)
    Dir.mktmpdir do |dir|
      if rodauth_app
        FileUtils.mkdir_p File.join(dir, "app/rodauth")
        File.write File.join(dir, "app/rodauth/rodauth_app.rb"), rodauth_app
      end
      yield Pu::Lite::LitestreamGenerator.new([], {}, destination_root: dir)
    end
  end

  NAMED_RODAUTH_APP = <<~RUBY
    class RodauthApp < Rodauth::Rails::App
      configure ::UserRodauthPlugin, :user
      configure ::AdminRodauthPlugin, :admin
    end
  RUBY

  PRIMARY_RODAUTH_APP = <<~RUBY
    class RodauthApp < Rodauth::Rails::App
      configure ::RodauthMain
    end
  RUBY

  test "prefers the admin configuration when several are present" do
    with_generator(rodauth_app: NAMED_RODAUTH_APP) do |gen|
      assert_equal ":admin", gen.send(:rodauth_management_account)
    end
  end

  test "does not fall back to another account when there is no admin" do
    app = NAMED_RODAUTH_APP.sub("  configure ::AdminRodauthPlugin, :admin\n", "")

    with_generator(rodauth_app: app) do |gen|
      assert_nil gen.send(:rodauth_management_account)
    end
  end

  test "does not use an unnamed primary configuration" do
    with_generator(rodauth_app: PRIMARY_RODAUTH_APP) do |gen|
      assert_nil gen.send(:rodauth_management_account)
    end
  end

  test "returns nil when the app has no rodauth configuration" do
    with_generator do |gen|
      assert_nil gen.send(:rodauth_management_account)
    end

    with_generator(rodauth_app: "class RodauthApp < Rodauth::Rails::App\nend\n") do |gen|
      assert_nil gen.send(:rodauth_management_account)
    end
  end

  test "generates a Rodauth constraint when a configuration is detected" do
    with_generator(rodauth_app: NAMED_RODAUTH_APP) do |gen|
      source = gen.send(:management_constraint_source)

      assert_includes source, "AUTHENTICATE = Rodauth::Rails.authenticate(:admin)"
      assert_includes source, "AUTHENTICATE.call(request)"
      refute_includes source, "TODO"
    end
  end

  test "generates the unimplemented stub when there is no rodauth" do
    with_generator do |gen|
      source = gen.send(:management_constraint_source)

      assert_includes source, "false # TODO: Implement authentication"
      # the Rodauth form is still shown, but only as a comment
      assert_includes source, "#   AUTHENTICATE = Rodauth::Rails.authenticate(:admin)"
      refute_match(/^\s*AUTHENTICATE = /, source)
    end
  end
end
