# Interaction Module

The Interaction module provides a powerful architectural pattern for organizing business logic around user interactions and business actions. It builds upon the traditional MVC pattern by introducing additional layers that encapsulate business logic and improve separation of concerns.

## Overview

The Interaction module is located in `lib/plutonium/interaction/` and provides:

- Business logic encapsulation separate from controllers
- Consistent handling of success and failure cases
- Flexible and expressive operation chaining
- Integration with ActiveModel for validation
- Response handling for controller actions
- Outcome-based result handling

## Key Benefits

- Clear separation of business logic from controllers
- Improved testability of business operations
- Consistent handling of success and failure cases
- Flexible and expressive way to chain operations
- Enhanced maintainability and readability of complex business processes
- Improved code organization and discoverability of business logic

## Core Components

### Interaction Base (`lib/plutonium/interaction/base.rb`)

The foundation for all interactions, integrating with ActiveModel for attributes and validations.

```ruby
class CreateUserInteraction < Plutonium::Interaction::Base
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def execute
    user = User.new(attributes)
    if user.save
      succeed(user)
        .with_redirect_response(user_path(user))
        .with_message("User was successfully created.")
    else
      failed(user.errors)
    end
  end
end
```

#### Key Methods

- `call(view_context:, **attributes)` - Class method to execute the interaction
- `succeed(value)` - Create a successful outcome (aliased as `success`)
- `failed(errors)` - Create a failed outcome
- `attributes` - Access to all defined attributes
- `valid?` / `invalid?` - ActiveModel validation methods

### Outcome (`lib/plutonium/interaction/outcome.rb`)

Encapsulates the result of an interaction with success/failure state and optional response.

#### Success Outcome

```ruby
# Creating a success outcome
outcome = succeed(user)
  .with_message("User created successfully")
  .with_redirect_response(user_path(user))

# Checking outcome
outcome.success? # => true
outcome.failure? # => false
outcome.value    # => user object
outcome.messages # => [["User created successfully", :notice]]
```

#### Failure Outcome

```ruby
# Creating a failure outcome
outcome = failed(user.errors)
  .with_message("Failed to create user", :error)

# Checking outcome
outcome.success? # => false
outcome.failure? # => true
outcome.messages # => [["Failed to create user", :error]]
```

#### Outcome Chaining

```ruby
def execute
  CreateUserInteraction.call(view_context: view_context, **user_params)
    .and_then { |user| SendWelcomeEmailInteraction.call(view_context: view_context, user: user) }
    .and_then { |result| LogUserCreationInteraction.call(view_context: view_context, user: result.value) }
    .with_redirect_response(dashboard_path)
    .with_message("Welcome! Your account has been created.")
end
```

### Response System (`lib/plutonium/interaction/response/`)

Handles controller responses after successful interactions.

#### Built-in Response Types

**Redirect Response**
```ruby
.with_redirect_response(user_path(user))
.with_redirect_response(posts_path, notice: "Post created")
```

**Render Response**
```ruby
.with_render_response(:show, locals: { user: user })
.with_render_response(:edit, status: :unprocessable_entity)
```

**File Response**
```ruby
.with_file_response(file_path, filename: "report.pdf")
```

**Null Response**
```ruby
# Default response when no specific response is set
# Allows controller to handle response manually
```

#### Processing Responses in Controllers

```ruby
class ApplicationController < ActionController::Base
  private

  def handle_interaction_outcome(outcome)
    if outcome.success?
      outcome.to_response.process(self) do |value|
        # Default response if no specific response is set
        render json: { success: true, data: value }
      end
    else
      outcome.messages.each { |msg, type| flash.now[type || :error] = msg }
      render json: { errors: outcome.errors }, status: :unprocessable_entity
    end
  end
end
```

### Nested Attributes (`lib/plutonium/interaction/nested_attributes.rb`)

Handle nested resource attributes in interactions.

```ruby
class CreatePostWithTagsInteraction < Plutonium::Interaction::Base
  include Plutonium::Interaction::NestedAttributes

  attribute :title, :string
  attribute :content, :text
  attribute :tags_attributes, :array

  validates :title, :content, presence: true

  private

  def execute
    post = Post.new(title: title, content: content)

    if post.save
      process_nested_attributes(post, :tags, tags_attributes)
      succeed(post)
    else
      failed(post.errors)
    end
  end
end
```

## Usage Patterns

### Basic Interaction

```ruby
# Define the interaction
class PublishPostInteraction < Plutonium::Interaction::Base
  attribute :post_id, :integer
  attribute :published_at, :datetime, default: -> { Time.current }

  validates :post_id, presence: true

  private

  def execute
    post = Post.find(post_id)

    if post.update(published: true, published_at: published_at)
      succeed(post)
        .with_message("Post published successfully")
        .with_redirect_response(post_path(post))
    else
      failed(post.errors)
    end
  end
end

# Use in controller
class PostsController < ApplicationController
  def publish
    outcome = PublishPostInteraction.call(
      view_context: view_context,
      post_id: params[:id]
    )

    handle_interaction_outcome(outcome)
  end
end
```

### Complex Business Logic

```ruby
class ProcessOrderInteraction < Plutonium::Interaction::Base
  attribute :order_id, :integer
  attribute :payment_method, :string
  attribute :shipping_address, :string

  validates :order_id, :payment_method, :shipping_address, presence: true

  private

  def execute
    order = Order.find(order_id)

    # Validate order can be processed
    return failed("Order already processed") if order.processed?
    return failed("Insufficient inventory") unless check_inventory(order)

    # Process payment
    payment_result = process_payment(order)
    return failed(payment_result.errors) unless payment_result.success?

    # Update order
    order.update!(
      status: 'processing',
      payment_method: payment_method,
      shipping_address: shipping_address,
      processed_at: Time.current
    )

    # Send notifications
    OrderMailer.confirmation_email(order).deliver_later
    NotifyWarehouseJob.perform_later(order)

    succeed(order)
      .with_message("Order processed successfully")
      .with_redirect_response(order_path(order))
  end

  def check_inventory(order)
    order.line_items.all? { |item| item.product.stock >= item.quantity }
  end

  def process_payment(order)
    PaymentService.charge(
      amount: order.total,
      method: payment_method,
      order_id: order.id
    )
  end
end
```

### Interaction Composition

```ruby
class CompleteUserOnboardingInteraction < Plutonium::Interaction::Base
  attribute :user_id, :integer
  attribute :profile_data, :hash
  attribute :preferences, :hash

  private

  def execute
    user = User.find(user_id)

    # Chain multiple interactions
    UpdateUserProfileInteraction.call(view_context: view_context, user: user, **profile_data)
      .and_then { |result| SetUserPreferencesInteraction.call(view_context: view_context, user: result.value, **preferences) }
      .and_then { |result| SendWelcomeEmailInteraction.call(view_context: view_context, user: result.value) }
      .and_then { |result| CreateDefaultDashboardInteraction.call(view_context: view_context, user: result.value) }
      .with_message("Welcome! Your account setup is complete.")
      .with_redirect_response(dashboard_path)
  end
end
```

## Integration with Plutonium

### Resource Actions

Interactions integrate seamlessly with resource definitions:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  action :publish, interaction: PublishPostInteraction
  action :archive, interaction: ArchivePostInteraction
  action :feature, interaction: FeaturePostInteraction
end
```

### Dynamic Route Actions

For actions that need dynamic URL generation, combine interactions with custom route options:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Simple interaction with static route
  action :publish, interaction: PublishPostInteraction

  # Complex action with dynamic route generation using RouteOptions
  action :create_deployment,
    label: "Create Deployment",
    icon: Phlex::TablerIcons::Rocket,
    record_action: true,
    interaction: CreateDeploymentInteraction,
    route_options: Plutonium::Action::RouteOptions.new(
      url_resolver: ->(subject) {
        resource_url_for(Deployment, action: :new, parent: subject)
      }
    )

  # Conditional routing based on user permissions
  action :manage_advanced_settings,
    label: "Advanced Settings",
    resource_action: true,
    interaction: ManageAdvancedSettingsInteraction,
    route_options: Plutonium::Action::RouteOptions.new(
      url_resolver: ->(subject) {
        if current_user.admin?
          admin_settings_path(subject)
        else
          basic_settings_path(subject)
        end
      }
    )

  # External system integration with dynamic URLs
  action :sync_with_external,
    label: "Sync External",
    record_action: true,
    interaction: SyncExternalInteraction,
    route_options: Plutonium::Action::RouteOptions.new(
      url_resolver: ->(subject) {
        "https://api.external-system.com/sync/#{subject.external_id}"
      }
    )
end
```

The `url_resolver` lambda provides powerful flexibility:
- **Record Actions**: Receive the current record as `subject`
- **Resource Actions**: Receive the resource class as `subject`
- **Bulk Actions**: Receive the resource class with selected records available in params
- **Context Access**: Full access to controller context including `current_user`, helper methods, etc.

### Advanced Dynamic Routing Examples

```ruby
class ProjectDefinition < Plutonium::Resource::Definition
  # Multi-step workflow routing
  action :start_workflow,
    label: "Start Workflow",
    record_action: true,
    interaction: StartWorkflowInteraction,
    route_options: Plutonium::Action::RouteOptions.new(
      url_resolver: ->(subject) {
        case subject.status
        when 'draft'
          new_project_review_path(subject)
        when 'review'
          project_approval_path(subject)
        else
          project_path(subject)
        end
      }
    )

  # Dynamic nested resource creation
  action :add_team_member,
    label: "Add Team Member",
    record_action: true,
    interaction: AddTeamMemberInteraction,
    route_options: Plutonium::Action::RouteOptions.new(
      url_resolver: ->(subject) {
        if subject.team.full?
          project_team_waitlist_path(subject)
        else
          new_project_team_member_path(subject)
        end
      }
    )

  # Conditional external redirects
  action :open_in_ide,
    label: "Open in IDE",
    record_action: true,
    interaction: OpenInIDEInteraction,
    route_options: Plutonium::Action::RouteOptions.new(
      url_resolver: ->(subject) {
        if subject.repository_url.present?
          "vscode://vscode.git/clone?url=#{subject.repository_url}"
        else
          project_repository_setup_path(subject)
        end
      }
    )
end
```

### Custom Interaction with Dynamic Routing

```ruby
class CreateChildResourceInteraction < Plutonium::Interaction::Base
  attribute :parent_id, :integer
  attribute :resource_type, :string
  attribute :attributes, :hash

  validates :parent_id, :resource_type, presence: true

  private

  def execute
    parent = find_parent_resource
    child_class = resource_type.constantize
    child = child_class.new(attributes.merge(parent_key => parent))

    if child.save
      succeed(child)
        .with_message("#{resource_type} created successfully")
        .with_redirect_response(resource_url_for(child, parent: parent))
    else
      failed(child.errors)
    end
  end

  def find_parent_resource
    # Dynamic parent resolution based on context
    case resource_type
    when 'Deployment'
      Project.find(parent_id)
    when 'Task'
      Project.find(parent_id)
    else
      raise ArgumentError, "Unknown resource type: #{resource_type}"
    end
  end

  def parent_key
    case resource_type
    when 'Deployment', 'Task'
      :project_id
    else
      raise ArgumentError, "Unknown parent key for: #{resource_type}"
    end
  end
end

# Usage in resource definition
class ProjectDefinition < Plutonium::Resource::Definition
  action :create_deployment,
    label: "Create Deployment",
    record_action: true,
    interaction: CreateChildResourceInteraction,
    route_options: Plutonium::Action::RouteOptions.new(
      url_resolver: ->(subject) {
        # The subject here will be the Project record
        new_deployment_path(project_id: subject.id)
      }
    )
end
```

### Controller Integration

Controllers can call interactions directly, but this requires manual setup:

```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  # Manual controller action (requires custom routing)
  def bulk_publish
    outcome = BulkPublishPostsInteraction.call(
      view_context: view_context,
      post_ids: params[:post_ids],
      published_at: params[:published_at]
    )

    # Manual response handling
    if outcome.success?
      redirect_to posts_path, notice: outcome.messages.first&.first
    else
      redirect_back(fallback_location: posts_path, alert: "Failed to publish posts")
    end
  end
end
```

**Note**: For automatic integration without manual setup, define actions in resource definitions instead:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # This automatically handles routing, UI, and response processing
  action :bulk_publish, interaction: BulkPublishPostsInteraction
end
```

### Form Integration

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Form submission automatically uses interactions
  action :create, interaction: CreatePostInteraction
  action :update, interaction: UpdatePostInteraction
end
```

## Best Practices

### Interaction Design

1. **Single Responsibility**: Each interaction should handle one business operation
2. **Clear Naming**: Use descriptive names that indicate the business action
3. **Validation**: Validate inputs using ActiveModel validations
4. **Error Handling**: Return meaningful error messages
5. **Idempotency**: Design interactions to be safely re-runnable when possible

### Outcome Handling

1. **Consistent Responses**: Use appropriate response types for different scenarios
2. **Meaningful Messages**: Provide clear success/failure messages
3. **Proper Chaining**: Use `and_then` for sequential operations
4. **Error Propagation**: Let failures bubble up through chains

### Testing Strategy

1. **Unit Test Interactions**: Test business logic in isolation
2. **Mock External Services**: Use mocks for external dependencies
3. **Test Both Paths**: Cover both success and failure scenarios
4. **Integration Tests**: Test controller integration with system tests

### Performance Considerations

1. **Database Transactions**: Use transactions for multi-step operations
2. **Background Jobs**: Move slow operations to background jobs
3. **Caching**: Cache expensive computations when appropriate
4. **Batch Operations**: Use batch processing for bulk operations

## Advanced Features

### Custom Response Types

```ruby
class JsonResponse < Plutonium::Interaction::Response::Base
  def initialize(data, status: :ok)
    super()
    @data = data
    @status = status
  end

  private

  def execute(controller, &)
    controller.render json: @data, status: @status
  end
end

# Usage
succeed(user).with_response(JsonResponse.new(user.as_json))
```

### Conditional Execution

```ruby
class ConditionalInteraction < Plutonium::Interaction::Base
  attribute :condition, :boolean
  attribute :data, :hash

  private

  def execute
    return succeed(nil) unless condition

    # Only execute if condition is true
    result = expensive_operation(data)
    succeed(result)
  end
end
```

### Error Recovery

```ruby
class ResilientInteraction < Plutonium::Interaction::Base
  private

  def execute
    primary_service_call
      .or_else { fallback_service_call }
      .or_else { failed("All services unavailable") }
  end

  def primary_service_call
    # Try primary service
    result = PrimaryService.call(attributes)
    result.success? ? succeed(result.data) : failed(result.errors)
  rescue StandardError => e
    failed("Primary service error: #{e.message}")
  end

  def fallback_service_call
    # Try fallback service
    result = FallbackService.call(attributes)
    result.success? ? succeed(result.data) : failed(result.errors)
  rescue StandardError => e
    failed("Fallback service error: #{e.message}")
  end
end
```

## Related Modules

- **[Resource Record](./resource_record.md)** - Resource definitions and CRUD operations
- **[Definition](./definition.md)** - Resource definition DSL
- **[Core](./core.md)** - Base controller functionality
- **[Action](./action.md)** - Custom actions and operations
