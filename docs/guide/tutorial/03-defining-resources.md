# 3. Defining Resources

With our `Blogging` package ready, we can now define the core **Resources** of our feature: `Post` and `Comment`. But first, we need a way to represent users, since posts and comments will belong to a user.

## Setting Up Users and Authentication

Plutonium provides generators to quickly set up user authentication using the popular [Rodauth](https://rodauth.jeremyevans.net/) library.

Run the following commands in your terminal:

```bash
# 1. Install Rodauth configuration
rails generate pu:rodauth:install

# 2. Generate a User model and authentication logic
rails generate pu:rodauth:account user

# 3. Run the database migrations
rails db:migrate
```

This is a huge time-saver! It creates:
- A `User` model (`app/models/user.rb`).
- Database migrations for the `users` table.
- All the necessary authentication logic (login, logout, sign up, password reset, etc.).

Now that we have a `User` model, we can create our blog-specific resources.

## Scaffolding the Post Resource

A **Resource** in Plutonium is more than just a model; it's a combination of the model, its definition (how it's displayed), and its policy (who can do what).

Let's scaffold our `Post` resource. It will have a title, some text content, and will belong to a `User`.

```bash
rails generate pu:res:scaffold Post user:belongs_to title:string content:text 'published_at:datetime?'
```

The generator will prompt you to choose which package this resource belongs to. **Select `blogging`**.

This command generates several important files inside your `packages/blogging` directory:

- `app/models/blogging/post.rb`: The ActiveRecord model.
- `app/definitions/blogging/post_definition.rb`: The resource definition for UI.
- `app/policies/blogging/post_policy.rb`: The authorization policy.
- A database migration to create the `blogging_posts` table.

Let's look at the generated model at `packages/blogging/app/models/blogging/post.rb`:

```ruby
# packages/blogging/app/models/blogging/post.rb
class Blogging::Post < Blogging::ResourceRecord
  belongs_to :user
  validates :title, presence: true
  validates :content, presence: true
end
```
Notice it's correctly namespaced under `Blogging` and associated with the `User` model.

Before we continue, run the migration to update your database:
```bash
rails db:migrate
```

## Scaffolding the Comment Resource

Now, let's do the same for `Comment`. A comment will belong to a `User` and a `Post`.

```bash
rails generate pu:res:scaffold Comment user:belongs_to blogging/post:belongs_to body:text
```

Again, select the **`blogging`** package when prompted.

::: tip Namespaced Associations
Notice that we used `blogging/post` to specify the association. Plutonium's generators understand this and will correctly create the namespaced `Blogging::Post` association.
:::

This generates the model, definition, policy, and migration for comments.

Run the migration for comments:
```bash
rails db:migrate
```

## Next Steps

We've now set up users, authentication, and the core `Post` and `Comment` resources for our blog. However, there's no way to interact with them yet.

In the next chapter, we'll create a **Portal** to provide a web interface for managing our new resources.
