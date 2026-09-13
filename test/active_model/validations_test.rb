# frozen_string_literal: true

require "test_helper"

# Messages for Plutonium's validators resolve through the ActiveModel
# convention (errors.messages.<key>) from config/locales/en/resource.yml.
class ActiveModel::ValidationsTest < Minitest::Test
  class Attachment
    def initialize(attached) = @attached = attached
    def attached? = @attached
  end

  class Thing
    include ActiveModel::Model

    attr_accessor :website, :logo

    validates :website, url: true, allow_blank: true
    validates :logo, attached: true
  end

  class Sized
    include ActiveModel::Model

    attr_accessor :sizes

    validates :sizes, array: {inclusion: {in: %w[big small]}}
  end

  def test_url_validator_message
    thing = Thing.new(website: "not a url", logo: Attachment.new(true))
    thing.valid?

    assert_equal ["is not a valid URL"], thing.errors[:website]
    assert_equal ["Website is not a valid URL"], thing.errors.full_messages
  end

  def test_url_validator_honours_a_custom_message
    thing = Class.new(Thing) {
      def self.name = "CustomThing"
      validates :website, url: {message: "looks wrong"}
    }.new(website: "nope", logo: Attachment.new(true))
    thing.valid?

    assert_includes thing.errors[:website], "looks wrong"
  end

  def test_attached_validator_message
    thing = Thing.new(logo: Attachment.new(false))
    thing.valid?

    assert_equal ["must be attached"], thing.errors[:logo]
  end

  def test_array_validator_prefixes_the_item_index
    sized = Sized.new(sizes: %w[big huge])
    sized.valid?

    assert_equal ["item 2 is not included in the list"], sized.errors[:sizes]
  end
end
