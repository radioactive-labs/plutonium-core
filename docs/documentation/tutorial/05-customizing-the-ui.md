# 5. Customizing the UI

Our dashboard is functional, but it's not very user-friendly. In Plutonium, customizing the UI is a two-step process that respects the separation of concerns:

1.  **Policy (`app/policies`)**: The policy file controls **what** a user is authorized to see or edit. This is a security layer.
2.  **Definition (`app/definitions`)**: The definition file controls **how** those permitted fields are displayed and formatted. This is a presentation layer.

Let's customize our `Post` resource by following this two-step process for the table, detail page, and form.

## Customizing the Posts Table (Index View)

First, we'll define **what** columns should appear in the posts table. This is an authorization concern, so we'll use the policy file.

Open the post policy: `packages/blogging/app/policies/blogging/post_policy.rb`

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # ... (other methods)

  # 1. Define WHAT columns are visible in the table.
  def permitted_attributes_for_index
    [:user, :title, :published_at, :created_at]
  end
end
```

Next, we'll configure **how** these columns are displayed in the definition file.

Open the post definition: `packages/blogging/app/definitions/blogging/post_definition.rb`

```ruby
# packages/blogging/app/definitions/blogging/post_definition.rb
class Blogging::PostDefinition < Blogging::ResourceDefinition
  # 2. Define HOW the permitted columns are rendered.
  column :published_at, as: :datetime
  column :created_at, as: :datetime
end
```

The table now only shows the permitted columns, formatted as we specified.

![Plutonium Posts Dashboard (Customized)](/tutorial/plutonium-posts-dashboard-customized.png)

## Customizing the Post Detail Page (Show View)

The same two-step process applies to the detail page.

1.  **Policy**: Define what fields are visible with `permitted_attributes_for_show`.
2.  **Definition**: Define how they are rendered with `display`.

Let's define the fields in the policy. For this view, we want to show the `:content`.

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # ...

  def permitted_attributes_for_index
    [:user, :title, :published_at, :created_at]
  end

  # 1. Define WHAT fields are visible on the show page.
  def permitted_attributes_for_show
    [:user, :title, :content, :published_at, :created_at]
  end
end
```

Now, let's configure the layout in the definition. We'll make each field take up the full width of the view.

```ruby
# packages/blogging/app/definitions/blogging/post_definition.rb
class Blogging::PostDefinition < Blogging::ResourceDefinition
  display :user, wrapper: { class: "col-span-full" }
  display :title, wrapper: { class: "col-span-full" }
  display :content, wrapper: { class: "col-span-full" }
  display :published_at, wrapper: { class: "col-span-full" }
  display :created_at, wrapper: { class: "col-span-full" }
end
```

![Plutonium Posts Detail (Customized)](/tutorial/plutonium-posts-detail-customized.png)

## Customizing the Post Form

Finally, we'll customize the `new` and `edit` forms.

1.  **Policy**: Use `permitted_attributes_for_create` and `_for_update` to control which fields can be submitted.
2.  **Definition**: Use the `input` helper to control how the form inputs are rendered.

First, the policy. We don't want the user to be able to set the `published_at` date directly in the form.

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # ...

  # 1. Define WHAT fields can be submitted in the form.
  def permitted_attributes_for_create
    [:user_id, :title, :content]
  end

  def permitted_attributes_for_update
    permitted_attributes_for_create
  end
end
```

Now, the definition. We'll use the `input` helper to specify that `:content` should use a rich text editor.

```ruby
# packages/blogging/app/definitions/blogging/post_definition.rb
class Blogging::PostDefinition < Blogging::ResourceDefinition
  # ... (display helpers from above)

  # 2. Define HOW the form inputs are rendered.
  input :content, as: :rich_text # Use a rich text editor
end
```

By separating what is permitted from how it is rendered, Plutonium gives you both security and flexibility.

## Next Steps

Our UI is now much more polished. We've used the **Policy** and **Definition** files together to customize our `Post` resource.

In the next chapter, we'll add custom business logic by creating an **Action** to publish a draft post.
