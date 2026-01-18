# Architecture

Plutonium follows a layered architecture where each layer has a specific responsibility. This separation makes applications easier to understand, test, and maintain.

## The Four Layers

### 1. Model Layer

The Model layer handles **data and business rules**.

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_many :comments

  validates :title, presence: true
  validates :body, presence: true

  scope :published, -> { where(published: true) }
end
```

Responsibilities:
- Database schema and migrations
- Validations
- Associations
- Scopes and queries
- Core business logic

### 2. Definition Layer

The Definition layer controls **how resources render**.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Fields shown in forms
  field :title
  field :body, as: :rich_text
  field :published, as: :switch

  # Columns shown in tables
  column :title, sortable: true
  column :published
  column :created_at

  # Custom actions
  action :publish, interaction: PublishPost
end
```

Responsibilities:
- Which fields appear in forms
- How fields are rendered (input types)
- Table column configuration
- Search and filtering
- Custom actions
- Field groups and layout

### 3. Policy Layer

The Policy layer controls **authorization**.

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def read?
    record.published? || owner?
  end

  def update?
    owner?
  end

  def permitted_attributes_for_update
    [:title, :body, :published]
  end

  def relation_scope(relation)
    relation.where(published: true).or(relation.where(user: user))
  end
end
```

Responsibilities:
- Action permissions (can user perform action?)
- Attribute permissions (which fields can user see/modify?)
- Collection scoping (which records can user access?)
- Multi-tenancy isolation

### 4. Controller Layer

The Controller layer handles **HTTP requests**.

```ruby
class PostsController < Plutonium::Resource::Controller
  private

  def build_resource
    super.tap do |post|
      post.user = current_user
    end
  end

  def after_create_success
    notify_subscribers(@resource)
    super
  end
end
```

Responsibilities:
- CRUD actions
- Request/response handling
- Resource building hooks
- Redirects and rendering
- Format handling (HTML, JSON, etc.)

## Request Flow

When a request comes in, it flows through the layers:

```
1. REQUEST arrives at Portal
   ↓
2. CONTROLLER receives request
   ↓
3. POLICY checks authorization
   ↓
4. DEFINITION determines rendering
   ↓
5. MODEL provides data
   ↓
6. RESPONSE rendered and returned
```

### Example: Viewing a Post

```
GET /admin/posts/1

1. AdminPortal routes to PostsController#show
2. PostsController loads Post.find(1)
3. PostPolicy#read? checks if user can view
4. PostDefinition provides field configuration
5. UI renders the post display
6. HTML response returned
```

### Example: Creating a Post

```
POST /admin/posts

1. AdminPortal routes to PostsController#create
2. PostsController builds new Post
3. PostPolicy#create? checks if user can create
4. PostPolicy#permitted_attributes_for_create filters params
5. Post validates and saves
6. Redirect to show page
```

## Layer Interaction

Layers communicate through well-defined interfaces:

```ruby
# Controller asks Policy
policy = policy_for(resource)
policy.authorize!(:update)

# Controller uses Definition
definition = definition_for(resource)
definition.fields_for(:form)

# Policy uses Model
def owner?
  record.user_id == user.id
end
```

## Customization Points

Each layer provides hooks for customization:

### Model Hooks
- Callbacks (before_save, after_create, etc.)
- Custom methods
- Scopes

### Definition Hooks
- Field configuration
- Custom renderers
- Conditional display

### Policy Hooks
- Custom permission methods
- Attribute filtering
- Scope customization

### Controller Hooks
- `build_resource` - Customize resource initialization
- `before_action` - Standard Rails callbacks
- `after_*_success/failure` - Action result hooks

## Why This Architecture?

### 1. Separation of Concerns
Each layer has one job. Forms don't know about authorization. Policies don't know about rendering.

### 2. Testability
Each layer can be tested in isolation:
- Model specs test validations and queries
- Policy specs test authorization
- Definition specs test field configuration
- Controller specs test request handling

### 3. Reusability
Definitions and policies can be shared across portals. Models are independent of the UI.

### 4. Maintainability
Changes to authorization don't affect forms. UI changes don't affect data logic.

## Related Topics

- [Resources](./resources) - Understanding resource classes
- [Packages and Portals](./packages-portals) - Organizing your application
- [Auto-Detection](./auto-detection) - How defaults are determined
