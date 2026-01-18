---
layout: home
hero:
  name: Plutonium
  text: Ship Rails Apps 10x Faster
  tagline: Build production-ready Rails applications in hours, not weeks. Convention-driven, fully customizable. Built for the AI era.
  image:
    src: /plutonium.png
    alt: Plutonium
  actions:
    - theme: brand
      text: Get Started →
      link: /getting-started/
    - theme: alt
      text: GitHub
      link: https://github.com/radioactive-labs/plutonium-core
---

<div class="landing-content">

<section class="before-after">
  <h2>The Old Way vs The Plutonium Way</h2>
  <div class="comparison">
    <div class="before">
      <h3>Without Plutonium</h3>
      <div class="file-tree">
        <div class="file">app/controllers/posts_controller.rb</div>
        <div class="file">app/controllers/comments_controller.rb</div>
        <div class="file">app/views/posts/index.html.erb</div>
        <div class="file">app/views/posts/show.html.erb</div>
        <div class="file">app/views/posts/new.html.erb</div>
        <div class="file">app/views/posts/edit.html.erb</div>
        <div class="file">app/views/posts/_form.html.erb</div>
        <div class="file dim">...12 more files</div>
      </div>
      <div class="stats">
        <span>~200 lines</span>
        <span>30+ minutes</span>
        <span>No auth yet</span>
      </div>
    </div>
    <div class="arrow">→</div>
    <div class="after">
      <h3>With Plutonium</h3>

```bash
rails g pu:res:scaffold Post \
  title:string body:text

rails g pu:res:conn Post \
  --dest=admin_portal
```

  <div class="stats success">
    <span>2 commands</span>
    <span>30 seconds</span>
    <span>Auth included</span>
  </div>
    </div>
  </div>
</section>

<section class="ai-section">
  <h2>Built for the AI Era</h2>
  <p class="ai-intro">Plutonium is the first Rails framework designed from the ground up for AI-assisted development. Every pattern, every convention, every file structure is optimized for AI comprehension.</p>

  <div class="ai-features">
    <div class="ai-feature">
      <div class="ai-icon">🧠</div>
      <h3>Claude Code Skills</h3>
      <p>20+ built-in skills teach AI assistants your app's patterns. Resources, policies, definitions, interactions - Claude understands them all.</p>
    </div>
    <div class="ai-feature">
      <div class="ai-icon">⚡</div>
      <h3>Predictable Patterns</h3>
      <p>Convention-heavy architecture means AI can accurately predict file locations, naming, and relationships. Less hallucination, more precision.</p>
    </div>
    <div class="ai-feature">
      <div class="ai-icon">🔄</div>
      <h3>Generate & Iterate</h3>
      <p>Tell Claude what you need. It generates the scaffold, policy, and definition. You refine. Ship in minutes what used to take hours.</p>
    </div>
  </div>

  <div class="ai-example">
    <div class="ai-prompt">
      <span class="prompt-label">You say:</span>
      <p>"Add a blog with posts and comments. Posts belong to users. Only authors can edit their posts. Add a publish action."</p>
    </div>
    <div class="ai-result">
      <span class="result-label">Claude generates:</span>
      <p>Model, migration, policy, definition, interaction, and connects it to your portal. Ready to customize.</p>
    </div>
  </div>
</section>

<section class="features-detailed">
  <h2>Everything You Need, Nothing You Don't</h2>

  <div class="feature-row">
    <div class="feature-text">
      <h3>Policies Control Access</h3>
      <p>Define who can do what. Attribute-level permissions. Automatic scoping. No more <code>if current_user.admin?</code> scattered everywhere.</p>
    </div>
    <div class="feature-code">

```ruby
class PostPolicy < ResourcePolicy
  def update?
    record.author == user || user.admin?
  end

  def permitted_attributes_for_create
    %i[title body]
  end
end
```

  </div>
  </div>

  <div class="feature-row reverse">
    <div class="feature-text">
      <h3>Definitions Control UI</h3>
      <p>Declare how fields render. Add search, filters, scopes. Custom actions. All in one place.</p>
    </div>
    <div class="feature-code">

```ruby
class PostDefinition < ResourceDefinition
  input :body, as: :markdown

  search do |scope, query|
    scope.where("title ILIKE ?", "%#{query}%")
  end

  scope :published
  scope :drafts

  action :publish, interaction: PublishPost
end
```

  </div>
  </div>

  <div class="feature-row">
    <div class="feature-text">
      <h3>Interactions Encapsulate Logic</h3>
      <p>Complex actions become simple classes. Validated inputs. Clear outcomes. Easy to test.</p>
    </div>
    <div class="feature-code">

```ruby
class PublishPost < ResourceInteraction
  attribute :resource
  attribute :publish_at, :datetime

  def execute
    resource.published_at = publish_at
    if resource.save
      succeed(resource).with_message("Published!")
    else
      failed(resource.errors)
    end
  end
end
```

  </div>
  </div>
</section>

<section class="feature-grid">
  <div class="grid-item">
    <div class="icon">📦</div>
    <h3>Modular Packages</h3>
    <p>Split your app into Feature Packages and Portals. Each isolated, testable, and reusable.</p>
  </div>
  <div class="grid-item">
    <div class="icon">🔐</div>
    <h3>Auth Built In</h3>
    <p>Rodauth integration with login, registration, 2FA, and password reset. Ready in one command.</p>
  </div>
  <div class="grid-item">
    <div class="icon">🏢</div>
    <h3>Multi-Tenancy</h3>
    <p>Entity scoping works out of the box. Path-based or custom strategies. Data isolation guaranteed.</p>
  </div>
  <div class="grid-item">
    <div class="icon">🎨</div>
    <h3>Fully Customizable</h3>
    <p>Override any layer. Custom views with Phlex. Your CSS. No black boxes.</p>
  </div>
</section>

<section class="cta-section">
  <h2>Ready to Build Faster?</h2>
  <p>Get a complete admin interface running in under 5 minutes.</p>
  <div class="cta-buttons">
    <a href="./getting-started/" class="cta-primary">Get Started</a>
    <a href="./getting-started/tutorial/" class="cta-secondary">Follow the Tutorial</a>
  </div>
</section>

</div>
