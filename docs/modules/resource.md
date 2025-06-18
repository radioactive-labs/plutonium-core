---
title: Resource Module
---

# Resource Module

The Resource module is the heart of Plutonium's CRUD functionality. It provides a declarative way to define resources, their behavior, and automatically generates controllers, views, and related functionality.

::: tip
The Resource module is located in `lib/plutonium/resource/`. Resource definitions are typically placed in `app/definitions/`.
:::

## Overview

The Resource module is located in `lib/plutonium/resource/` and provides:

- Resource definition DSL for declarative configuration
- Automatic controller generation and behavior
- CRUD operations with minimal boilerplate
- Query objects for filtering and searching
- Policy integration for authorization
- Interaction integration for business logic

## Core Components

### Resource Definition (`lib/plutonium/resource/definition.rb`)

Resource definitions are the primary way to configure how resources behave in Plutonium applications.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Display configuration
  display :title, :author, :published_at, :status

  # Search configuration
  search do |scope, search|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{search}%", "%#{search}%")
  end

  # Filtering configuration
  filter :published, type: :boolean
  filter :author, type: :select, collection: -> { User.pluck(:name, :id) }
  filter :created_at, type: :date_range

  # Form configuration
  input :title, as: :string
  input :content, as: :text
  input :published, as: :boolean
  input :author, as: :select, collection: -> { User.pluck(:name, :id) }

  # Actions configuration
  action :publish, interaction: PublishPostInteraction
  action :archive, interaction: ArchivePostInteraction

  # Scoping
  scope :published
  scope :drafts, -> { where(published: false) }

  # Nested resources
  nested_input :comments
end
```

### Resource Controller (`lib/plutonium/resource/controller.rb`)

The resource controller provides standard CRUD operations with extensive customization options.

#### Key Features

- **Automatic CRUD**: Standard index, show, new, create, edit, update, destroy actions
- **Query Integration**: Automatic filtering, searching, and sorting
- **Policy Enforcement**: Authorization checks on all actions
- **Interaction Support**: Business logic through interactions
- **Nested Resources**: Support for nested resource operations

#### Key Methods

- `resource_class` - Get the resource class for the controller
- `resource_record!` - Get the current resource record (raises exception if not found)
- `resource_record?` - Get the current resource record (returns nil if not found)
- `resource_params` - Get processed resource parameters with scoping and parent params
- `submitted_resource_params` - Get raw submitted parameters
- `current_parent` - Get the current parent record for nested resources
- `build_form` - Build a form for the resource
- `build_detail` - Build a detail view for the resource
- `build_collection` - Build a collection view for resources
- `current_query_object` - Get the current query object for filtering/searching

#### Usage Example

```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  # Controller automatically configured based on PostDefinition
  # All CRUD operations available out of the box

  private

  # Optional: Override resource class resolution
  def self.resource_class
    Post # Explicitly set if auto-detection fails
  end

  # The resource_params method is automatically handled
  # It includes scoping and parent parameters automatically
end
```

### Query Objects (`lib/plutonium/resource/query_object.rb`)

Query objects handle filtering, searching, and sorting of resources.

#### Features

- **Search**: Full-text search across specified fields
- **Filtering**: Type-specific filters (boolean, select, date range, etc.)
- **Sorting**: Configurable sorting options
- **Scoping**: Apply predefined scopes
- **Pagination**: Built-in pagination support

#### Key Methods

- `define_filter(name, body)` - Define a custom filter
- `define_scope(name, body)` - Define a scope filter
- `define_sorter(name, body)` - Define a custom sorter
- `define_search(body)` - Define search functionality
- `apply(scope, params)` - Apply filters and sorting to a scope
- `build_url(**options)` - Build URLs with query parameters

#### Usage Example

```ruby
# Automatic usage through controllers
GET /posts?q[search]=rails&q[published]=true&q[sort_fields][]=created_at&q[sort_directions][created_at]=desc

# Manual usage in controller
query_object = current_query_object
@resource_records = query_object.apply(current_authorized_scope, raw_resource_query_params)

# Defining custom query behavior
query_object = Plutonium::Resource::QueryObject.new(Post, params[:q] || {}, request.path) do |query|
  query.define_search proc { |scope, search:| scope.where("title ILIKE ?", "%#{search}%") }
  query.define_filter :published, proc { |scope, published:| scope.where(published: published) }
  query.define_sorter :title, proc { |scope, direction:| scope.order(title: direction) }
end
```

#### Advanced Query Object Examples

**Complex Search with Multiple Fields**
```ruby
query_object = Plutonium::Resource::QueryObject.new(Post, params[:q] || {}, request.path) do |query|
  query.define_search proc { |scope, search:|
    scope.joins(:author, :tags)
         .where(
           "posts.title ILIKE :search OR posts.content ILIKE :search OR users.name ILIKE :search OR tags.name ILIKE :search",
           search: "%#{search}%"
         )
         .distinct
  }
end
```

**Custom Date Range Filter**
```ruby
query_object.define_filter :date_range, proc { |scope, start_date:, end_date:|
  scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
}
```

**Conditional Scoping with User Context**
```ruby
query_object.define_scope :my_posts, proc { |scope|
  scope.where(author: current_user)
}

query_object.define_scope :team_posts, proc { |scope|
  scope.joins(:author).where(users: { team_id: current_user.team_id })
}
```

**Complex Sorting with Associations**
```ruby
query_object.define_sorter :author_name, proc { |scope, direction:|
  scope.joins(:author).order("users.name #{direction}")
}

query_object.define_sorter :comment_count, proc { |scope, direction:|
  scope.left_joins(:comments)
       .group('posts.id')
       .order("COUNT(comments.id) #{direction}")
}
```

### Resource Policy (`lib/plutonium/resource/policy.rb`)

Resource policies provide authorization logic for resource operations.

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def index?
    true # Everyone can view posts list
  end

  def show?
    record.published? || record.author == user
  end

  def create?
    user.present?
  end

  def update?
    record.author == user || user.admin?
  end

  def destroy?
    record.author == user || user.admin?
  end

  def publish?
    record.author == user && record.draft?
  end
end
```

### Resource Context (`lib/plutonium/resource/context.rb`)

A simple data structure that provides context for resource operations.

```ruby
# Context is a Data.define with three attributes:
context = Plutonium::Resource::Context.new(
  resource_class: Post,
  parent: current_user,           # Parent record for nested resources
  scope: current_organization     # Scoping entity (for multi-tenancy)
)
```

### Resource Record (`lib/plutonium/resource/record.rb`)

A module that enhances Active Record models with Plutonium-specific functionality.

```ruby
class Post < ApplicationRecord
  include Plutonium::Resource::Record

  belongs_to :author, class_name: 'User'
  has_many :comments, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true

  scope :published, -> { where(published: true) }
  scope :drafts, -> { where(published: false) }
end
```

#### Features Provided by Resource::Record

**Labeling (`lib/plutonium/resource/record/labeling.rb`)**
```ruby
# Automatic label generation for display
post.to_label  # => "My Post Title" or "Post #123"
```

**Field Names (`lib/plutonium/resource/record/field_names.rb`)**
```ruby
# Categorized field name access
Post.content_column_field_names        # => [:title, :content, :published_at]
Post.belongs_to_association_field_names # => [:author]
Post.has_many_association_field_names   # => [:comments]
Post.has_one_attached_field_names       # => [:featured_image]
Post.resource_field_names               # => All field names combined
```

**Secure Associations (`lib/plutonium/resource/record/associations.rb`)**
```ruby
# Automatic SGID (Signed Global ID) methods for associations
post.author_sgid = user.to_signed_global_id
post.comment_sgids = [comment1.to_signed_global_id, comment2.to_signed_global_id]
```

**Route Helpers (`lib/plutonium/resource/record/routes.rb`)**
```ruby
# Enhanced routing support for nested and scoped resources

# Default scope for finding records by path parameter
User.from_path_param("123")  # => User.where(id: "123")

# Custom path parameter methods (class methods)
class User < ApplicationRecord
  include Plutonium::Resource::Record

  # Use a specific field as the URL parameter
  path_parameter :username
  # Now User.from_path_param("john") => User.where(username: "john")
  # And user.to_param => user.username

  # Use dynamic parameterization (id + field)
  dynamic_path_parameter :title
  # Now user.to_param => "123-my-blog-post-title"
  # And User.from_path_param("123-my-blog-post-title") => User.where(id: "123")
end

# Association route helpers
Post.has_many_association_routes  # => ["comments", "tags"]

# Nested attributes configuration
Post.all_nested_attributes_options
# => { comments: { macro: :has_many, class: Comment, allow_destroy: true } }
```

## Resource Definitions

Resource definitions are the heart of Plutonium's declarative configuration system. They define how resources behave, how they're displayed, what inputs are available, and what actions can be performed.

### Definition Structure

Resource definitions inherit from `Plutonium::Resource::Definition` and use a declarative DSL:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Display configuration - what fields to show in tables/lists
  display :title, :author, :published_at, :status

  # Input configuration - what fields to show in forms
  input :title, as: :string
  input :content, as: :text
  input :published, as: :boolean
  input :author, as: :select, collection: -> { User.pluck(:name, :id) }

  # Search configuration - how to search records
  search do |scope, search|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{search}%", "%#{search}%")
  end

  # Filter configuration - what filters to provide
  filter :published, type: :boolean
  filter :author, type: :select, collection: -> { User.pluck(:name, :id) }
  filter :created_at, type: :date_range

  # Action configuration - what custom actions are available
  action :publish, interaction: PublishPostInteraction
  action :archive, interaction: ArchivePostInteraction

  # Scope configuration - predefined query scopes
  scope :published
  scope :drafts, -> { where(published: false) }

  # Page configuration
  index_page_title "All Blog Posts"
  show_page_title "Post Details"
  new_page_title "Create New Post"
  edit_page_title "Edit Post"
end
```

### Display Configuration

The `display` method configures which fields are shown in index tables and detail views:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Basic field display
  display :title, :author, :created_at

  # All available fields (if not specified, uses model's resource_field_names)
  display :id, :title, :content, :author, :published, :created_at, :updated_at

  # Field-specific options (implementation may vary by field type)
  display :status, class: "font-semibold"
  display :created_at, format: :short
end
```

### Input Configuration

The `input` method configures form fields for create and edit operations:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Basic input types
  input :title, as: :string
  input :content, as: :text
  input :published, as: :boolean
  input :view_count, as: :number
  input :published_at, as: :datetime
  input :created_at, as: :date

  # Select inputs with options
  input :category, as: :select, collection: %w[tech business lifestyle]
  input :author, as: :select, collection: -> { User.pluck(:name, :id) }

  # File uploads
  input :featured_image, as: :file
  input :attachments, as: :file, multiple: true

  # Rich text editor
  input :content, as: :rich_text

  # Hidden fields
  input :user_id, as: :hidden

  # Custom input options
  input :slug, as: :string, placeholder: "auto-generated-if-blank"
  input :excerpt, as: :text, rows: 3
end
```

### Search Configuration

The `search` method defines how full-text search works across your resource:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Basic search across multiple fields
  search do |scope, search|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{search}%", "%#{search}%")
  end

  # Advanced search with term splitting
  search do |scope, search|
    terms = search.split(/\s+/)
    terms.reduce(scope) do |current_scope, term|
      current_scope.where(
        "title ILIKE ? OR content ILIKE ? OR author_name ILIKE ?",
        "%#{term}%", "%#{term}%", "%#{term}%"
      )
    end
  end

  # Search with associations
  search do |scope, search|
    scope.joins(:author, :tags).where(
      "posts.title ILIKE ? OR posts.content ILIKE ? OR users.name ILIKE ? OR tags.name ILIKE ?",
      "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%"
    )
  end
end
```

### Filter Configuration

The `filter` method defines filtering options for the resource:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Boolean filter
  filter :published, type: :boolean

  # Select filter with static options
  filter :category, type: :select, collection: %w[tech business lifestyle]

  # Select filter with dynamic options
  filter :author, type: :select, collection: -> { User.pluck(:name, :id) }

  # Date filters
  filter :created_at, type: :date
  filter :published_at, type: :date_range

  # Number filters
  filter :view_count, type: :number
  filter :word_count, type: :number_range

  # Text filter (default type)
  filter :title  # Equivalent to: filter :title, type: :text

  # Custom filter with block
  filter :content_length do |scope, value:|
    case value
    when 'short'
      scope.where('LENGTH(content) < 500')
    when 'medium'
      scope.where('LENGTH(content) BETWEEN 500 AND 2000')
    when 'long'
      scope.where('LENGTH(content) > 2000')
    end
  end
end
```

### Action Configuration

The `action` method defines custom actions that can be performed on resources:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Basic action
  action :publish, interaction: PublishPostInteraction

  # Action with confirmation
  action :delete_permanently,
         interaction: DeletePostInteraction,
         confirmation: "This action cannot be undone. Are you sure?"

  # Action with icon and category
  action :feature,
         interaction: FeaturePostInteraction,
         icon: Phlex::TablerIcons::Star,
         category: :primary

  # Record-specific action (shows on individual records)
  action :approve,
         interaction: ApprovePostInteraction,
         record_action: true

  # Collection action (shows on index page for bulk operations)
  action :bulk_publish,
         interaction: BulkPublishInteraction,
         collection_action: true

  # Conditional action
  action :archive,
         interaction: ArchivePostInteraction,
         if: -> { current_user.admin? }

  # Action with custom positioning
  action :priority_boost,
         interaction: PriorityBoostInteraction,
         position: 1  # Shows first in action list
end
```

### Scope Configuration

The `scope` method defines predefined query scopes:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Named scope (uses existing model scope)
  scope :published
  scope :featured

  # Lambda scope
  scope :recent, -> { where('created_at > ?', 1.week.ago) }
  scope :popular, -> { where('view_count > ?', 1000) }

  # Conditional scope
  scope :own_posts,
        -> { where(author: current_user) },
        if: -> { !current_user.admin? }

  # Scope with parameters
  scope :by_category, ->(category) { where(category: category) }
end
```

### Page Configuration

Configure page titles, descriptions, and breadcrumbs:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Static page titles
  index_page_title "All Blog Posts"
  show_page_title "Post Details"
  new_page_title "Create New Post"
  edit_page_title "Edit Post"

  # Dynamic page titles
  show_page_title -> { "Reading: #{resource_record!.title}" }
  edit_page_title -> { "Editing: #{resource_record!.title}" }

  # Page descriptions
  index_page_description "Manage and organize your blog content"
  show_page_description "View post details and related information"

  # Breadcrumb configuration
  breadcrumbs true
  index_page_breadcrumbs true
  show_page_breadcrumbs false
  new_page_breadcrumbs true
  edit_page_breadcrumbs true
end
```

### Nested Input Configuration

Handle nested resource relationships in forms:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Simple nested input (uses all available fields)
  nested_input :comments

  # Nested input with specific fields
  nested_input :tags, fields: [:name, :color]

  # Nested input with block configuration
  nested_input :metadata do
    input :key, as: :string
    input :value, as: :text
  end

  # Nested input with options
  nested_input :attachments,
               fields: [:name, :file],
               allow_destroy: true,
               limit: 5
end
```

### Field and Column Configuration

Fine-tune field behavior and display:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Field configuration (affects multiple contexts)
  field :title, as: :string, required: true
  field :status, as: :select, collection: %w[draft published archived]

  # Column-specific configuration (for table display)
  column :title, class: "font-bold text-lg"
  column :status, renderer: :badge
  column :created_at, format: :short

  # Display-specific configuration
  display :title, :status, :author, :created_at
end
```

### Definition Inheritance

Resource definitions support inheritance for shared configuration:

```ruby
class BaseContentDefinition < Plutonium::Resource::Definition
  # Common fields for all content types
  input :title, as: :string
  input :content, as: :text
  input :published, as: :boolean

  # Common filters
  filter :published, type: :boolean
  filter :created_at, type: :date_range

  # Common search
  search do |scope, search|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{search}%", "%#{search}%")
  end
end

class PostDefinition < BaseContentDefinition
  # Post-specific configuration
  input :featured, as: :boolean
  input :category, as: :select, collection: %w[tech business lifestyle]

  filter :featured, type: :boolean
  filter :category, type: :select, collection: %w[tech business lifestyle]

  action :publish, interaction: PublishPostInteraction
end

class ArticleDefinition < BaseContentDefinition
  # Article-specific configuration
  input :research_level, as: :select, collection: %w[basic intermediate advanced]

  filter :research_level, type: :select, collection: %w[basic intermediate advanced]

  action :peer_review, interaction: PeerReviewInteraction
end
```

### Dynamic Configuration

Use lambdas and conditionals for context-aware configuration:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Dynamic display based on user role
  display -> {
    fields = [:title, :author, :created_at]
    fields << :admin_notes if current_user.admin?
    fields << :internal_id if current_user.developer?
    fields
  }

  # Conditional inputs
  input :featured, as: :boolean, if: -> { current_user.editor? }
  input :admin_notes, as: :text, if: -> { current_user.admin? }

  # Dynamic filter collections
  filter :author,
         type: :select,
         collection: -> {
           if current_user.admin?
             User.pluck(:name, :id)
           else
             User.where(department: current_user.department).pluck(:name, :id)
           end
         }

  # Conditional actions
  action :approve,
         interaction: ApprovePostInteraction,
         if: -> { current_user.can_approve? && resource_record!.pending? }
end
```

## Advanced Features

### Nested Resources

Handle nested resource relationships:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Simple nested input
  nested_input :comments

  # Nested input with configuration
  nested_input :tags do
    input :name, :string
    input :color, :color
  end

  # Nested resource with custom fields
  nested_input :metadata, fields: [:key, :value]
end
```

### Scoping

Apply scopes to resources:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Named scope
  scope :published

  # Lambda scope
  scope :recent, -> { where('created_at > ?', 1.week.ago) }

  # Conditional scope
  scope :own_posts, -> { where(author: current_user) }, if: -> { !current_user.admin? }
end
```

### Custom Rendering

Customize how fields are rendered:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Badge renderer
  display :status, renderer: :badge,
          color_map: { published: :green, draft: :yellow, archived: :red }

  # Image renderer
  display :featured_image, renderer: :image, size: :thumbnail

  # Custom renderer
  display :word_count, renderer: -> (value) { "#{value} words" }

  # Link renderer
  display :external_url, renderer: :link, target: :blank
end
```

## Integration with Other Modules

### Interaction Integration

Resources integrate seamlessly with interactions:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  action :publish, interaction: PublishPostInteraction
end

class PublishPostInteraction < Plutonium::Interaction::Base
  attribute :id, :integer

  private

  def execute
    post = Post.find(id)
    if post.update(published: true, published_at: Time.current)
      success(post)
        .with_message("Post published successfully")
        .with_response(Response::Redirect.new(post_path(post)))
    else
      failure(post.errors)
    end
  end
end
```

### UI Integration

Resources automatically generate appropriate UI components:

```ruby
# Tables are automatically generated based on display configuration
# Forms are automatically generated based on input configuration
# Actions become buttons with proper styling and behavior
```

### Policy Integration

Resources work with ActionPolicy for authorization:

```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  # Policies are automatically applied:
  # - index action checks PostPolicy#index?
  # - show action checks PostPolicy#show?
  # - create action checks PostPolicy#create?
  # etc.
end
```

## Testing

### Resource Definition Testing

```ruby
RSpec.describe PostDefinition do
  subject(:definition) { described_class.new }

  it 'configures display fields correctly' do
    expect(definition.display_fields).to include(:title, :author, :created_at)
  end

  it 'configures search fields correctly' do
    expect(definition.search_fields).to include(:title, :content)
  end

  it 'configures filters correctly' do
    expect(definition.filters[:published]).to be_present
  end
end
```

### Resource Controller Testing

```ruby
RSpec.describe PostsController, type: :controller do
  let(:user) { create(:user) }
  let(:post) { create(:post, author: user) }

  before { sign_in(user) }

  describe 'GET #index' do
    it 'returns successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'applies search filters' do
      matching_post = create(:post, title: 'Rails Guide')
      non_matching_post = create(:post, title: 'Vue Tutorial')

      get :index, params: { search: 'Rails' }
      expect(assigns(:records)).to include(matching_post)
      expect(assigns(:records)).not_to include(non_matching_post)
    end
  end

  describe 'POST #create' do
    let(:valid_params) { { post: { title: 'New Post', content: 'Content' } } }

    it 'creates a new post' do
      expect {
        post :create, params: valid_params
      }.to change(Post, :count).by(1)
    end
  end
end
```

### Query Object Testing

```ruby
RSpec.describe PostQueryObject do
  let(:published_post) { create(:post, published: true) }
  let(:draft_post) { create(:post, published: false) }

  describe '#call' do
    it 'filters by published status' do
      query = described_class.new(published: true)
      results = query.call(Post.all)

      expect(results).to include(published_post)
      expect(results).not_to include(draft_post)
    end

    it 'searches by title' do
      rails_post = create(:post, title: 'Rails Guide')
      vue_post = create(:post, title: 'Vue Tutorial')

      query = described_class.new(search: 'Rails')
      results = query.call(Post.all)

      expect(results).to include(rails_post)
      expect(results).not_to include(vue_post)
    end
  end
end
```

## Best Practices

### Resource Definition

1. **Keep definitions focused**: One definition per resource
2. **Use meaningful names**: Clear, descriptive field names
3. **Configure sensible defaults**: Reasonable display and input configurations
4. **Implement proper validation**: Both at model and definition level
5. **Use scoping appropriately**: Apply necessary data restrictions

### Controller Customization

1. **Minimize controller code**: Use definitions and interactions
2. **Override selectively**: Only customize what's necessary
3. **Maintain REST conventions**: Stick to standard actions when possible
4. **Handle errors gracefully**: Provide meaningful error messages

### Performance Optimization

1. **Use includes**: Prevent N+1 queries in displays
2. **Implement pagination**: For large datasets
3. **Cache expensive operations**: Use Rails caching appropriately
4. **Optimize search**: Use database indexes for search fields

## Migration Guide

### From Rails Scaffolding

Converting Rails scaffold to Plutonium resource:

```ruby
# Before: Rails scaffold controller
class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    @posts = Post.all
  end

  def show
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to @post, notice: 'Post was successfully created.'
    else
      render :new
    end
  end

  # ... more actions

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :content, :published)
  end
end

# After: Plutonium resource
class PostDefinition < Plutonium::Resource::Definition
  display :title, :author, :created_at
  input :title, as: :string
  input :content, as: :text
  input :published, as: :boolean
  search do |scope, search|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{search}%", "%#{search}%")
  end
  filter :published, type: :boolean
end

class PostsController < ApplicationController
  include Plutonium::Resource::Controller
  # All CRUD functionality automatically available
end
```

## Related Modules

- **[Core](./core.md)** - Base controller functionality
- **[Definition](./definition.md)** - Resource definition DSL
- **[Query](./query.md)** - Query objects and filtering
- **[Interaction](./interaction.md)** - Business logic encapsulation
- **[UI](./ui.md)** - User interface components
