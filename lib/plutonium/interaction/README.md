# Interactions

## Table of Contents

1. [Introduction](#introduction)
2. [Key Concepts](#key-concepts)
3. [Core Components](#core-components)
4. [Setup](#setup)
5. [Usage](#usage)
6. [Best Practices](#best-practices)
7. [Testing](#testing)
8. [Advanced Features](#advanced-features)
9. [Examples](#examples)

## Introduction

Interactions organize code around the actions a user can take. Each one is the entry point from a page into a single, well-defined operation: it declares the inputs, renders as a button and a form, is gated by a policy, and hands back an outcome the controller turns into a message and a redirect.

### Key Benefits

- A uniform surface for custom operations: button, form, authorization, messaging, redirect
- Clear separation of the *request* from the controller
- Consistent handling of success and failure cases
- Input validation that renders as form errors
- Improved discoverability — every custom operation is a named class in `app/interactions/`

## Key Concepts

### Interactions

An interaction is a **presentation object**. It owns the button, the form, the input-shape validation, and the user-facing outcome.

It is *not* where a domain operation should end up living. An interaction cannot be constructed without a `view_context:`, so anything reachable only through one is reachable only from a page. Logic may **start** in `execute` — a one-off with a single caller is fine there, and pre-extracting is YAGNI. The trigger to extract is the **second caller**: a background job, an API controller, a rake task, the console, or another interaction. At that point the behaviour moves onto the **model** (fat models, per Rails convention — not a new service layer), and the interaction shrinks to a call to a well-named method.

`view_context` is the tell: if a caller would need one purely to reach some behaviour, that behaviour is on the wrong side of the boundary.

Validations split along the same line. **Interaction validations check input shape** — is it present, does it parse, is it the right type — and exist to render form errors. **Model validations are business invariants** and must hold regardless of who is calling.

Full explanation: [Reference › Behavior › Interactions](https://radioactive-labs.github.io/plutonium-core/reference/behavior/interactions).

### Outcomes

Outcomes encapsulate the result of an interaction, providing a consistent interface for handling both success and failure scenarios. Outcomes can have an associated response, which can be set explicitly using the `with_response` method. The value of the outcome is separate from its response, allowing for more flexible handling of interaction results.
<!-- ### Workflows

Workflows allow you to compose multiple interactions into a larger, more complex business process while maintaining separation of concerns. -->
## Core Components

### Plutonium::Interaction::Base

The foundation for all interactions. It integrates with ActiveModel for attribute definition and validations.

```ruby
class MyInteraction < Plutonium::Interaction::Base
  attribute :some_input, :string
  validates :some_input, presence: true

  private

  def execute
    # Implementation
  end
end
```

### Plutonium::Interaction::Outcome

Encapsulates the result of an interaction. It has two subclasses:

- `Success`: Represents a successful operation
- `Failure`: Represents a failed operation

### Plutonium::Interaction::Response

Represents controller operations that can be performed as a result of a successful interaction.
We ship with these out of the box:

- `Plutonium::Interaction::Response::Redirect`
- `Plutonium::Interaction::Response::Render`
- `Plutonium::Interaction::Response::Null`

## Usage

### Creating an Interaction

1. Create a new file in `app/interactions/`, e.g., `app/interactions/users/create_user.rb`:

   ```ruby
   module Users
     class CreateUser < Plutonium::Interaction::Base
       attribute :first_name, :string
       attribute :last_name, :string
       attribute :email, :string

       validates :first_name, :last_name, presence: true
       validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

       private

       def execute
         user = User.new(attributes)
         if user.save
           success(user)
             .with_response(Response::Redirect.new(user_path(user)))
             .with_message("User was successfully created.")
         else
           failed(user.errors)
         end
       end
     end
   end
   ```

### Using an Interaction in a Controller

```ruby
class UsersController < ApplicationController
  def create
    process_outcome(Users::CreateUser.call(user_params))
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email)
  end
end
```

### Processing Outcomes

In your `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  private

  def process_outcome(outcome)
    if outcome.success?
      outcome.to_response.process(self) do |value|
        # Default response.
        # Executed if the interaction does not produce a specific Response.
        render json: value
      end
    else
      outcome.messages.each { |msg, type| flash.now[type] = msg }
      render json: { errors: outcome.errors }, status: :unprocessable_content
    end
  end
end
```

### Executing an Interaction

Interactions can be executed using the call class method:

```ruby
outcome = MyInteraction.call(some_input: "value")

if outcome.success?
  # Handle success case
else
  # Handle failure case
end
```

### Composing outcomes — `and_then`

`and_then` composes `Outcome`s. On a `Success` it yields **the value** (not the outcome) and returns whatever the block returns; on a `Failure` it short-circuits, returning the failure untouched. It's useful for expressing a guard as an outcome inside one `execute`:

```ruby
def execute
  unlocked_resource.and_then do |post|
    post.publish!
    succeed(post).with_message("Published")
  end
end

private

def unlocked_resource
  resource.locked? ? failed("This post is locked") : succeed(resource)
end
```

> **Don't use `and_then` to sequence business operations.** A chain of three interactions is a chain of three things that each demand a `view_context` — none of which a job or an API controller can supply. That's one model method wearing three costumes; see [Best Practices](#best-practices) below.

## Best Practices

1. Keep interactions focused on a single responsibility
2. Use meaningful names for interactions that describe the action being performed
3. **Put the operation on the model as soon as a second caller needs it.** Logic may start in `execute`; a job, API controller, rake task, or console session wanting the same behaviour is the trigger to extract. Name the model method in domain language (`publish!`, `archive!`, `register!`), not persistence terms (`update_published_at`)
4. **Interaction validations check input shape; model validations enforce invariants.** The interaction's exist to render form errors — they don't run for any other caller
5. Use `with_response` to explicitly set the desired response type
6. Keep the interaction's core logic separate from response handling

### The chaining anti-pattern

```ruby
# 🚫 Each link demands a view_context that has nothing to do with the work
CreateUserInteraction.call(view_context:, **user_params)
  .and_then { |user| SendWelcomeEmail.call(view_context:, user:) }
  .and_then { |user| LogActivity.call(view_context:, user:) }
```

Sending a welcome email and writing an audit row are exactly what a signup API endpoint or a seeds script also has to do — and neither has a view context. Give the model the operation instead:

```ruby
# ✅
def execute
  user = User.register!(**attributes)   # welcome email + audit row live in here
  succeed(user).with_message("Welcome aboard!")
end
```

## Testing

Interactions are easy to test in isolation. Here's an example using RSpec:

```ruby
RSpec.describe Users::CreateUser do
  let(:valid_attributes) { { first_name: "John", last_name: "Doe", email: "john@example.com" } }

  it "creates a user successfully" do
    outcome = described_class.call(valid_attributes)

    expect(outcome).to be_success
    expect(outcome.value).to be_a(User)
    expect(outcome.to_response).to be_a(Response::Redirect)
    expect(User.last.email).to eq("john@example.com")
  end

  it "fails with invalid attributes" do
    outcome = described_class.call(first_name: "", last_name: "Doe", email: "invalid")

    expect(outcome).to be_failure
    expect(outcome.errors).to include("First name can't be blank")
    expect(outcome.errors).to include("Email is invalid")
  end
end
```

## Advanced Features

<!--
### Workflows

Workflows allow you to compose multiple interactions into a larger business process:

```ruby
module Orders
  class PlaceOrder < Plutonium::Interaction::Base
    presents label: "Place Order",
             icon: "shopping-cart",
             description: "Process a new order"

    attribute :user_id, :integer
    attribute :product_ids, :string
    attribute :payment_method, :string

    validates :user_id, :product_ids, :payment_method, presence: true

    workflow do
      step :validate_products, ValidateProducts
      step :check_inventory, CheckInventory
      step :process_payment, ProcessPayment, if: ->(ctx) { ctx[:total_price] > 0 }
      step :create_order, CreateOrder
      step :send_confirmation, SendOrderConfirmation
    end

    private

    def execute
      execute_workflow(attributes.to_h)
        .map { |ctx| Response::Redirect.new(order_path(ctx[:order])) }
        .with_message("Order placed successfully.")
    end
  end
end
```
-->

### Presentable Concern

The `Presentable` concern allows you to add metadata to your interactions, which can be used for generating UI components or documentation:

```ruby
class MyInteraction < Plutonium::Interaction::Base
  include Plutonium::Definition::Presentable

  presents label: "My Interaction",
           icon: Phlex::TablerIcons::Activate,
           description: "Does something awesome"

  # ... rest of the interaction
end
```

### Interactions with Structured Input

> **Note:** `nested_input` and `accepts_nested_attributes_for` are **not**
> available on interactions. They are resource-only features that work with
> model-backed `has_many`/`has_one` associations. For collecting structured or
> repeating input inside an interaction, use `structured_input` instead.

`structured_input` declares an attribute on the interaction and renders an
inline fieldset in the auto-generated form. It comes in two forms:

- **Single** — the attribute arrives in `execute` as a plain `Hash`.
- **Repeat** — the attribute arrives as an `Array` of hashes (capped at the
  given number of rows; `repeat: true` defaults to 10).

```ruby
# app/interactions/users/interactions/create_user_interaction.rb
module Users
  module Interactions
    class CreateUserInteraction < Plutonium::Interaction::Base
      include Plutonium::Definition::Presentable

      presents label: "Add a new user", icon: Phlex::Tabler::UserPlus

      attribute :first_name, :string
      attribute :last_name, :string
      attribute :email, :string

      validates :first_name, :last_name, presence: true
      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

      # single → a hash
      structured_input :address do |f|
        f.input :street
        f.input :city
      end

      # repeater → an array of hashes (max 5 rows)
      structured_input :contacts, repeat: 5 do |f|
        f.input :label
        f.input :phone_number
      end

      private

      def execute
        # address  => { "street" => "...", "city" => "..." }
        # contacts => [ { "label" => "...", "phone_number" => "..." }, ... ]
        user = User.new(first_name: first_name, last_name: last_name, email: email)

        if user.save
          success(user).with_message("User created successfully")
        else
          failed(user.errors)
        end
      end
    end
  end
end
```

## Examples

### Chaining Operations

```ruby
module Orders
  class PlaceOrder < Plutonium::Interaction::Base
    attribute :user_id, :integer
    attribute :product_ids, :string

    private

    def execute
      success(attributes)
        .and_then { |attrs| find_user(attrs[:user_id]) }
        .and_then { |user| find_products(user, attributes[:product_ids]) }
        .and_then { |user, products| create_order(user, products) }
        .with_response(Response::Redirect.new(order_path(order)))
        .with_message("Order placed successfully.")
    end

    def find_user(user_id)
      user = User.find_by(id: user_id)
      user ? success(user) : failed(["User not found"])
    end

    def find_products(user, product_ids)
      products = Product.where(id: product_ids.split(','))
      products.empty? ? failed(["No valid products found"]) : success([user, products])
    end

    def create_order(user, products)
      # Order.place! owns the domain work — inventory, totals, confirmation mail.
      # The interaction only resolves the inputs and shapes the outcome.
      success(Order.place!(user: user, products: products))
    rescue ActiveRecord::RecordInvalid => e
      failed(e.record.errors)
    end
  end
end
```

Every link here is a **private method of this one interaction** resolving an input, not a separate interaction — so nothing in the chain needs a `view_context` of its own, and `Order.place!` stays callable from a job or an API. That's the shape `and_then` is for: composing outcomes inside a single `execute`, not sequencing business operations across interactions.

Note also how `with_response` and `with_message` set the response and attach a message to the outcome.

<!--

This example demonstrates how to chain multiple operations, handle potential failures at each step, and return an appropriate outcome.

By following these guidelines and examples, you can effectively implement and use the Use Case Driven Design pattern in your Rails applications, leading to more maintainable and testable code.

### Example interaction with workflow

```ruby
module Orders
  class PlaceOrder < Plutonium::Interaction::Base
    presents label: "Place Order",
             icon: "shopping-cart",
             description: "Process a new order",
             category: "Order Management"

    attribute :user_id, :integer
    attribute :product_ids, :string
    attribute :payment_method, :string

    validates :user_id, :product_ids, :payment_method, presence: true

    workflow do
      step :validate_products, use_case: ValidateProducts
      step :check_inventory, use_case: CheckInventory
      step :process_payment, use_case: ProcessPayment, if: ->(ctx) { ctx[:total_price] > 0 }
      step :create_order, use_case: CreateOrder
      step :send_confirmation, use_case: SendOrderConfirmation
    end

    private

    def execute
      execute_workflow(attributes.to_h)
        .map { |ctx| Actions::RedirectAction.new(:order_path, id: ctx[:order].id) }
        .with_message("Order placed successfully.")
    end
  end

  class ValidateProducts < Plutonium::Interaction::Base
    # Implementation...
  end

  class CheckInventory < Plutonium::Interaction::Base
    # Implementation...
  end

  class ProcessPayment < Plutonium::Interaction::Base
    # Implementation...
  end

  class CreateOrder < Plutonium::Interaction::Base
    # Implementation...
  end

  class SendOrderConfirmation < Plutonium::Interaction::Base
    # Implementation...
  end
end
```

  class Sample < Phlex::HTML
    def view_template
      p { "my custom template" }
    end
  end

  class Rename < ResourceInteraction
    attribute :resource

    attribute :name
    validates :name, presence: true

    # input :name, as: :file
    turbo false

    presents label: "Rename resource",
      icon: Phlex::TablerIcons::Pencil,
      description: "Some cool stuff"

    private

    def execute
      resource.name = name
      if resource.save
        succeed.with_message("Action completed").with_render_response(Sample.new)
      else
        failed resource.errors
      end
    end
  end
  # action :rename, interaction: Rename
-->
