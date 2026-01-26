# Definition Actions

Complete reference for custom actions in definitions.

## Overview

Actions add buttons beyond standard CRUD operations. Two types:

1. **Simple Actions** - Navigate to URLs
2. **Interactive Actions** - Execute Interactions with optional user input

## Action Types

| Type | Shows In | Use Case |
|------|----------|----------|
| `resource_action` | Index page | Import, Export, Create |
| `record_action` | Show page | Edit, Delete, Archive |
| `collection_record_action` | Table rows | Quick actions per row |
| `bulk_action` | Selected records | Bulk operations |

## Simple Actions

Simple actions link to existing routes. The target route must already exist.

```ruby
class PostDefinition < Plutonium::Resource::Definition
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

::: warning Always Name Custom Routes
When adding custom routes for actions, always use the `as:` option:

```ruby
resources :posts do
  collection do
    get :reports, as: :reports  # Named route required!
  end
end
```

This ensures `resource_url_for` can generate correct URLs, especially for nested resources.
:::

**Note:** For custom operations with business logic, use **Interactive Actions** with an Interaction class.

## Interactive Actions

```ruby
class PostDefinition < Plutonium::Resource::Definition
  action :publish,
    interaction: PublishInteraction,
    icon: Phlex::TablerIcons::Send

  action :archive,
    interaction: ArchiveInteraction,
    color: :danger,
    category: :danger,
    position: 1000,
    confirmation: "Are you sure?"
end
```

## Action Options

```ruby
action :name,
  # Display
  label: "Custom Label",           # Button text (default: name.titleize)
  description: "What it does",     # Tooltip/description
  icon: Phlex::TablerIcons::Star,  # Icon component

  # Styling
  color: :danger,                  # :primary, :secondary, :danger

  # Visibility (boolean flags)
  resource_action: true,           # Show on index page
  record_action: true,             # Show on show page
  collection_record_action: true,  # Show in table rows
  bulk_action: true,               # For selected records

  # Grouping
  category: :primary,              # :primary, :secondary, :danger
  position: 50,                    # Order (lower = first)

  # Behavior
  confirmation: "Are you sure?",   # Confirmation dialog
  turbo_frame: "_top",             # Turbo frame target
  return_to: "/custom/path",       # Override return URL
  route_options: {action: :foo}    # Route configuration
```

## Route Options

Configure how the action's URL is generated:

```ruby
# Simple route to controller action
action :preview,
  route_options: {action: :preview},
  record_action: true

# With HTTP method
action :archive,
  route_options: {method: :post, action: :archive},
  record_action: true

# External URL
action :docs,
  route_options: {url: "https://docs.example.com"},
  resource_action: true

# Custom URL resolver
action :create_deployment,
  route_options: Plutonium::Action::RouteOptions.new(
    url_resolver: ->(subject) {
      resource_url_for(Deployment, action: :new, parent: subject)
    }
  ),
  record_action: true
```

## Built-in CRUD Actions

These are defined by default:

```ruby
action :new,
  route_options: {action: :new},
  resource_action: true,
  category: :primary,
  icon: Phlex::TablerIcons::Plus,
  position: 10

action :show,
  route_options: {action: :show},
  collection_record_action: true,
  icon: Phlex::TablerIcons::Eye,
  position: 10

action :edit,
  route_options: {action: :edit},
  record_action: true,
  collection_record_action: true,
  icon: Phlex::TablerIcons::Edit,
  position: 20

action :destroy,
  route_options: {method: :delete},
  record_action: true,
  collection_record_action: true,
  category: :danger,
  icon: Phlex::TablerIcons::Trash,
  position: 100,
  confirmation: "Are you sure?",
  turbo_frame: "_top"
```

### Customizing Built-in Actions

Override in your definition:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Customize delete confirmation
  action :destroy,
    confirmation: "This will permanently delete the post and all comments.",
    route_options: {method: :delete},
    record_action: true,
    collection_record_action: true,
    category: :danger,
    icon: Phlex::TablerIcons::Trash,
    position: 100,
    turbo_frame: "_top"
end
```

## Authorization

Actions are authorized via policies:

```ruby
# app/policies/post_policy.rb
class PostPolicy < Plutonium::Resource::Policy
  def publish?
    user.admin? || record.author == user
  end

  def archive?
    user.admin?
  end
end
```

The action only appears if the policy method returns `true`.

## Immediate vs Form Actions

**Immediate** - Executes without showing a form (when interaction has no extra inputs):

```ruby
class ArchiveInteraction < Plutonium::Resource::Interaction
  attribute :resource  # Only resource, no other inputs
  # No input declarations

  def execute
    resource.archived!
    succeed(resource)
  end
end
```

**Form** - Shows a form first (when interaction has additional inputs):

```ruby
class InviteUserInteraction < Plutonium::Resource::Interaction
  attribute :resource
  attribute :email
  attribute :role

  input :email
  input :role, as: :select, choices: %w[admin member]
  # Has inputs = shows form first
end
```

## Interaction Reference

### Basic Structure

```ruby
class PublishInteraction < Plutonium::Resource::Interaction
  presents label: "Publish",
           icon: Phlex::TablerIcons::Send,
           description: "Make this post public"

  attribute :resource  # The record being acted upon

  private

  def execute
    resource.update!(published: true, published_at: Time.current)
    succeed(resource).with_message("Published!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

### With User Input

```ruby
class InviteUserInteraction < Plutonium::Resource::Interaction
  presents label: "Invite User", icon: Phlex::TablerIcons::Mail

  attribute :resource  # The company
  attribute :email
  attribute :role

  input :email, as: :email
  input :role, as: :select, choices: %w[admin member viewer]

  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :role, presence: true

  private

  def execute
    UserInvite.create!(
      company: resource,
      email: email,
      role: role
    )
    succeed(resource).with_message("Invitation sent to #{email}.")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

### Bulk Action

Bulk actions operate on multiple selected records. When registered, the resource table automatically shows:
- **Selection checkboxes** in each row
- **Bulk actions toolbar** that appears when records are selected

```ruby
class BulkArchiveInteraction < Plutonium::Resource::Interaction
  presents label: "Archive Selected", icon: Phlex::TablerIcons::Archive

  attribute :resources  # Array of records (note: plural)

  private

  def execute
    count = 0
    resources.each do |record|
      record.archived!
      count += 1
    end
    succeed(resources).with_message("#{count} records archived.")
  end
end
```

Register in definition:

```ruby
class PostDefinition < ResourceDefinition
  action :bulk_archive, interaction: BulkArchiveInteraction
  # bulk_action: true is automatically inferred from `resources` attribute
end
```

Add the policy method (checked per-record):

```ruby
class PostPolicy < ResourcePolicy
  def bulk_archive?
    # Can use record attributes - checked for each selected record
    user.admin? || record.author == user
  end
end
```

::: tip Bulk Action Authorization
Bulk actions use **per-record authorization**:
- Policy method (e.g., `bulk_archive?`) is checked for **each selected record** - you can use `record` attributes
- Backend rejects the entire request if any record fails authorization
- UI only shows actions that **all** selected records support
:::

### Resource Action (No Record)

```ruby
class ImportInteraction < Plutonium::Resource::Interaction
  presents label: "Import CSV", icon: Phlex::TablerIcons::Upload

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

## Interaction Responses

```ruby
def execute
  # Success with message (redirects to resource automatically)
  succeed(resource).with_message("Done!")

  # Success with custom redirect (only if different from default)
  succeed(resource)
    .with_redirect_response(custom_dashboard_path)
    .with_message("Redirecting...")

  # Failure with field errors
  failed(resource.errors)

  # Failure with custom message
  failed("Something went wrong")
end
```

::: tip Automatic Redirect
Redirect is automatic on success. You can use `with_redirect_response` for a different destination.
:::

## Inherited Actions

Actions defined in `ResourceDefinition` are inherited by all definitions:

```ruby
# app/definitions/resource_definition.rb
class ResourceDefinition < Plutonium::Resource::Definition
  action :archive,
    interaction: ArchiveInteraction,
    color: :danger,
    position: 1000
end

# All definitions inherit the archive action automatically
class PostDefinition < ResourceDefinition
end
```

## Portal-Specific Actions

Override actions for a specific portal:

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  # Add admin-only actions
  action :feature, interaction: FeaturePostInteraction
  action :bulk_publish, interaction: BulkPublishInteraction
end
```

## Common Patterns

### Archive/Restore

```ruby
action :archive,
  interaction: ArchiveInteraction,
  record_action: true,
  color: :danger

action :restore,
  interaction: RestoreInteraction,
  record_action: true
```

### Export

```ruby
action :export,
  interaction: ExportInteraction,
  resource_action: true,
  icon: Phlex::TablerIcons::Download
```

## Related

- [Definition Reference](./index)
- [Fields Reference](./fields)
- [Query Reference](./query)
