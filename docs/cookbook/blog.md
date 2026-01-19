# Recipe: Blog Application

Build a full-featured blog with posts, comments, categories, and multi-user support.

## Overview

This recipe covers:
- Post and comment management
- Categories and tags
- User roles (admin, author, reader)
- Publication workflow
- SEO features

## Architecture

```
packages/
├── blogging/           # Feature package
│   ├── models/
│   │   ├── post.rb
│   │   ├── comment.rb
│   │   ├── category.rb
│   │   └── tag.rb
│   ├── definitions/
│   ├── policies/
│   └── interactions/
├── admin_portal/       # Admin interface
└── public_portal/      # Public blog
```

## Models

### Post

```ruby
module Blogging
  class Post < Blogging::ResourceRecord
    belongs_to :author, class_name: 'User'
    belongs_to :category
    has_many :comments, dependent: :destroy
    has_many :taggings, dependent: :destroy
    has_many :tags, through: :taggings

    validates :title, presence: true, length: { maximum: 200 }
    validates :body, presence: true
    validates :slug, presence: true, uniqueness: true

    scope :published, -> { where(published: true) }
    scope :draft, -> { where(published: false) }
    scope :featured, -> { where(featured: true) }
    scope :recent, -> { order(published_at: :desc) }

    before_validation :generate_slug, on: :create

    def publish!
      update!(published: true, published_at: Time.current)
    end

    def reading_time
      words_per_minute = 200
      (body.to_plain_text.split.size / words_per_minute.to_f).ceil
    end

    private

    def generate_slug
      self.slug ||= title&.parameterize
    end
  end
end
```

### Comment

```ruby
module Blogging
  class Comment < Blogging::ResourceRecord
    belongs_to :post
    belongs_to :author, class_name: 'User'
    belongs_to :parent, class_name: 'Comment', optional: true
    has_many :replies, class_name: 'Comment', foreign_key: :parent_id

    validates :body, presence: true

    scope :approved, -> { where(approved: true) }
    scope :pending, -> { where(approved: false) }
    scope :root, -> { where(parent_id: nil) }
  end
end
```

### Category

```ruby
module Blogging
  class Category < Blogging::ResourceRecord
    has_many :posts

    validates :name, presence: true, uniqueness: true
    validates :slug, presence: true, uniqueness: true

    before_validation :generate_slug

    private

    def generate_slug
      self.slug ||= name&.parameterize
    end
  end
end
```

## Definitions

### Post Definition

```ruby
module Blogging
  class PostDefinition < Plutonium::Resource::Definition
    # Form fields
    field :title
    field :slug, hint: "URL-friendly version (auto-generated if blank)"
    field :body, as: :rich_text
    field :excerpt, as: :text
    field :category
    field :tags, as: :select, multiple: true, collection: -> { Tag.pluck(:name, :id) }
    field :featured_image, as: :file, accept: "image/*"
    field :published, as: :switch
    field :featured, as: :switch
    field :meta_title
    field :meta_description, as: :text

    # Table columns
    column :title, sortable: true
    column :category
    column :author
    column :published
    column :featured
    column :published_at, sortable: true

    # Search
    search do |scope, query|
      scope.where("title ILIKE :q OR body ILIKE :q", q: "%#{query}%")
    end

    # Scopes
    scope :all, default: true
    scope :published, -> { where(published: true) }, badge: true
    scope :drafts, -> { where(published: [false, nil]) }, badge: true
    scope :featured, -> { where(featured: true) }

    # Filters
    filter :category, as: :select, collection: -> { Category.pluck(:name, :id) }
    filter :author, as: :select, collection: -> { User.pluck(:name, :id) }
    filter :published, as: :boolean
    filter :created_at, as: :date_range

    # Actions
    action :publish, interaction: PublishPost, condition: ->(p) { !p.published? }
    action :unpublish, interaction: UnpublishPost, condition: ->(p) { p.published? }
    action :feature, interaction: FeaturePost, condition: ->(p) { !p.featured? }

    # Associations
    association :comments, fields: [:body, :author, :approved, :created_at]

    # Eager loading
    includes :author, :category, :tags
  end
end
```

### Comment Definition

```ruby
module Blogging
  class CommentDefinition < Plutonium::Resource::Definition
    field :body, as: :text
    field :post, as: :hidden
    field :author, as: :hidden
    field :approved, as: :switch

    column :body
    column :author
    column :approved
    column :created_at

    scope :all, default: true
    scope :approved, -> { where(approved: true) }
    scope :pending, -> { where(approved: false) }, badge: true

    action :approve, interaction: ApproveComment, condition: ->(c) { !c.approved? }
    action :reject, interaction: RejectComment, condition: ->(c) { c.approved? }
  end
end
```

## Interactions

### Publish Post

```ruby
module Blogging
  class PublishPost < Plutonium::Interaction::Base
    presents model_class: Post
    presents label: "Publish"
    presents icon: Phlex::TablerIcons::Send

    validate :has_content

    def execute
      resource.update!(
        published: true,
        published_at: Time.current
      )

      # Notify subscribers
      NotifySubscribersJob.perform_later(resource.id)

      succeed(resource).with_message("Post published!")
    end

    private

    def has_content
      errors.add(:base, "Post must have content") if resource.body.blank?
    end
  end
end
```

### Approve Comment

```ruby
module Blogging
  class ApproveComment < Plutonium::Interaction::Base
    presents model_class: Comment
    presents label: "Approve"

    def execute
      resource.update!(approved: true)

      # Notify comment author
      CommentApprovedMailer.notify(resource).deliver_later

      succeed(resource).with_message("Comment approved")
    end
  end
end
```

## Policies

### Post Policy

```ruby
module Blogging
  class PostPolicy < Plutonium::Resource::Policy
    def read?
      record.published? || author? || admin?
    end

    def create?
      user.present? && (user.author? || user.admin?)
    end

    def update?
      author? || admin?
    end

    def destroy?
      author? || admin?
    end

    def publish?
      (author? || admin?) && !record.published?
    end

    def relation_scope(relation)
      if admin?
        relation
      elsif user&.author?
        relation.where(author: user).or(relation.where(published: true))
      else
        relation.where(published: true)
      end
    end

    private

    def author?
      record.author_id == user&.id
    end

    def admin?
      user&.admin?
    end
  end
end
```

## Portal Configuration

### Admin Portal

Engine:

```ruby
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
  end
end
```

Authentication (in controller concern):

```ruby
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:admin)
```

Admin policy override:

```ruby
# packages/admin_portal/app/policies/admin_portal/blogging/post_policy.rb
module AdminPortal
  module Blogging
    class PostPolicy < ::Blogging::PostPolicy
      def read?
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
end
```

### Public Portal

Engine:

```ruby
module PublicPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
  end
end
```

Authentication (in controller concern):

```ruby
# packages/public_portal/app/controllers/public_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:user)
```

Public policy override:

```ruby
# packages/public_portal/app/policies/public_portal/blogging/post_policy.rb
module PublicPortal
  module Blogging
    class PostPolicy < ::Blogging::PostPolicy
      def create?
        false
      end

      def update?
        false
      end

      def relation_scope(relation)
        relation.published
      end
    end
  end
end
```

## Usage

```bash
# Generate the structure
rails generate pu:pkg:package blogging
rails generate pu:res:scaffold Post title:string slug:string body:text published:boolean --dest=blogging
rails generate pu:res:scaffold Comment body:text approved:boolean post:belongs_to --dest=blogging
rails generate pu:res:scaffold Category name:string slug:string --dest=blogging

# Create portals
rails generate pu:pkg:portal admin
rails generate pu:pkg:portal public

# Connect resources to portal
rails generate pu:res:conn Blogging::Post Blogging::Comment Blogging::Category --dest=admin_portal

rails db:migrate
```

## Next Steps

- Add image uploads with Active Storage
- Implement RSS feeds
- Add social sharing
- Set up full-text search with PostgreSQL
