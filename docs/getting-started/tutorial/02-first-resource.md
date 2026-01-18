# Chapter 2: Creating Your First Resource

In this chapter, you'll create the Post resource - the core of our blog application.

## What is a Resource?

In Plutonium, a **resource** is a complete unit consisting of:
- **Model** - The data structure (ActiveRecord)
- **Definition** - How the resource renders (fields, actions, UI)
- **Policy** - Who can do what (authorization)
- **Controller** - HTTP handling (auto-generated or custom)

## Generating a Feature Package

First, let's create a feature package to hold our blogging logic:

```bash
rails generate pu:pkg:package blogging
```

This creates:

```
packages/blogging/
├── app/
│   ├── controllers/blogging/
│   ├── definitions/blogging/
│   ├── interactions/blogging/
│   ├── models/blogging/
│   ├── policies/blogging/
│   └── views/blogging/
└── lib/
    └── engine.rb
```

## Generating the Post Resource

Now generate the Post resource inside the blogging package:

```bash
rails generate pu:res:scaffold Post title:string body:text 'published:boolean?' --dest=blogging
```

This creates:

### Model (`packages/blogging/app/models/blogging/post.rb`)

```ruby
class Blogging::Post < Blogging::ResourceRecord
  # Add validations, associations, and business logic here
end
```

### Definition (`packages/blogging/app/definitions/blogging/post_definition.rb`)

```ruby
class Blogging::PostDefinition < Blogging::ResourceDefinition
  # Customize field rendering, forms, and UI here
end
```

### Policy (`packages/blogging/app/policies/blogging/post_policy.rb`)

```ruby
class Blogging::PostPolicy < Blogging::ResourcePolicy
  def create?
    true
  end

  def read?
    true
  end

  def permitted_attributes_for_create
    [:title, :body, :published]
  end

  def permitted_attributes_for_read
    [:title, :body, :published]
  end

  def permitted_associations
    %i[]
  end
end
```

### Migration

```ruby
class CreateBloggingPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :blogging_posts do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.boolean :published

      t.timestamps
    end
  end
end
```

## Running the Migration

```bash
rails db:migrate
```

## Creating a Portal

Resources need a portal to be accessible via the web. Let's create an admin portal:

```bash
rails generate pu:pkg:portal admin
```

This creates the AdminPortal package with authentication configured.

## Connecting the Resource

Connect the Post resource to the admin portal:

```bash
rails generate pu:res:conn Blogging::Post --dest=admin_portal
```

This:
1. Adds routes for Post in the admin portal
2. Creates a portal-specific controller
3. Registers the resource with the portal

## Starting the Server

```bash
bin/dev
```

Visit `http://localhost:3000/admin/blogging/posts`. You should see:
- An empty posts table
- A "New Post" button
- Search and filter options

Try creating a post. The form is automatically generated from your model's attributes.

## Understanding Auto-Detection

Notice that we wrote almost no configuration code. Plutonium auto-detected:

- **Fields** from the model's columns
- **Validations** from the model's validators
- **Associations** from belongs_to/has_many
- **Form inputs** based on column types
- **Table columns** from the policy's permitted attributes

This is Plutonium's core philosophy: **convention over configuration**. You only write code when you need to change the defaults.

## Customizing Table Columns

By default, Plutonium shows all permitted attributes in the table. To customize which columns appear, use the policy's `permitted_attributes_for_index` method:

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
module Blogging
  class PostPolicy < Blogging::ResourcePolicy
    # Control which columns appear in the index table
    def permitted_attributes_for_index
      [:title, :published, :created_at]
    end
  end
end
```

Refresh the page. The table now shows only the columns you specified.

## What's Next

Our resource is working, but anyone can access it. In the next chapter, we'll add authentication with Rodauth.

[Continue to Chapter 3: Setting Up Authentication →](./03-authentication)
