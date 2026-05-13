# Interaction

Encapsulate business logic into testable, reusable units. Registered as [actions](/reference/resource/actions) in definitions and executed by the controller. Built on ActiveModel attributes + validations.

## 🚨 Critical

- **`ActiveRecord::RecordInvalid` is NOT rescued automatically.** Always rescue when using `create!` / `update!` / `save!`, return `failed(e.record.errors)`.
- **Return `succeed(...)` or `failed(...)` from `execute`** — the controller can't tell what happened otherwise. Returning anything else raises.
- **Redirect is automatic on success** — only use `with_redirect_response` for a *different* destination.
- **Bulk actions use `attribute :resources` (plural).** Policy authorization is checked per record — if any fails, the whole request fails.
- **The shape of the action (record / bulk / resource) is inferred from the interaction's attributes.** See [Resource › Actions](/reference/resource/actions#inferred-visibility-interactive-actions).

## Structure

```ruby
# app/interactions/resource_interaction.rb — installed once
class ResourceInteraction < Plutonium::Resource::Interaction
end

# A real interaction
class PublishPostInteraction < ResourceInteraction
  presents label: "Publish",
           icon: Phlex::TablerIcons::Send,
           description: "Make this post public"

  attribute :resource
  attribute :publish_date, :datetime, default: -> { Time.current }

  input :publish_date

  validates :publish_date, presence: true

  private

  def execute
    resource.update!(published_at: publish_date)
    succeed(resource).with_message("Post published!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

## Attributes

ActiveModel-style:

```ruby
attribute :resource                                  # single record (record action)
attribute :resources                                 # array of records (bulk action)
attribute :email, :string
attribute :count, :integer, default: 1
attribute :active, :boolean, default: -> { true }    # callable default
attribute :tags, :array
attribute :metadata, :hash
attribute :date, :datetime
```

The presence of `:resource` / `:resources` / neither determines the action type — see [Resource › Actions › Inferred visibility](/reference/resource/actions#inferred-visibility-interactive-actions).

## Inputs

Same DSL as definition `input`. Auto-detection from the attribute type applies — declare `as:` only when overriding.

```ruby
input :email                          # auto: :email type from name match
input :role, as: :select, choices: %w[admin user]
input :content, as: :text
```

See [Resource › Definition](/reference/resource/definition#available-field-types) for all `as:` types, options, and dynamic blocks.

## Presentation

```ruby
presents label: "Archive Record",
         icon:  Phlex::TablerIcons::Archive,
         description: "Move to archive"
```

Access:

```ruby
MyInteraction.label        # => "Archive Record"
MyInteraction.icon         # => Phlex::TablerIcons::Archive
MyInteraction.description  # => "Move to archive"
```

If `action :foo, interaction: FooInteraction` doesn't override `label:` / `icon:` etc., these `presents` values are used.

## `execute` — outcomes

`execute` MUST return a `succeed(...)` or `failed(...)` outcome. Validations run automatically before `execute`; if they fail, the interaction short-circuits to `failed()`.

### Success

```ruby
succeed(resource)                                       # auto-redirect to resource
succeed(resource).with_message("Done!")
succeed(resource).with_message("Heads up!", :alert)
succeed(resource).with_redirect_response(custom_path)   # different destination
succeed(resource).with_file_response(path, filename: "report.pdf")
succeed(resource).with_render_response(:custom_template)
```

### Failure

```ruby
failed("Something went wrong")
failed(resource.errors)
failed(email: "is invalid", name: "is required")  # hash form
failed("Invalid value", :email)                   # string + attribute
```

### Manual error addition

```ruby
def execute
  errors.add(:base, "Post must have content")
  return failure if errors.any?

  # …continue
end
```

### Chaining

`and_then` chains interactions. On failure, the chain short-circuits and returns the failure immediately.

```ruby
def execute
  CreateUserInteraction.call(view_context:, **user_params)
    .and_then { |r| SendWelcomeEmail.call(view_context:, user: r.value) }
    .and_then { |r| LogActivity.call(view_context:, user: r.value) }
    .with_message("User created and welcomed!")
end
```

## Validations

Standard ActiveModel. Run automatically before `execute`:

```ruby
validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
validates :role, inclusion: {in: %w[admin user guest]}

validate :custom_check

private

def custom_check
  errors.add(:resource, "cannot be modified when archived") if resource.archived?
end
```

## Accessing context

`current_user` is provided by the base class (`view_context.controller.helpers.current_user`):

```ruby
def execute
  resource.update!(updated_by: current_user)
  succeed(resource)
end
```

## Interaction types

| Attribute pattern | Action type | Where it shows up |
|---|---|---|
| `attribute :resource` | Record action | Show page + per-row in table |
| `attribute :resources` (plural) | Bulk action | Bulk toolbar above table |
| neither | Resource action | Index page header |

### Record action

```ruby
class ArchiveInteraction < Plutonium::Resource::Interaction
  attribute :resource

  def execute
    resource.update!(archived: true)
    succeed(resource).with_message("Archived")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

### Bulk action

```ruby
class BulkArchiveInteraction < Plutonium::Resource::Interaction
  attribute :resources

  def execute
    resources.update_all(archived: true)
    succeed(resources).with_message("Archived #{resources.size} records")
  end
end
```

Per-record authorization details in [Resource › Actions › Bulk action](/reference/resource/actions#bulk-action).

### Resource action (no record)

```ruby
class ImportInteraction < Plutonium::Resource::Interaction
  attribute :file
  input :file, as: :file
  validates :file, presence: true

  def execute
    # …import logic
    succeed(nil).with_message("Import completed.")
  end
end
```

## Calling interactions directly

The controller handles this for interactive actions. But you can call them manually too — useful in tests, jobs, and rake tasks.

### Class method

```ruby
outcome = PublishPost.call(view_context: view_context, resource: post)

if outcome.success?
  # …
else
  # …
end
```

### Instance method

```ruby
interaction = PublishPost.new(view_context: view_context, resource: post)
outcome = interaction.call
```

The `view_context:` argument is required — interactions use it to access controller helpers and the current user.

## Immediate vs form

| Interaction shape | Behavior |
|---|---|
| Only `:resource` / `:resources` (no extra `attribute` or `input`) | **Immediate** — browser confirmation (`"#{label}?"`, e.g. `"Archive?"`), then runs. Override with `confirmation: "Custom"` or `confirmation: false` on the action. |
| Additional `attribute` / `input` declared | **Form** — renders modal form first; no auto-confirmation. |

See [Resource › Actions › Immediate vs form](/reference/resource/actions#immediate-vs-form).

## Generating interaction URLs

`resource_url_for` with the `interaction:` kwarg. The action type (record / bulk / resource) is inferred from the element and the presence of `ids:`:

```ruby
# Record action — instance argument
resource_url_for(@post, interaction: :publish)
# => /posts/:id/record_actions/publish

# Resource action — class, no ids
resource_url_for(Post, interaction: :import)
# => /posts/resource_actions/import

# Bulk action — class + ids
resource_url_for(Post, interaction: :archive, ids: [1, 2, 3])
# => /posts/bulk_actions/archive?ids[]=1&ids[]=2&ids[]=3

# Composes with parent / entity scoping
resource_url_for(@post, parent: @user, interaction: :publish)
```

The same URL serves GET (form/confirmation) and POST (commit) — the HTTP verb routes to the right controller action. Passing both `interaction:` and `action:` raises `ArgumentError`.

## Complete example

```ruby
class Company::InviteUserInteraction < Plutonium::Resource::Interaction
  presents label: "Invite User",
           icon:  Phlex::TablerIcons::UserPlus

  attribute :resource         # the company
  attribute :email, :string
  attribute :role, :string

  input :email
  input :role, as: :select, choices: -> { UserInvite.roles.keys }

  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :role,  presence: true, inclusion: {in: UserInvite.roles.keys}
  validate :not_already_invited

  private

  def execute
    invite = UserInvite.create!(
      company: resource, email: email, role: role,
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

## Testing

```ruby
RSpec.describe PublishPost do
  let(:view_context) { double("view_context", controller: double(helpers: double(current_user: user))) }
  let(:user) { create(:user) }
  let(:post) { create(:post, user: user, published: false) }

  it "publishes the post" do
    outcome = described_class.call(view_context: view_context, resource: post)

    expect(outcome).to be_success
    expect(post.reload).to be_published
  end
end
```

See [Testing](/reference/testing/) for Plutonium's built-in testing helpers — `ResourceInteraction` concern wraps these patterns.

## Related

- [Resource › Actions](/reference/resource/actions) — registering interactions, inferred visibility, immediate vs form
- [Policies](./policies) — `def <action>?` authorization methods
- [Controllers](./controllers) — `resource_url_for(..., interaction: …)` URL generation
- [UI › Forms](/reference/ui/forms) — customizing the modal form rendered for actions with inputs
