# frozen_string_literal: true

require "test_helper"

class InteractionTest < Minitest::Test
  # Test interaction features as documented

  def setup
    @user = User.create!(email: "test@example.com", password: "password123", status: "verified")
  end

  def teardown
    Blogging::Comment.delete_all
    Blogging::Post.delete_all
    User.delete_all
  end

  def test_interaction_attributes
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      attribute :resource
      attribute :email, :string
      attribute :count, :integer, default: 1
      attribute :active, :boolean, default: -> { true }
    end

    instance = interaction_class.new(view_context: nil, resource: nil, email: "test@example.com")

    assert_equal "test@example.com", instance.email
    assert_equal 1, instance.count
    assert_equal true, instance.active
  end

  def test_interaction_presents
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      presents label: "Test Action",
               icon: Phlex::TablerIcons::Star,
               description: "A test action"
    end

    assert_equal "Test Action", interaction_class.label
    assert_equal Phlex::TablerIcons::Star, interaction_class.icon
    assert_equal "A test action", interaction_class.description
  end

  def test_interaction_validations
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      attribute :email, :string

      validates :email, presence: true

      private

      def execute
        succeed(nil)
      end
    end

    # Without email - should fail validation
    result = interaction_class.call(view_context: nil, email: nil)
    assert result.failure?

    # With email - should succeed
    result = interaction_class.call(view_context: nil, email: "test@example.com")
    assert result.success?
  end

  def test_interaction_custom_validation
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      attribute :value, :integer

      validate :value_must_be_positive

      private

      def execute
        succeed(value)
      end

      def value_must_be_positive
        errors.add(:value, "must be positive") if value && value <= 0
      end
    end

    result = interaction_class.call(view_context: nil, value: -1)
    assert result.failure?

    result = interaction_class.call(view_context: nil, value: 10)
    assert result.success?
  end

  def test_success_outcome
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      attribute :value, :integer

      private

      def execute
        succeed(value * 2)
      end
    end

    result = interaction_class.call(view_context: nil, value: 5)

    assert result.success?
    refute result.failure?
    assert_equal 10, result.value
  end

  def test_success_with_message
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      private

      def execute
        succeed(nil).with_message("Operation completed!")
      end
    end

    result = interaction_class.call(view_context: nil)

    assert result.success?
    assert_equal [["Operation completed!", :notice]], result.messages
  end

  def test_success_with_alert_message
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      private

      def execute
        succeed(nil).with_message("Warning!", :alert)
      end
    end

    result = interaction_class.call(view_context: nil)

    assert result.success?
    assert_equal [["Warning!", :alert]], result.messages
  end

  def test_failure_outcome
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      private

      def execute
        failed("Something went wrong")
      end
    end

    result = interaction_class.call(view_context: nil)

    assert result.failure?
    refute result.success?
  end

  def test_failure_with_hash_errors
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      private

      def execute
        failed(email: "is invalid", name: "is required")
      end
    end

    result = interaction_class.call(view_context: nil)
    assert result.failure?
  end

  def test_outcome_chaining_with_and_then
    first_interaction = Class.new(Plutonium::Resource::Interaction) do
      attribute :value, :integer

      private

      def execute
        succeed(value + 1)
      end
    end

    second_interaction = Class.new(Plutonium::Resource::Interaction) do
      attribute :value, :integer

      private

      def execute
        succeed(value * 2)
      end
    end

    # Chain: 5 -> +1 = 6 -> *2 = 12
    result = first_interaction.call(view_context: nil, value: 5)
      .and_then { |val| second_interaction.call(view_context: nil, value: val) }

    assert result.success?
    assert_equal 12, result.value
  end

  def test_outcome_chaining_short_circuits_on_failure
    first_interaction = Class.new(Plutonium::Resource::Interaction) do
      private

      def execute
        failed("First failed")
      end
    end

    second_interaction = Class.new(Plutonium::Resource::Interaction) do
      private

      def execute
        succeed("Second succeeded")
      end
    end

    second_called = false
    result = first_interaction.call(view_context: nil)
      .and_then do |_val|
        second_called = true
        second_interaction.call(view_context: nil)
      end

    assert result.failure?
    refute second_called, "Second interaction should not be called when first fails"
  end

  def test_publish_post_interaction_success
    post = Blogging::Post.create!(title: "Draft", body: "Content", user: @user, published: false)

    result = Blogging::PublishPost.call(view_context: nil, resource: post)

    assert result.success?
    post.reload
    assert post.published?
  end

  def test_publish_post_interaction_validation_failure
    post = Blogging::Post.create!(title: "Published", body: "Content", user: @user, published: true)

    result = Blogging::PublishPost.call(view_context: nil, resource: post)

    assert result.failure?
  end

  def test_schedule_post_interaction_success
    post = Blogging::Post.create!(title: "To Schedule", body: "Content", user: @user, published: false)
    future_time = 1.day.from_now

    result = Blogging::SchedulePost.call(view_context: nil, resource: post, scheduled_at: future_time)

    assert result.success?
  end

  def test_schedule_post_interaction_validation_failure_past_date
    post = Blogging::Post.create!(title: "To Schedule", body: "Content", user: @user, published: false)
    past_time = 1.day.ago

    result = Blogging::SchedulePost.call(view_context: nil, resource: post, scheduled_at: past_time)

    assert result.failure?
  end

  def test_interaction_input_declaration
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      attribute :email, :string
      attribute :role, :string

      input :email, as: :email, hint: "Enter email"
      input :role, as: :select, choices: %w[admin user]

      private

      def execute
        succeed(nil)
      end
    end

    assert interaction_class.defined_inputs.key?(:email)
    assert interaction_class.defined_inputs.key?(:role)
    assert_equal :email, interaction_class.defined_inputs[:email][:options][:as]
    assert_equal :select, interaction_class.defined_inputs[:role][:options][:as]
  end

  def test_interaction_determines_if_form_needed
    # Interaction with no inputs - immediate action
    immediate_interaction = Class.new(Plutonium::Resource::Interaction) do
      attribute :resource

      private

      def execute
        succeed(resource)
      end
    end

    # Interaction with inputs - form action
    form_interaction = Class.new(Plutonium::Resource::Interaction) do
      attribute :resource
      attribute :reason, :string

      input :reason

      private

      def execute
        succeed(resource)
      end
    end

    # The presence of `input` declarations determines if a form is shown
    assert immediate_interaction.defined_inputs.empty?
    refute form_interaction.defined_inputs.empty?
  end
end
