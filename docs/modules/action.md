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

Simple actions are for basic navigation or links. They are defined with `route_options`.

::: code-group
```ruby [Internal Link]
# Navigates to the #reports action on the current controller
action :view_reports,
       label: "View Reports",
       route_options: { action: :reports },
       icon: Phlex::TablerIcons::ChartBar
```
```ruby [External Link]
# Links to an external URL
action :documentation,
       label: "Documentation",
       route_options: { url: "https://docs.example.com" },
       icon: Phlex::TablerIcons::Book
```
:::

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

## Best Practices

### Action Design

1. **Clear Intent**: Use descriptive action names that clearly indicate what they do
2. **Consistent Categories**: Group related actions using consistent categories
3. **Appropriate Icons**: Choose icons that clearly represent the action
4. **Meaningful Confirmations**: Use confirmation messages for destructive actions
5. **Logical Positioning**: Order actions by importance and frequency of use

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
