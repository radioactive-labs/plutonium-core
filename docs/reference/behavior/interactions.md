# Interaction

The entry point from a Plutonium page into an operation. An interaction declares the inputs, renders as a button and a form, is gated by a policy, and returns an outcome the controller turns into a flash message and a redirect. Built on ActiveModel attributes + validations.

## 🚨 Critical

- **`ActiveRecord::RecordInvalid` is NOT rescued automatically.** Always rescue when using `create!` / `update!` / `save!`, return `failed(e.record.errors)`.
- **Return `succeed(...)` or `failed(...)` from `execute`** — the controller can't tell what happened otherwise. Returning anything else raises.
- **Redirect is automatic on success** — only use `with_redirect_response` for a *different* destination.
- **Bulk actions use `attribute :resources` (plural).** Policy authorization is checked per record — if any fails, the whole request fails.
- **The shape of the action (record / bulk / resource) is inferred from the interaction's attributes.** See [Resource › Actions](/reference/resource/actions#inferred-visibility-interactive-actions).
- **An interaction is a presentation object.** Logic may *start* in `execute`; the **second caller** — a job, an API controller, a rake task, the console — is the signal to move it to the model. See [below](#what-an-interaction-is-for).

## What an interaction is for {#what-an-interaction-is-for}

An interaction is a **presentation object**. It exists so Plutonium can render a button, check a policy, bind a form, and turn the result into a message and a redirect. That is the whole job:

| An interaction owns | An interaction does not own |
|---|---|
| The button — `presents label:` / `icon:` | *Who* may click it. That's the [policy](./policies). |
| The form — `attribute` + `input` declarations | — |
| **Input shape** validation: present? parses? right type? | **Business invariants** — they must hold for every caller, so they belong on the model |
| The user-facing outcome — `succeed` / `failed`, messages, redirect | The domain operation itself, once more than one caller needs it |

### Logic may start in `execute`

A one-off operation with exactly one caller is perfectly fine written inline. Don't pre-extract a service object for a two-line `update!` — that's YAGNI, and Plutonium deliberately ships no service layer to put it in. The rule below is a **refactoring trigger**, not a prohibition.

### The second caller is the trigger to extract

The moment a background job, an API controller, a rake task, the console, or another interaction needs the same behaviour, move it to the model.

The deadline is *the second caller* — and not "as soon as it looks like business logic" — because of one line in the base class:

```ruby
def initialize(view_context:, **attributes)
```

`view_context:` is required. So a caller that isn't a Plutonium page has exactly two options: duplicate the logic, or manufacture a `view_context` it has no business owning. **`view_context` is the tell.** If reaching some behaviour would force a caller to conjure one, that behaviour is on the wrong side of the boundary.

### The destination is the model

Rails convention: fat models. Give the operation a name in domain language and hang it off the record.

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  def publish!(on: Time.current)
    update!(published: true, published_at: on)
  end
end
```

```ruby
# the interaction presents it
def execute
  resource.publish!(on: publish_date)
  succeed(resource).with_message("Post published!")
rescue ActiveRecord::RecordInvalid => e
  failed(e.record.errors)
end
```

Name it for the domain (`publish!`, `archive!`, `register!`), not for the persistence (`update_published_at`) — the point is that a scheduler job can now call `post.publish!` and read as if it meant it. And resist inventing a `PublishPostService`: the model is the destination, not a new layer.

### Worked counter-example — chained interactions

```ruby
# 🚫 Every link demands a view_context that has nothing to do with the work
CreateUserInteraction.call(view_context:, **user_params)
  .and_then { |user| SendWelcomeEmail.call(view_context:, user:) }
  .and_then { |user| LogActivity.call(view_context:, user:) }
```

Sending a welcome email and writing an audit row are precisely what a signup API endpoint, a seeds script, or a console session also has to do — none of which has a `view_context`. Modelled as interactions, they are unreachable from anywhere but a Plutonium page.

```ruby
# ✅ The model owns registering a user; the interaction presents it
def execute
  user = User.register!(**attributes)   # welcome email + audit row live in here
  succeed(user).with_message("Welcome aboard!")
end
```

Chaining three interactions is usually the signal that you have one model method wearing three presentation costumes. `and_then` is real API and stays [documented below](#chaining) — just don't reach for it to sequence business operations.

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
    resource.publish!(on: publish_date)   # Post#publish! — see above
    succeed(resource).with_message("Post published!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

Note the division: the interaction declares the input, validates that a date was supplied, and phrases the flash. `Post#publish!` decides what publishing a post *means* — so the scheduled-publishing job can call it too.

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

### Chaining {#chaining}

`and_then` composes `Outcome`s. On a `Success` it yields **the value** (not the outcome) and returns whatever the block returns; on a `Failure` it short-circuits, returning the failure untouched.

```ruby
def execute
  unlocked_resource.and_then do |post|
    post.publish!(on: publish_date)
    succeed(post).with_message("Post published!")
  end
end

private

# a guard expressed as an Outcome, so the failure carries its own message
def unlocked_resource
  resource.locked? ? failed("This post is locked") : succeed(resource)
end
```

::: warning Don't use `and_then` to sequence business operations
A chain of three interactions is a chain of three things that each demand a `view_context`, none of which a job or an API controller can supply. That's one model method wearing three costumes — see [Worked counter-example](#what-an-interaction-is-for). `and_then` earns its keep composing outcomes *within* one interaction, or in a test.
:::

## Validations

Standard ActiveModel. Run automatically before `execute`; if they fail, `execute` never runs.

```ruby
validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
validates :role, inclusion: {in: %w[admin user guest]}

validate :custom_check

private

def custom_check
  errors.add(:resource, "cannot be modified when archived") if resource.archived?
end
```

### Which validation goes where

Interactions have validations and so do models, and they are not competing — they answer different questions:

| | Interaction validation | Model validation |
|---|---|---|
| Asks | "Can I read this input?" — present, parses, right type, plausible format | "Is this record legal?" — invariants that hold no matter who is calling |
| Exists to | render a form error next to the field | protect the data from every caller, including the ones with no form |
| Runs | before `execute`, without ever touching the model | inside `save!` / `update!` — i.e. inside your model method |

Both surface to the user, but **not identically**, and the difference should inform where you put a rule:

- An **interaction** validation attaches to a declared attribute. The re-rendered modal shows it inline against that input, and again in the summary at the top of the form.
- `failed(record.errors)` flattens `ActiveModel::Errors` into **full messages on `:base`** (`Array(errors)` calls `errors.to_a`, which is `full_messages`). Those land in the form's error summary only — never against a field — and they're phrased with the *model's* attribute names, which need not match your inputs.

So it is fine, and often right, to *duplicate* a cheap invariant as an interaction validation purely for the better error placement, while the model keeps the authoritative copy. What must not happen is the model-side copy going missing: the moment a job calls `post.publish!`, the interaction's validations are not in the picture at all.

## Accessing context

`current_user` is provided by the base class (`view_context.controller.helpers.current_user`):

```ruby
def execute
  resource.update!(updated_by: current_user)
  succeed(resource)
end
```

This one is *correctly* inline. "Who clicked the button" is context the presentation layer holds and nothing else does — `current_user` is read straight off the `view_context`. A job has no answer for it, so there is no second caller to extract for.

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
    resource.archive!
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

`update_all` stays inline on purpose: it's a single-statement SQL update whose *whole point* is skipping per-record model machinery. If archiving means more than setting a column — callbacks, an audit row, a webhook — this is the wrong shape; call `resources.each(&:archive!)` and let the model own it.

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

The controller handles this for interactive actions. You can also call one by hand — chiefly in **tests**, where you're exercising the interaction itself.

::: tip Needing this in a job or a rake task is the signal to refactor
Both entry points require `view_context:`, and a job doesn't have one. If you find yourself reaching for a stub to satisfy it, you don't want the interaction — you want the model method it wraps. See [What an interaction is for](#what-an-interaction-is-for).
:::

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

The `view_context:` argument is required — interactions use it to access controller helpers and the current user. It is also the boundary marker: everything reachable *only* through an interaction is reachable only from a page.

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

Inviting a user is a textbook second-caller case — a seats-provisioning job, an admin rake task and a signup API all need to send the same invitation. So the operation lives on `Company`, and the interaction is the button in front of it.

```ruby
# app/models/company.rb
class Company < ApplicationRecord
  has_many :user_invites

  # Everything inviting means: the row, the mail, the audit trail.
  def invite!(email:, role:, by:)
    user_invites.create!(email: email, role: role, invited_by: by).tap do |invite|
      UserInviteMailer.invitation(invite).deliver_later
    end
  end

  def pending_invite_for?(email) = user_invites.exists?(email: email, state: :pending)
end
```

```ruby
# app/interactions/company/invite_user_interaction.rb
class Company::InviteUserInteraction < Plutonium::Resource::Interaction
  presents label: "Invite User",
           icon:  Phlex::TablerIcons::UserPlus

  attribute :resource         # the company
  attribute :email, :string
  attribute :role, :string

  input :email
  input :role, as: :select, choices: -> { UserInvite.roles.keys }

  # Input shape — is this a readable email, is this a role that exists?
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :role,  presence: true, inclusion: {in: UserInvite.roles.keys}
  validate  :not_already_invited

  private

  def execute
    resource.invite!(email: email, role: role, by: current_user)
    succeed(resource).with_message("Invitation sent to #{email}")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end

  # Deliberately duplicated. `UserInvite` enforces uniqueness for real (a job
  # calling `company.invite!` must hit it too); this copy exists only so the
  # message lands on the :email field instead of in the base error summary.
  def not_already_invited
    return if email.blank?
    errors.add(:email, "already has a pending invitation") if resource.pending_invite_for?(email)
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
