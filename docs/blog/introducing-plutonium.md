---
title: "Introducing Plutonium: Rails conventions, past CRUD"
titleTemplate: "Plutonium Blog"
date: 2026-08-24
description: Rails made a bargain. Follow the conventions and the framework carries you. Plutonium makes the same bargain about the layer Rails deliberately left alone.
author: Stefan Froelich
tags: [announcement, rails, architecture]
draft: true
---

# Introducing Plutonium: Rails conventions, past CRUD

<BlogMeta />

Rails made a bargain with you, and the bargain is the whole reason it works.

Name the column `user_id` and the association resolves itself. Name the file `posts_controller.rb` and the routing finds it. Put the partial where Rails expects it and it renders. You give up the freedom to arrange things however you like, and in exchange the framework stops asking you questions. Follow the conventions and the code nearly writes itself. Fight them and every line becomes a negotiation.

The second half of the bargain matters just as much. Rails never locks the door. Every convention has a configuration point behind it: `foreign_key:`, `class_name:`, `to_prepare`, a custom inflection, a controller that renders whatever you want. You get to ninety percent without making a decision, and the rest stays possible.

That bargain stops at the framework layer, on purpose. Rails gives you models, controllers, views, routing, migrations. It does not give you an opinion about authentication flows, authorization rules, admin interfaces, multi-tenancy, or the difference between "a record" and "a thing a user is allowed to act on." Those are application concerns. Rails leaves them to you, which is the right call for a general-purpose framework and also the reason you have written them four times.

Plutonium makes the same bargain about that layer: follow the convention and it carries you, reach for an escape hatch when you need one.

## Design the model correctly and multi-tenancy stops being work

Multi-tenancy is the clearest example, because it's the feature most often implemented as a discipline problem. The usual approach: add a tenant filter to every query, scope every controller action, then review every pull request for the one place someone forgot. The failure mode is a data leak.

In Plutonium you don't write filters. You declare where the tenant lives, once, on the portal:

```ruby
# packages/admin_portal/lib/engine.rb
module AdminPortal
  class Engine < ::Rails::Engine
    include Plutonium::Portal::Engine

    scope_to_entity Organization, strategy: :path
  end
end
```

Then you design your models the way you would have anyway:

```ruby
class Post < ApplicationRecord
  belongs_to :organization              # a direct child of the tenant
end

class Comment < ApplicationRecord
  belongs_to :post
  has_one :organization, through: :post # reachable through an association
end
```

That's the entire setup. Every query in that portal is scoped, every create is associated, every nested route is constrained, because Plutonium can read the path from a record to its tenant out of your associations. Resolution happens in a defined order: a direct `belongs_to` first, then `has_one` or `has_one :through`, then a reverse `has_many` from the entity if it has to.

What matters more is the case where your schema is complicated, because real ones are. When no association expresses the relationship, you don't abandon the convention and start hand-scoping controllers. You write the resolution yourself, on the model:

```ruby
class Invoice < ApplicationRecord
  scope :associated_with_organization, ->(org) {
    joins(:contract).where(contracts: {organization_id: org.id})
  }
end
```

Now `Invoice` scopes exactly the way `Post` does. The index, the show page, nested routes, the authorization scope: all of it behaves identically. You replaced one lookup, not the mechanism.

The convention covers the common shapes, and the exception gets a named place to live. It lives on the *model* rather than in a policy or a controller, so it applies everywhere the record is read.

## Nothing gets declared twice

A definition can be empty:

```ruby
class PostDefinition < ResourceDefinition
end
```

That already renders an index table, a form and a show page. Plutonium reads the model for the rest: column types become field types, `belongs_to` and `has_many` become pickers and nested tables, an attached file becomes an upload. Validations carry through too, so `validates :title, presence: true` marks the field required and `validates :status, inclusion: {in: %w[draft published archived]}` supplies the select's choices.

That move is not a definition feature. It's how the whole framework is built:

- The tenant scope is read off your associations, which is why the multi-tenancy above needed no filters.
- A collection's preloads are read off the policy's permitted fields, so there is no `includes` list to maintain.
- An association picker's typeahead is read off the target resource's own `search` block.
- Whether an interaction is a record, bulk or resource action is read off whether it declares `:resource`, `:resources`, or neither.
- CRUD routes, nested routes and action routes are read off the resource registration.

None of these is a default someone picked for you. Each is computed from a declaration you already made for another reason, which is the part that matters: there is one place to change it, and nothing downstream to keep in step. Add a column, and the form, the table, the export and the preloads all move together.

So you declare only what differs. A `field :title` matching what was detected is dead code.

That leaves the differences, and two portals rarely want the same ones.

## Overrides follow the inheritance you already understand

Rails view lookup walks an inheritance chain. A template in your controller's own directory wins, otherwise it falls back to the parent's.

Plutonium customization works the same way, because it is the same thing: plain Ruby inheritance, across three levels.

Your resource has an app-wide definition:

```ruby
# app/definitions/post_definition.rb
class PostDefinition < ResourceDefinition
  input :content, as: :markdown

  display :status, as: :badge, colors: {published: :accent, draft: :neutral}
end
```

A portal that needs something different inherits from it:

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  scope :pending_review
  input :internal_notes, hint: "Not shown to the author"
end
```

The policy for that portal inherits the same way, and decides a different question:

```ruby
# packages/admin_portal/app/policies/admin_portal/post_policy.rb
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  def permitted_attributes_for_create = %i[title content internal_notes]
end
```

That split is worth being precise about. The definition says *how* a field renders. The policy says *whether it appears at all*. `internal_notes` shows up in the admin portal because the admin policy permits it, not because the admin definition mentions it, and a customer-facing portal that inherits from the same two base classes makes both decisions independently.

Neither portal knows about the other. There's no registry of overrides, no configuration DSL for precedence, no merge semantics to learn. It's a superclass and a subclass, so the answer to "why is this field showing up here but not there" is readable as a class hierarchy.

## Escape hatches, sized to the problem

Plutonium's exits are graduated. You climb only as far as the problem requires.

**Change an option.** Most customization is a keyword:

```ruby
input :content, as: :markdown
display :status, as: :badge, colors: {published: :accent, draft: :neutral}
```

**Render it inline.** A display takes a block, or a proc that runs inside a Phlex context, so tag methods and Tailwind classes are available without defining a class:

```ruby
display :priority, as: :phlexi_render, with: ->(value, attrs) do
  span(class: "pu-badge") { value.humanize }
end
```

**Write a component.** It's Phlex. A field component reads everything off `field` and plugs straight into `as:`:

```ruby
class ChartComponent < Phlexi::Display::Components::Base
  def view_template
    div(**attributes, data: {controller: "chart", chart_value: field.value.to_json})
  end
end

# in the definition
display :revenue, as: ChartComponent
```

A component with its own constructor renders from a block instead:

```ruby
display :card do |field|
  PostCardComponent.new(post: field.object)
end
```

**Implement a hook.** Once the change is about a page or a request rather than a field, there is usually a named seam waiting. Controllers expose hooks rather than asking you to reopen the CRUD actions:

```ruby
class PostsController < ::ResourceController
  private

  def redirect_url_after_submit = posts_path

  def resource_params
    params = super
    params[:tags] = params[:tags].split(",") if params[:tags].is_a?(String)
    params
  end
end
```

Pages expose a matching set for markup: `render_before_content` and `render_after_content`, plus the same pairs around the header, breadcrumbs, toolbar and footer.

```ruby
class PostDefinition < ResourceDefinition
  class ShowPage < ShowPage
    private

    def page_title = "Post: #{object.title}"

    def render_after_content
      render RelatedPostsComponent.new(post: object)
    end
  end
end
```

Both families exist for the reason Rails gives you `before_action` instead of asking you to rewrite dispatch. Overriding a whole method means inheriting responsibility for everything else it did: a page's `view_template` also renders breadcrumbs, the header, and the frame wiring that makes turbo navigation work. Implement `render_after_content` and all of that keeps working.

**Replace the page.** When no hook sits where you need it, override `view_template` on the nested class and take over the whole body. When Phlex is the wrong tool entirely, a designer's HTML or an existing layout you're keeping, drop an ERB view at the controller path instead. ERB wins over the page class when both exist for the same action:

```erb
<%-# app/views/posts/show.html.erb %>
<div class="announcement-banner">Special announcement</div>
<%= render current_definition.show_page_class.new %>
<%= render partial: "related" %>
```

That middle line is the generated page. Keep it and wrap it, or delete it and write the whole thing yourself.

Underneath all five rungs it stays Rails. Your models are plain ActiveRecord. Your controllers inherit from Rails controllers. Your views resolve through Rails view paths. Hotwire works as it does in any Rails app. A Plutonium resource and a hand-written controller can sit in the same app.

## What comes in the box

- **Resources.** One line of registration generates CRUD routes, nested routes and action routes.
- **Authentication.** Rodauth integration, or bring your own.
- **Authorization.** ActionPolicy-backed, with per-field read and write permissions.
- **Multi-tenancy.** Entity scoping declared per portal, resolved through your associations.
- **Queries.** Search, filters, scopes and sorting declared on the definition.
- **Exports.** Streamed CSV on every resource, opt-in through the policy, with columns drawn from the same permitted-attributes list.
- **Eager loading.** Index pages, kanban boards and exports preload the associations and attachments they are about to render. The field set comes from the policy, so there is no `includes` list to declare or keep in step.
- **Positioning.** `positioned_on` on the model and `position_on` in the definition put drag handles on index tables, card grids and nested association tables. A drop writes one decimal, so there is no renumbering sweep.
- **Generators.** Scaffolding for resources, packages, portals, auth and tests, so the conventional files start out conventional.
- **Testing.** Concerns for CRUD, policy, definition, interaction and portal-access tests.
- **Forms.** Nested attributes, markdown editors, date pickers and drag-and-drop uploads.
- **Association inputs.** Server-side typeahead by default, searching through the target resource's own `search` block, with the options filtered by its policy and the values protected by signed global IDs.
- **Interactions.** A business operation gets a button, a form, a policy gate and a typed outcome instead of a bespoke controller action.

Newer, and still experimental:

- **Kanban boards.** Drag between columns, WIP limits, opt-in realtime.
- **Wizards.** Multi-step flows with branching and a built-in review step.
- **Async interactions.** Persisted, resumable runs for work that outlives a request.

## Where it actually is

Plutonium is pre-1.0 and MIT licensed. The core (resources, definitions, policies, portals, packages, entity scoping) is stable and running in production. The newer surfaces are marked experimental in the docs, individually, because their DSLs are young enough that I'd rather rename a method in response to real use than freeze a first guess into a compatibility promise. Pin your version if that makes you nervous.

None of this does something Rails can't. You can build all of it by hand, and you probably have. The argument is that you shouldn't have to build it a fifth time.

Start with the [tutorial](/getting-started/tutorial/), or read [Core Concepts](/getting-started/) to see whether the shape fits how you already think. If it fights you somewhere, I'd like to hear where. That feedback still changes things.
