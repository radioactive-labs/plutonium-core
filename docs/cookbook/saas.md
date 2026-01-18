# Recipe: SaaS Application

Build a multi-tenant SaaS application with organizations, team management, and role-based access.

## Overview

This recipe covers:
- Multi-tenant data isolation
- Organization and team management
- Role-based permissions
- Invitation system
- Subscription tiers

## Architecture

```
packages/
├── core/               # Shared: users, organizations
├── projects/           # Feature: project management
├── billing/            # Feature: subscriptions
├── app_portal/         # Main application interface
└── admin_portal/       # Super admin interface
```

## Core Models

### Organization

```ruby
module Core
  class Organization < Core::ResourceRecord
    has_many :memberships, dependent: :destroy
    has_many :users, through: :memberships
    has_many :projects, class_name: 'Projects::Project'

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true

    before_validation :generate_slug, on: :create

    def owner
      memberships.find_by(role: 'owner')&.user
    end

    private

    def generate_slug
      self.slug ||= name&.parameterize
    end
  end
end
```

### Membership

```ruby
module Core
  class Membership < Core::ResourceRecord
    belongs_to :organization
    belongs_to :user

    ROLES = %w[owner admin member viewer].freeze

    validates :role, presence: true, inclusion: { in: ROLES }
    validates :user_id, uniqueness: { scope: :organization_id }

    scope :admins, -> { where(role: %w[owner admin]) }

    def admin?
      role.in?(%w[owner admin])
    end

    def owner?
      role == 'owner'
    end
  end
end
```

### User Extensions

```ruby
class User < ApplicationRecord
  has_many :memberships, class_name: 'Core::Membership'
  has_many :organizations, through: :memberships

  def role_in(organization)
    memberships.find_by(organization: organization)&.role
  end

  def admin_of?(organization)
    memberships.admins.exists?(organization: organization)
  end

  def member_of?(organization)
    memberships.exists?(organization: organization)
  end
end
```

## Multi-Tenant Setup

### Project Model

```ruby
module Projects
  class Project < Core::ResourceRecord
    belongs_to :organization, class_name: 'Core::Organization'
    belongs_to :creator, class_name: 'User'
    has_many :tasks, dependent: :destroy

    validates :name, presence: true
  end
end
```

### Portal Engine

```ruby
module AppPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      # Scope all data to current organization
      scope_to_entity Core::Organization
    end
  end
end
```

### Portal Authentication

```ruby
# packages/app_portal/app/controllers/app_portal/concerns/controller.rb
module AppPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:user)
    end
  end
end
```

### Organization Context

```ruby
module AppPortal
  class ResourceController < Plutonium::Portal::ResourceController
    before_action :set_current_organization

    private

    def set_current_organization
      @current_organization = current_user.organizations.find_by!(
        slug: params[:org_slug]
      )
    rescue ActiveRecord::RecordNotFound
      redirect_to select_organization_path
    end

    def current_organization
      @current_organization
    end
    helper_method :current_organization

    def current_membership
      @current_membership ||= current_user.memberships.find_by(
        organization: current_organization
      )
    end
    helper_method :current_membership
  end
end
```

## Role-Based Policies

### Project Policy

```ruby
module Projects
  class ProjectPolicy < Plutonium::Resource::Policy
    def read?
      member?
    end

    def create?
      admin?
    end

    def update?
      admin? || creator?
    end

    def destroy?
      owner?
    end

    def permitted_attributes_for_create
      [:name, :description]
    end

    def permitted_attributes_for_update
      if admin?
        [:name, :description, :status, :archived]
      else
        [:description]
      end
    end

    # Entity scope handles organization filtering automatically
    # Add role-based filtering here
    def relation_scope(relation)
      if viewer?
        relation.where(archived: false)
      else
        relation
      end
    end

    private

    def membership
      @membership ||= context[:membership] ||
        user.memberships.find_by(organization: record.organization)
    end

    def member?
      membership.present?
    end

    def viewer?
      membership&.role == 'viewer'
    end

    def admin?
      membership&.admin?
    end

    def owner?
      membership&.owner?
    end

    def creator?
      record.creator_id == user.id
    end
  end
end
```

## Invitation System

### Invitation Model

```ruby
module Core
  class Invitation < Core::ResourceRecord
    belongs_to :organization
    belongs_to :inviter, class_name: 'User'
    belongs_to :user, optional: true  # Set when accepted

    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :role, presence: true, inclusion: { in: Membership::ROLES - ['owner'] }
    validates :token, presence: true, uniqueness: true

    before_validation :generate_token, on: :create

    scope :pending, -> { where(accepted_at: nil, expired_at: nil) }

    def pending?
      accepted_at.nil? && !expired?
    end

    def expired?
      expired_at.present? || created_at < 7.days.ago
    end

    def accept!(user)
      transaction do
        update!(accepted_at: Time.current, user: user)
        organization.memberships.create!(user: user, role: role)
      end
    end

    private

    def generate_token
      self.token ||= SecureRandom.urlsafe_base64(32)
    end
  end
end
```

### Invite User Interaction

```ruby
module Core
  class InviteUser < Plutonium::Interaction::Base
    presents model_class: Organization
    presents label: "Invite Team Member"

    attribute :email, :string
    attribute :role, :string

    validates :email, presence: true
    validates :role, presence: true, inclusion: { in: Membership::ROLES - ['owner'] }
    validate :not_already_member

    def execute
      invitation = resource.invitations.create!(
        email: email,
        role: role,
        inviter: context[:user]
      )

      InvitationMailer.invite(invitation).deliver_later

      succeed(resource)
        .with_message("Invitation sent to #{email}")
    end

    private

    def not_already_member
      if resource.users.exists?(email: email)
        errors.add(:email, "is already a member")
      end
    end
  end
end
```

## Organization Switcher

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/org/select', to: 'organizations#select', as: :select_organization
  post '/org/switch/:id', to: 'organizations#switch', as: :switch_organization

  scope '/:org_slug' do
    mount AppPortal::Engine, at: '/app'
  end
end
```

### Controller

```ruby
class OrganizationsController < ApplicationController
  before_action :authenticate_user!

  def select
    @organizations = current_user.organizations
  end

  def switch
    organization = current_user.organizations.find(params[:id])
    session[:current_organization_id] = organization.id
    redirect_to app_root_path(org_slug: organization.slug)
  end
end
```

## Definitions

### Organization Definition

```ruby
module Core
  class OrganizationDefinition < Plutonium::Resource::Definition
    field :name
    field :slug, readonly: true
    field :logo, as: :file, accept: "image/*"

    column :name, sortable: true
    column :members_count do |org|
      org.memberships.count
    end
    column :created_at

    association :memberships, fields: [:user, :role, :created_at]

    action :invite, interaction: InviteUser
  end
end
```

### Membership Definition

```ruby
module Core
  class MembershipDefinition < Plutonium::Resource::Definition
    field :user
    field :role, as: :select, collection: Membership::ROLES

    column :user
    column :role
    column :created_at

    action :change_role, interaction: ChangeMemberRole
    action :remove, interaction: RemoveMember, color: :danger
  end
end
```

## Subscription Integration

### Plan Model

```ruby
module Billing
  class Plan < Core::ResourceRecord
    has_many :subscriptions

    validates :name, presence: true
    validates :price_cents, presence: true
    validates :max_projects, presence: true
    validates :max_members, presence: true

    has_cents :price
  end
end
```

### Subscription Checks

```ruby
module Core
  class Organization < Core::ResourceRecord
    has_one :subscription, class_name: 'Billing::Subscription'

    def can_add_project?
      projects.count < subscription.plan.max_projects
    end

    def can_add_member?
      memberships.count < subscription.plan.max_members
    end
  end
end

# In policy
def create?
  admin? && record.organization.can_add_project?
end
```

## Usage

```bash
# Create packages
rails generate pu:pkg:package core
rails generate pu:pkg:package projects
rails generate pu:pkg:package billing
rails generate pu:pkg:portal app

# Generate models
rails generate pu:res:scaffold Organization name:string slug:string --package core
rails generate pu:res:scaffold Membership role:string organization:belongs_to user:belongs_to --package core
rails generate pu:res:scaffold Project name:string organization:belongs_to --package projects

# Connect to portal
rails generate pu:res:conn Project --package projects --portal app

rails db:migrate
```

## Security Checklist

- [ ] All models scoped to organization
- [ ] Policies check membership
- [ ] Invitations expire
- [ ] Role changes audited
- [ ] Owner cannot be removed
- [ ] Data isolated in queries
