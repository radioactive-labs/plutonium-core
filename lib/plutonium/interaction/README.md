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

Interactions allows us to leverage an architectural approach that focuses on organizing code around business actions or user interactions.
It builds upon the traditional MVC pattern by introducing additional layers that encapsulate business logic and improve separation of concerns.

### Key Benefits

- Clear separation of business logic from controllers
- Improved testability of business operations
- Consistent handling of success and failure cases
- Flexible and expressive way to chain operations
- Enhanced maintainability and readability of complex business processes
- Improved code organization and discoverability of business logic

## Key Concepts

### Interactions

Interactions are the core of this pattern. They represent specific use cases or business operations in your application. Each interaction is responsible for a single, well-defined task.
Interactions encapsulate the business logic, input validation, and outcome handling, providing a clean interface between the controller and the application's core functionality.

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
           failure(user.errors)
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

Or within another interaction:

```ruby
def execute
  MyInteraction.call(some_input: "value")
    .and_then { |result| do_something_with(result) }
    .with_response(Response::Redirect.new(some_path(final_result)))
    .with_message("Operation completed successfully")
end
```

## Best Practices

1. Keep interactions focused on a single responsibility
2. Use meaningful names for interactions that describe the action being performed
3. Leverage the `and_then` method for clean and expressive operation chaining
4. Prefer small, composable interactions over large, monolithic ones
5. Use `with_response` to explicitly set the desired response type
6. Keep the interaction's core logic separate from response handling

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

### Interactions with Nested Attributes

This example demonstrates how to handle nested attributes—specifically,
a `User` with multiple `Contact` and `UserAddress` records using
a Plutonium `Interaction`.

#### Key Highlights

The model definitions are included here for completeness, but the primary focus
remains on demonstrating how to build interactions that handle nested
attributes.

- Core user attributes (`first_name`, `last_name`, `email`) are declared and
  validated at the top level of the interaction.

- Nested associations (`contacts`, `addresses`) are managed via
  `accepts_nested_attributes_for`. The optional `reject_if` condition is used
  to discard entries that lack required fields—helping ensure data integrity at
  the input level.

- The `nested_input` DSL provides a declarative way to structure nested inputs,
  specifying accepted fields and mapping them to their respective definition
  classes (`ContactDefinition` and `UserAddressDefinition`).

- During execution, a `User` instance is initialized with both top-level and
  nested attributes, then persisted with all applicable validations.

**Note:** The `class_name` option is explicitly defined in the interaction's
`accepts_nested_attributes_for` macro because the `addresses` association does
not directly map to its underlying model name. Simply provide the class name,
for example, `class_name: "UserAddress"`, to ensure the correct model is used.

**This is essential only when the association name differs from the actual
class name.**

This approach enables seamless handling of complex nested input from forms or
API requests, while keeping validation logic clean, maintainable, and modular.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Plutonium::Resource::Record

  has_many :contacts
  has_many :addresses, class_name: "UserAddress"

  accepts_nested_attributes_for :contacts, :addresses
end

# app/models/contact.rb
class Contact < ApplicationRecord
  include Plutonium::Resource::Record

  belongs_to :user
  validates :label, :phone_number, presence: true
end

# app/models/user_address.rb
class UserAddress < ApplicationRecord
  include Plutonium::Resource::Record

  belongs_to :user
  validates :label, :map_url, presence: true
end

# app/interactions/users/interactions/create_user_interaction.rb
module Users
  module Interactions
    class CreateUserInteraction < Plutonium::Interaction::Base
      include Plutonium::Definition::Presentable

      presents label: "Add a new user", icon: Phlex::Tabler::UserPlus

      attribute :first_name, :string
      attribute :last_name, :string
      attribute :email, :string
      attribute :contacts
      attribute :addresses

      validates :first_name, :last_name, presence: true
      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

      accepts_nested_attributes_for :contacts,
        reject_if: proc { |attributes| attributes[:label].blank? }

      accepts_nested_attributes_for :addresses, class_name: "UserAddress",
        reject_if: proc { |attributes| attributes[:label].blank? }

      nested_input :contacts,
        using: ContactDefinition,
        fields: %i[label phone_number],
        description: "Add one or more contacts for this user."

      nested_input :addresses,
        using: UserAddressDefinition,
        fields: %i[label map_url],
        description: "Add one or more addresses for this user."

      private

      def execute
        user = User.new(self.attributes)

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
      user ? success(user) : failure(["User not found"])
    end

    def find_products(user, product_ids)
      products = Product.where(id: product_ids.split(','))
      products.empty? ? failure(["No valid products found"]) : success([user, products])
    end

    def create_order(user, products)
      order = Order.create(user: user, products: products)
      order.persisted? ? success(order) : failure(order.errors.full_messages)
    end
  end
end
```

This example demonstrates how to chain multiple operations, handle potential failures at each step, and return an appropriate outcome with a specific response type. Note how the `with_response` and `with_message` methods are used to set the response and add a message to the outcome.

By following these guidelines and examples, you can effectively implement and use the Interaction pattern in your Rails applications, leading to more maintainable and testable code.

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
