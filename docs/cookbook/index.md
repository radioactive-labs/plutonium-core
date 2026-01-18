# Cookbook

Real-world recipes and patterns for building applications with Plutonium.

## Overview

These recipes show complete implementations of common application patterns. Each recipe includes:
- Architecture decisions
- Code examples
- Best practices

## Recipes

### [Blog Application](./blog)
A content management system with posts, comments, categories, and multi-user support.

### [SaaS Application](./saas)
Multi-tenant application with organizations, team management, and subscription handling.

## Quick Patterns

### Basic CRUD with Authorization

```ruby
# Model
class Article < ResourceRecord
  belongs_to :author, class_name: 'User'
  validates :title, :body, presence: true
end

# Definition
class ArticleDefinition < Plutonium::Resource::Definition
  field :title
  field :body, as: :rich_text
  field :published, as: :switch

  column :title, sortable: true
  column :author
  column :published
  column :created_at, sortable: true

  search { |scope, q| scope.where("title ILIKE ?", "%#{q}%") }
  scope :all, default: true
  scope :published, -> { where(published: true) }
end

# Policy
class ArticlePolicy < Plutonium::Resource::Policy
  def update?
    owner? || admin?
  end

  def destroy?
    owner? || admin?
  end

  private

  def owner?
    record.author_id == user.id
  end
end
```

### Nested Resource Pattern

```ruby
# Parent
class Project < ResourceRecord
  has_many :tasks, dependent: :destroy
end

# Child
class Task < ResourceRecord
  belongs_to :project
end

# Parent policy enables association panel
class ProjectPolicy < Plutonium::Resource::Policy
  def permitted_associations
    %i[tasks]
  end
end
```

### Custom Action Pattern

```ruby
# Interaction
class CompleteTask < Plutonium::Interaction::Base
  presents model_class: Task
  presents label: "Mark Complete"

  attribute :completion_notes, :text

  def execute
    resource.update!(
      completed: true,
      completed_at: Time.current,
      completion_notes: completion_notes
    )

    succeed(resource).with_message("Task completed!")
  end
end

# Register in definition
class TaskDefinition < Plutonium::Resource::Definition
  action :complete,
         interaction: CompleteTask,
         condition: ->(task) { !task.completed? }
end

# Authorize in policy
class TaskPolicy < Plutonium::Resource::Policy
  def complete?
    owner? && !record.completed?
  end
end
```

### Multi-Portal Pattern

```ruby
# Admin portal - full access
module AdminPortal
  class TaskPolicy < ::TaskPolicy
    def index?
      true
    end

    def destroy?
      true
    end

    def relation_scope(relation)
      relation
    end
  end
end

# User portal - limited access
module UserPortal
  class TaskPolicy < ::TaskPolicy
    def index?
      true
    end

    def destroy?
      owner?
    end

    def relation_scope(relation)
      relation.where(user: user)
    end
  end
end
```

## Architecture Patterns

### Feature Package Organization

```
packages/
├── core/              # Shared models (User, Organization)
├── projects/          # Project management feature
├── billing/           # Subscription & payments
├── notifications/     # Email & push notifications
├── admin_portal/      # Admin interface
└── customer_portal/   # Customer interface
```

### Service Objects with Interactions

```ruby
# Complex operations go in Interactions
class CreateProjectWithTasks < Plutonium::Interaction::Base
  presents model_class: Project

  attribute :name, :string
  attribute :tasks, :json  # Array of task attributes

  validates :name, presence: true

  def execute
    project = Project.create!(name: name, user: context[:user])

    tasks.each do |task_attrs|
      project.tasks.create!(task_attrs)
    end

    succeed(project).with_message("Project created with #{tasks.size} tasks")
  rescue ActiveRecord::RecordInvalid => e
    fail!(e.message)
  end
end
```

### Event-Driven Updates

```ruby
class PublishArticle < Plutonium::Interaction::Base
  presents model_class: Article

  def execute
    resource.update!(published: true, published_at: Time.current)

    # Trigger downstream effects
    ArticlePublishedJob.perform_later(resource.id)
    NotifySubscribersJob.perform_later(resource.id)
    UpdateSearchIndexJob.perform_later(resource.id)

    succeed(resource)
  end
end
```

## Common Customizations

### Custom Display Component

```ruby
class StatusBadge < Plutonium::UI::Component::Base
  COLORS = {
    'draft' => 'gray',
    'pending' => 'yellow',
    'approved' => 'green',
    'rejected' => 'red'
  }.freeze

  def initialize(status:)
    @status = status
    @color = COLORS.fetch(status, 'gray')
  end

  def view_template
    span(class: "px-2 py-1 text-xs rounded bg-#{@color}-100 text-#{@color}-800") do
      @status.titleize
    end
  end
end

# Use in definition
column :status do |record|
  render StatusBadge.new(status: record.status)
end
```

### Custom Form Section

```ruby
class ProjectForm < Plutonium::UI::Form::Resource
  def form_template
    div(class: "space-y-8") do
      section("Basic Information") do
        render_field :name
        render_field :description
      end

      section("Settings") do
        render_field :visibility
        render_field :notifications_enabled
      end

      section("Team") do
        render_field :team_members, as: :nested
      end

      render_submit_button
    end
  end

  private

  def section(title, &block)
    div(class: "bg-white rounded-lg shadow p-6") do
      h3(class: "text-lg font-medium mb-4") { title }
      yield
    end
  end
end
```

## Next Steps

- Explore the [Guides](/guides/) for detailed how-tos
- Check the [Reference](/reference/) for complete API documentation
- Visit our [GitHub](https://github.com/radioactive-labs/plutonium-core) for more examples
