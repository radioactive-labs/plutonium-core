# Interaction Reference

Complete reference for business logic Interactions.

## Overview

Interactions encapsulate business logic for custom actions. They:
- Accept input from users
- Validate that input
- Execute business logic
- Return success or failure outcomes

## Base Class

```ruby
# app/interactions/resource_interaction.rb (generated during install)
class ResourceInteraction < Plutonium::Resource::Interaction
end

# app/interactions/publish_post_interaction.rb
class PublishPostInteraction < ResourceInteraction
  # Interaction code
end
```

## Presentation

Configure how the action appears in the UI:

```ruby
class PublishPost < Plutonium::Resource::Interaction
  presents label: "Publish Post",
           icon: Phlex::TablerIcons::Send,
           description: "Make this post visible to the public"
end
```

Access presentation metadata:

```ruby
PublishPost.label       # => "Publish Post"
PublishPost.icon        # => Phlex::TablerIcons::Send
PublishPost.description # => "Make this post visible..."
```

## Attributes

Define inputs using ActiveModel attributes:

### Basic Types

```ruby
attribute :title, :string
attribute :count, :integer
attribute :price, :decimal
attribute :active, :boolean
attribute :published_at, :datetime
```

### With Defaults

```ruby
attribute :status, :string, default: "pending"
attribute :notify, :boolean, default: true
attribute :count, :integer, default: 1
attribute :created_at, :datetime, default: -> { Time.current }
```

### The resource Attribute

For record actions, declare a `resource` attribute:

```ruby
class PublishPost < Plutonium::Resource::Interaction
  attribute :resource  # The record being acted upon

  private

  def execute
    resource.update!(published: true)
    succeed(resource)
  end
end
```

### The resources Attribute

For bulk actions, declare a `resources` attribute:

```ruby
class BulkArchive < Plutonium::Resource::Interaction
  attribute :resources  # Collection of records

  private

  def execute
    resources.update_all(archived: true)
    succeed(resources)
  end
end
```

## Form Inputs

Define how attributes render in forms using the `input` method:

```ruby
class InviteUser < Plutonium::Resource::Interaction
  attribute :resource
  attribute :email, :string
  attribute :role, :string

  input :email, as: :email
  input :role, as: :select, choices: %w[admin member viewer]
end
```

See [Fields Reference](/reference/definition/fields) for all input types and options.

## Validation

Use standard ActiveModel validations:

```ruby
class SchedulePost < Plutonium::Resource::Interaction
  attribute :resource
  attribute :publish_at, :datetime

  validates :publish_at, presence: true
  validate :publish_at_in_future

  private

  def publish_at_in_future
    if publish_at.present? && publish_at <= Time.current
      errors.add(:publish_at, "must be in the future")
    end
  end
end
```

Validations run automatically before `execute`. If invalid, returns a failure outcome.

## The execute Method

Main logic goes here. Must return an outcome using `succeed()` or `failed()`:

```ruby
private

def execute
  resource.update!(published: true)
  succeed(resource).with_message("Published!")
rescue ActiveRecord::RecordInvalid => e
  failed(e.record.errors)
end
```

::: warning Handle RecordInvalid
`ActiveRecord::RecordInvalid` is **not** rescued automatically. Always rescue it when using bang methods (`create!`, `update!`, `save!`).
:::

## Constructor

Interactions require `view_context:` and accept attributes as keyword arguments:

```ruby
interaction = PublishPost.new(
  view_context: view_context,
  resource: post,
  notify: true
)
```

The controller handles this automatically for interactive actions.

## Calling Interactions

### Via call Class Method

```ruby
outcome = PublishPost.call(view_context: view_context, resource: post)

if outcome.success?
  # Handle success
else
  # Handle failure
end
```

### Via call Instance Method

```ruby
interaction = PublishPost.new(view_context: view_context, resource: post)
outcome = interaction.call
```

## Success Outcomes

::: tip Automatic Redirect
On success, the controller automatically redirects to the resource.
:::

### Basic Success

```ruby
succeed(resource)  # Redirects to resource automatically
```

### With Message

```ruby
succeed(resource).with_message("Post published!")
succeed(resource).with_message("Warning: limited visibility", :alert)
```

### With Custom Redirect

Useful when redirecting somewhere other than the default:

```ruby
succeed(resource).with_redirect_response(custom_dashboard_path)
```

### With File Download

```ruby
succeed(resource).with_file_response(file_path, filename: "report.pdf")
```

### With Render

```ruby
succeed(resource).with_render_response(:custom_template)
```

### Chaining

```ruby
succeed(resource)
  .with_message("Created!")
  .with_redirect_response(edit_post_path(resource))
```

## Failure Outcomes

### Simple Failure

```ruby
failed("Cannot publish draft posts")
```

### With Attribute

```ruby
failed("is invalid", :email)
```

### With Hash of Errors

```ruby
failed(email: "is invalid", name: "is required")
```

### With ActiveModel Errors

```ruby
failed(resource.errors)
```

### Manual Error Addition

```ruby
def execute
  errors.add(:base, "Post must have content")
  return failure if errors.any?

  # Continue...
end
```

## Chaining Interactions

Use `and_then` to chain operations. On failure, the chain short-circuits:

```ruby
def execute
  CreateUserInteraction.call(view_context:, **user_params)
    .and_then { |result| SendWelcomeEmail.call(view_context:, user: result.value) }
    .and_then { |result| LogActivity.call(view_context:, user: result.value) }
    .with_message("User created and welcomed!")
end
```

## Accessing Current User

```ruby
def execute
  resource.update!(updated_by: current_user)
  succeed(resource)
end

# current_user is provided by the base class:
# def current_user
#   view_context.controller.helpers.current_user
# end
```

## Complete Example

```ruby
class Company::InviteUserInteraction < Plutonium::Resource::Interaction
  presents label: "Invite User",
           icon: Phlex::TablerIcons::UserPlus,
           description: "Send an invitation email"

  attribute :resource  # The company
  attribute :email, :string
  attribute :role, :string

  input :email, as: :email
  input :role, as: :select, choices: -> { UserInvite.roles.keys }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: UserInvite.roles.keys }
  validate :not_already_invited

  private

  def execute
    invite = UserInvite.create!(
      company: resource,
      email: email,
      role: role,
      invited_by: current_user
    )
    UserInviteMailer.invitation(invite).deliver_later

    succeed(resource).with_message("Invitation sent to #{email}")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end

  def not_already_invited
    return unless email.present?

    if UserInvite.exists?(company: resource, email: email, state: :pending)
      errors.add(:email, "already has a pending invitation")
    end
  end
end
```

## Connecting to Definitions

Register interactions as actions in definitions:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  action :publish, interaction: PublishPostInteraction
  action :invite_user, interaction: InviteUserInteraction

  action :archive,
    interaction: ArchiveInteraction,
    confirmation: "Are you sure?",
    category: :danger,
    position: 100
end
```

## Immediate vs Form Actions

Plutonium determines if an action needs a form based on whether inputs are defined:

**Shows form first** (has inputs):

```ruby
class InviteUserInteraction < Plutonium::Resource::Interaction
  attribute :resource
  attribute :email
  input :email  # This triggers form display
end
```

**Executes immediately** (no inputs):

```ruby
class ArchiveInteraction < Plutonium::Resource::Interaction
  attribute :resource
  # No inputs = immediate execution with confirmation
end
```

## Policy Integration

Control access with policy methods matching the action name:

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def publish?
    update? && record.draft?
  end

  def archive?
    destroy? && !record.archived?
  end
end
```

## Testing

```ruby
RSpec.describe PublishPost do
  let(:view_context) { double("view_context", controller: double(helpers: double(current_user: user))) }
  let(:user) { create(:user) }
  let(:post) { create(:post, user: user, published: false) }

  describe '#call' do
    it 'publishes the post' do
      interaction = described_class.new(view_context: view_context, resource: post)
      outcome = interaction.call

      expect(outcome).to be_success
      expect(post.reload).to be_published
    end

    context 'when validation fails' do
      it 'returns failure outcome' do
        interaction = described_class.new(view_context: view_context, resource: nil)
        outcome = interaction.call

        expect(outcome).to be_failure
      end
    end
  end
end
```

## Best Practices

1. **Keep interactions focused** - One action per interaction
2. **Use validations** - Validate all inputs before execution
3. **Handle errors gracefully** - Rescue exceptions and return `failed()`

## Related

- [Actions Reference](/reference/definition/actions) - Connecting interactions to definitions
- [Fields Reference](/reference/definition/fields) - Input configuration
- [Policy Reference](/reference/policy/) - Authorization
