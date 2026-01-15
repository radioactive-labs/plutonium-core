---
title: Action Module
---

# Action Module

The Action module provides a comprehensive system for defining and managing custom actions in Plutonium applications. Actions represent operations that can be performed on resources, from simple navigation to complex business logic.

::: tip
The Action module is located in `lib/plutonium/action/`. Actions are typically defined within a resource's Definition file.
:::

## Overview

- **Declarative Definition**: Define actions with metadata and behavior in your resource definition files.
- **Multiple Action Types**: Support for actions on individual records, entire resources, or bulk collections.
- **UI Integration**: Automatic button and form generation in the UI.
- **Authorization Support**: Integrates with policies to control action visibility and execution.

## Defining Actions

Actions are typically defined in a resource definition file using the `action` method.

```ruby
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # An action that runs a complex operation via an Interaction
  action :publish,
         interaction: PublishPostInteraction,
         icon: Phlex::TablerIcons::Send,
         category: :primary

  # A simple navigation action
  action :export,
         route_options: { action: :export, format: :csv },
         icon: Phlex::TablerIcons::Download,
         resource_action: true # This is a resource-level action

  # A destructive action with a confirmation
  action :archive,
         interaction: ArchivePostInteraction,
         icon: Phlex::TablerIcons::Archive,
         category: :danger,
         confirmation: "Are you sure you want to archive this post?"
end
```

### Action Types

You can specify where an action should be available.

::: code-group
```ruby [Record Action]
# Shows on the record's #show page and in the table row.
action :edit,
       record_action: true,
       collection_record_action: true,
       icon: Phlex::TablerIcons::Edit
```
```ruby [Resource Action]
# Shows on the resource's #index page (e.g., "Import").
action :import,
       resource_action: true,
       icon: Phlex::TablerIcons::Upload
```
```ruby [Bulk Action]
# Appears when records are selected on the #index page.
action :bulk_delete,
       bulk_action: true,
       category: :danger,
       icon: Phlex::TablerIcons::Trash
```
:::

### Action Categories & Positioning

Categories and positioning control the visual appearance and order of action buttons.

- **`category`**: Can be `:primary`, `:secondary`, or `:danger`.
- **`position`**: A number used for sorting; lower numbers appear first (default: 50).

```ruby
# A prominent primary action
action :create, category: :primary, position: 10

# A standard secondary action
action :archive, category: :secondary, position: 50

# A destructive action, shown last
action :delete, category: :danger, position: 100
```

## Action Types

### Simple Actions

Simple actions link to existing routes. **The target route must already exist** - these don't create new functionality, just navigation links.

::: code-group
```ruby [External Link]
# Links to an external URL - works directly
action :documentation,
       label: "Documentation",
       route_options: { url: "https://docs.example.com" },
       icon: Phlex::TablerIcons::Book,
       resource_action: true
```
```ruby [Internal Link]
# Navigates to a custom controller action
# NOTE: You must add the controller action and route yourself
action :view_reports,
       label: "View Reports",
       route_options: { action: :reports },
       icon: Phlex::TablerIcons::ChartBar,
       resource_action: true
```
:::

::: warning Simple Actions Require Existing Routes
For internal links with `route_options: { action: :reports }`, the controller action and route must already exist. Simple actions are navigation links, not operation definitions.

**For custom operations with business logic, use Interactive Actions with an Interaction class instead.** That's the recommended approach for most custom actions.
:::

### Dynamic Route Options

For actions that need dynamic URL generation based on the current record or context, use the `RouteOptions` class with a custom `url_resolver`:

::: code-group
```ruby [Dynamic Parent-Child Navigation]
# Navigate to create a child resource with the current record as parent
action :create_deployment,
       label: "Create Deployment",
       icon: Phlex::TablerIcons::Rocket,
       record_action: true,
       route_options: Plutonium::Action::RouteOptions.new(
         url_resolver: ->(subject) {
           resource_url_for(UniversalFlow::Deployment, action: :new, parent: subject)
         }
       )
```
```ruby [Conditional Routing]
# Different routes based on user permissions or record state
action :manage_settings,
       label: "Manage Settings",
       resource_action: true,
       route_options: Plutonium::Action::RouteOptions.new(
         url_resolver: ->(subject) {
           if current_user.admin?
             admin_settings_path(subject)
           else
             basic_settings_path(subject)
           end
         }
       )
```
```ruby [External Integration]
# Dynamic external URLs based on record attributes
action :view_external,
       label: "View in External System",
       record_action: true,
       route_options: Plutonium::Action::RouteOptions.new(
         url_resolver: ->(subject) {
           "https://external-system.com/items/#{subject.external_id}"
         }
       )
```
:::

The `url_resolver` lambda receives the current record (for record actions) or resource class (for resource actions) as the `subject` parameter, allowing you to generate URLs dynamically based on the context.

### Interactive Actions

Interactive actions are powered by an `Interaction` class and handle business logic. The action's properties (label, description, etc.) are often inferred from the interaction itself.

```ruby
# The action is automatically configured based on the interaction
action :publish,
       interaction: PublishPostInteraction,
       icon: Phlex::TablerIcons::Send
```

::: details Automatic Type Detection from Interaction
The Action module inspects the interaction's attributes to determine its type (`record`, `resource`, or `bulk`).
```ruby
# This will be a RECORD action because it has a `:resource` attribute.
class PublishPostInteraction < Plutonium::Interaction::Base
  attribute :resource
  attribute :publish_date, :date
end

# This will be a BULK action because it has a `:resources` attribute.
class BulkArchiveInteraction < Plutonium::Interaction::Base
  attribute :resources
  attribute :archive_reason, :string
end

# This will be a RESOURCE action because it has neither.
class ImportPostsInteraction < Plutonium::Interaction::Base
  attribute :csv_file, :string
end
```
:::

::: details Immediate vs. Modal Actions
- If an interaction has **only** a `resource` or `resources` attribute, the action will execute immediately on click.
- If it has **any other attributes**, a modal form will be rendered to collect user input before execution.
```ruby
# IMMEDIATE: No extra inputs, runs on click.
class SimplePublishInteraction < Plutonium::Interaction::Base
  attribute :resource
end

# MODAL: Requires `publish_date`, so a form will be shown.
class ScheduledPublishInteraction < Plutonium::Interaction::Base
  attribute :resource
  attribute :publish_date, :datetime
end
```
:::

## Action Inheritance

### Inherited Actions

Actions defined in your base `ResourceDefinition` (created during install) are inherited by all resource definitions:

```ruby
# app/definitions/resource_definition.rb (created during install)
class ResourceDefinition < Plutonium::Resource::Definition
  # All resources get this archive action
  action :archive,
    interaction: ArchiveInteraction,
    color: :danger,
    position: 1000
end

# app/definitions/post_definition.rb
class PostDefinition < ResourceDefinition
  # Inherits :archive automatically
  # Add resource-specific actions
  action :publish, interaction: PublishInteraction
end
```

### Portal-Specific Actions

After connecting a resource to a portal, you can add or override actions for that portal only:

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  # Add admin-only actions
  action :feature, interaction: FeaturePostInteraction
  action :bulk_publish,
    interaction: BulkPublishInteraction,
    bulk_action: true

  # Override inherited action options for this portal
  action :archive,
    interaction: ArchiveInteraction,
    collection_record_action: true  # Show in table rows for admins
end
```

This lets you:
- Add portal-specific actions (admin-only operations)
- Override action visibility per portal
- Customize action behavior for different user types

## Best Practices

### Action Design

1. **Clear Intent**: Use descriptive action names that clearly indicate what they do
2. **Consistent Categories**: Group related actions using consistent categories
3. **Appropriate Icons**: Choose icons that clearly represent the action
4. **Meaningful Confirmations**: Use confirmation messages for destructive actions
5. **Logical Positioning**: Order actions by importance and frequency of use

### Dynamic Route Actions

1. **Context Awareness**: Use the subject parameter to make routing decisions based on the current record or resource
2. **Error Handling**: Handle cases where dynamic URLs might fail (e.g., missing external IDs)
3. **Performance**: Keep url_resolver lambdas simple to avoid performance issues
4. **Security**: Validate permissions within the lambda when generating sensitive URLs

### Interactive Actions

1. **Single Purpose**: Each action should have a single, well-defined purpose
2. **Input Validation**: Always validate user inputs in the interaction
3. **Error Messages**: Provide clear, actionable error messages
4. **Success Feedback**: Give users clear feedback when actions complete successfully
5. **Idempotency**: Design actions to be safely repeatable when possible

### Security

1. **Authorization**: Always check user permissions before executing actions
2. **Input Sanitization**: Sanitize all user inputs
3. **CSRF Protection**: Include CSRF tokens in all action forms
4. **Rate Limiting**: Implement rate limiting for resource-intensive actions
5. **Audit Logging**: Log important actions for security auditing
