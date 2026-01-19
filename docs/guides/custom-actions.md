# Custom Actions

This guide covers adding custom actions beyond standard CRUD operations.

## Overview

Custom actions let you add buttons like "Publish", "Archive", or "Send Invoice" to your resources. Actions can be:

- **Simple** - Navigation to another page
- **Interactive** - Execute business logic with optional user input

## Action Types

| Type | Shows In | Use Case |
|------|----------|----------|
| `resource_action` | Index page | Import, Export, Create new |
| `record_action` | Show page | Edit, Delete, Archive |
| `collection_record_action` | Table rows | Quick actions per row |
| `bulk_action` | Selected records | Bulk operations |

## Simple Actions (Navigation)

For actions that just navigate somewhere (the target route must already exist):

```ruby
class PostDefinition < ResourceDefinition
  # Link to external URL
  action :documentation,
    label: "Documentation",
    route_options: {url: "https://docs.example.com"},
    icon: Phlex::TablerIcons::Book,
    resource_action: true

  # Link to custom controller action
  action :reports,
    route_options: {action: :reports},
    icon: Phlex::TablerIcons::ChartBar,
    resource_action: true
end
```

**Note:** For custom operations with business logic, use Interactive Actions with an Interaction class.

## Interactive Actions with Interactions

For actions that execute business logic, use Interactions.

### Creating an Interaction

```ruby
# app/interactions/resource_interaction.rb (generated during install)
class ResourceInteraction < Plutonium::Resource::Interaction
end

# app/interactions/publish_post_interaction.rb
class PublishPostInteraction < ResourceInteraction
  # UI configuration
  presents label: "Publish Post",
           icon: Phlex::TablerIcons::Send,
           description: "Make this post public"

  # The record being acted on
  attribute :resource

  # Validation
  validate :not_already_published

  private

  # Main logic
  def execute
    resource.update!(
      published: true,
      published_at: Time.current
    )

    succeed(resource)
      .with_message("Post published successfully!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end

  def not_already_published
    if resource.published?
      errors.add(:base, "Post is already published")
    end
  end
end
```

### Registering the Action

```ruby
class PostDefinition < ResourceDefinition
  action :publish, interaction: PublishPostInteraction
end
```

### Authorizing the Action

```ruby
class PostPolicy < ResourcePolicy
  def publish?
    update? && !record.published?
  end
end
```

## Actions with User Input

Interactions can accept user input via attributes:

```ruby
class SchedulePostInteraction < ResourceInteraction
  presents label: "Schedule Publication",
           icon: Phlex::TablerIcons::Calendar

  # The record
  attribute :resource

  # User inputs
  attribute :publish_at, :datetime
  attribute :notify_subscribers, :boolean, default: true

  # Configure form inputs
  input :publish_at, as: :datetime
  input :notify_subscribers, as: :boolean

  # Validations
  validates :publish_at, presence: true
  validate :publish_at_in_future

  private

  def execute
    resource.update!(
      scheduled_at: publish_at,
      notify_on_publish: notify_subscribers
    )

    SchedulePublicationJob.perform_at(publish_at, resource.id)

    succeed(resource)
      .with_message("Post scheduled for #{publish_at.strftime('%B %d at %I:%M %p')}")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end

  def publish_at_in_future
    if publish_at.present? && publish_at <= Time.current
      errors.add(:publish_at, "must be in the future")
    end
  end
end
```

Register with the definition:

```ruby
action :schedule, interaction: SchedulePostInteraction
```

Now users see a form with date picker and checkbox before execution.

## Immediate vs Form Actions

Plutonium automatically determines if an action needs a form:

- **Has inputs defined** → Shows form first
- **No inputs** → Executes immediately (with optional confirmation)

```ruby
# Shows form (has inputs)
class InviteUserInteraction < ResourceInteraction
  attribute :resource
  attribute :email
  input :email  # This triggers form display
end

# Immediate execution (no inputs)
class ArchiveInteraction < ResourceInteraction
  attribute :resource
  # No inputs = immediate with confirmation
end
```

## Action Visibility

Control where actions appear:

```ruby
action :publish,
  interaction: PublishPostInteraction,
  record_action: true,             # Show on show page
  collection_record_action: true   # Show in table rows
```

### Record Actions (Single Records)

```ruby
action :publish, interaction: PublishPostInteraction
action :archive, interaction: ArchiveInteraction, record_action: true
```

### Bulk Actions (Multiple Records)

```ruby
action :bulk_publish, interaction: BulkPublishInteraction
action :bulk_archive, interaction: BulkArchiveInteraction
```

### Resource Actions (No Record)

```ruby
action :import, interaction: ImportInteraction, resource_action: true
action :export, interaction: ExportInteraction, resource_action: true
```

## Bulk Action Interaction

Bulk actions operate on multiple selected records. When a definition has bulk actions, the resource table automatically shows:
- **Selection checkboxes** in each row
- **Bulk actions toolbar** that appears when records are selected

```ruby
class BulkPublishInteraction < ResourceInteraction
  presents label: "Publish Selected",
           icon: Phlex::TablerIcons::Send

  # Note: plural 'resources' for bulk actions
  attribute :resources

  private

  def execute
    count = resources.update_all(
      published: true,
      published_at: Time.current
    )

    succeed(resources)
      .with_message("#{count} posts published")
  end
end
```

Register in your definition:

```ruby
class PostDefinition < ResourceDefinition
  action :bulk_publish, interaction: BulkPublishInteraction
  # bulk_action: true is automatically inferred from `resources` attribute
end
```

Add the policy method (checked per-record):

```ruby
class PostPolicy < ResourcePolicy
  def bulk_publish?
    # Can use record attributes - checked for each selected record
    user.admin? || record.author == user
  end
end
```

::: tip Bulk Action Authorization
Bulk actions use **per-record authorization**:
- The policy method (e.g., `bulk_publish?`) is checked for **each selected record** - you can use `record` attributes
- Backend rejects the entire request if any record fails authorization
- UI only shows actions that **all** selected records support (buttons hide dynamically as you select)
- Records are fetched from `current_authorized_scope` - only accessible records can be selected
:::

## Resource Action (No Record)

```ruby
class ImportInteraction < ResourceInteraction
  presents label: "Import CSV",
           icon: Phlex::TablerIcons::Upload

  # No :resource or :resources = resource action
  attribute :file

  input :file, as: :file

  validates :file, presence: true

  private

  def execute
    # Import logic...
    succeed(nil).with_message("Import completed.")
  end
end
```

## Action Options

```ruby
action :name,
  interaction: MyInteraction,

  # Display
  label: "Custom Label",           # Override interaction label
  icon: Phlex::TablerIcons::Star,  # Override interaction icon
  color: :danger,                  # :primary, :secondary, :danger

  # Visibility
  resource_action: true,           # Show on index page
  record_action: true,             # Show on show page
  collection_record_action: true,  # Show in table rows
  bulk_action: true,               # For selected records

  # Grouping
  category: :danger,               # :primary, :secondary, :danger
  position: 50,                    # Order (lower = first)

  # Behavior
  confirmation: "Are you sure?",   # Confirmation dialog
  turbo_frame: "_top"              # Turbo frame target
```

## Confirmation Dialogs

Require confirmation before executing:

```ruby
action :delete,
  interaction: DeleteInteraction,
  confirmation: "Are you sure you want to delete this post?"

action :bulk_delete,
  interaction: BulkDeleteInteraction,
  confirmation: "Delete all selected posts? This cannot be undone."
```

## Interaction Outcomes

### Success

::: tip Automatic Redirect
On success, the controller automatically redirects to the resource. You can use `with_redirect_response` if you want a **different** destination.
:::

```ruby
def execute
  # ... do work ...

  # Basic success
  succeed(resource)

  # With message
  succeed(resource).with_message("Success!")

  # With redirect
  succeed(resource)
    .with_redirect_response(posts_path)
    .with_message("Post created!")

  # With file download
  succeed(resource)
    .with_file_response(pdf_path, filename: "invoice.pdf")
end
```

### Failure

```ruby
def execute
  # From ActiveModel errors
  failed(resource.errors)

  # With custom message
  failed("Something went wrong")

  # With specific field
  failed("is invalid", :email)

  # With hash of errors
  failed(email: "is invalid", name: "is required")
end
```

### Chaining Interactions

```ruby
def execute
  CreateUserInteraction.call(view_context:, **user_params)
    .and_then { |result| SendWelcomeEmail.call(view_context:, user: result.value) }
    .and_then { |result| LogActivity.call(view_context:, user: result.value) }
    .with_message("User created and welcomed!")
end
```

On failure, the chain short-circuits and returns the failure immediately.

## Accessing Context

Interactions have access to `current_user` and `view_context`:

```ruby
class PublishPostInteraction < ResourceInteraction
  attribute :resource

  private

  def execute
    resource.update!(
      published: true,
      published_by: current_user  # Built-in helper
    )

    succeed(resource)
  end
end
```

For advanced access:

```ruby
def execute
  # Access helpers via view_context
  view_context.controller.helpers.some_helper

  # Access params
  view_context.params

  succeed(resource)
end
```

## Complete Example: Send Invoice

```ruby
class SendInvoiceInteraction < ResourceInteraction
  presents label: "Send Invoice",
           icon: Phlex::TablerIcons::Mail,
           description: "Email invoice to recipient"

  attribute :resource  # The invoice
  attribute :recipient_email, :string
  attribute :message, :text
  attribute :attach_pdf, :boolean, default: true

  input :recipient_email, as: :email, hint: "Recipient's email address"
  input :message, as: :text, hint: "Optional message to include"
  input :attach_pdf, as: :boolean

  validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def execute
    # Generate PDF if requested
    pdf = attach_pdf ? generate_pdf : nil

    # Send email
    InvoiceMailer.send_invoice(
      invoice: resource,
      to: recipient_email,
      message: message,
      attachment: pdf
    ).deliver_later

    # Update invoice status
    resource.update!(
      sent_at: Time.current,
      sent_to: recipient_email
    )

    succeed(resource)
      .with_message("Invoice sent to #{recipient_email}")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end

  def generate_pdf
    InvoicePdfGenerator.new(resource).generate
  end
end
```

## Inherited Actions

Define common actions in your base definition:

```ruby
# app/definitions/resource_definition.rb
class ResourceDefinition < Plutonium::Resource::Definition
  action :archive,
    interaction: ArchiveInteraction,
    color: :danger,
    position: 1000
end

# All definitions inherit the archive action
class PostDefinition < ResourceDefinition
  # Already has :archive action
end
```

## Portal-Specific Actions

Override or add actions for specific portals:

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  # Add admin-only actions
  action :feature, interaction: FeaturePostInteraction
  action :bulk_publish, interaction: BulkPublishInteraction
end
```

## Testing Interactions

```ruby
RSpec.describe PublishPostInteraction do
  let(:user) { create(:user) }
  let(:post) { create(:post, user: user, published: false) }
  let(:view_context) { double(controller: double(helpers: double(current_user: user))) }

  subject { described_class.new(view_context: view_context, resource: post) }

  describe '#call' do
    it 'publishes the post' do
      result = subject.call

      expect(result).to be_success
      expect(post.reload.published?).to be true
    end

    context 'when already published' do
      before { post.update!(published: true) }

      it 'fails with error' do
        result = subject.call

        expect(result).to be_failure
        expect(subject.errors[:base]).to include("Post is already published")
      end
    end
  end
end
```

## Best Practices

1. **Keep interactions focused** - One action per interaction
2. **Use validations** - Validate all inputs before execution
3. **Handle errors gracefully** - Rescue exceptions and return `failed()`
4. **Return meaningful messages** - Help users understand what happened
5. **Use `and_then` for chains** - Compose complex workflows from simple interactions

## Related

- [Authorization](./authorization)
- [Adding Resources](./adding-resources)
