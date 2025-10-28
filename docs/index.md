---
layout: home

hero:
  name: Plutonium
  text: Rails On Steroids
  tagline: Build enterprise apps at startup speed. Imagine Rails; but faster, smarter and easier to ship.
  image:
    src: /plutonium.png
    alt: Plutonium
  actions:
    - theme: brand
      text: Read The Docs
      link: /documentation/installation/01-installation
    - theme: alt
      text: View Source Code
      link: https://github.com/radioactive-labs/plutonium-core

features:
  - icon: 🚀
    title: Ship 10× Faster
    details: Generators, conventions, and zero-config defaults eliminate boilerplate.
  - icon: 🎯
    title: Enterprise Ready
    details: Multitenancy, RBAC, audit logs, and API mode already built in.
  - icon: 🎨
    title: Beautiful by Default
    details: Modern UI with Tailwind, Hotwire and themeable components that is 100% customizable  with total design freedom.
---

## Stop Writing the Same Code Every Time

Every Rails app starts with the same building blocks: auth, roles, CRUD, API etc.
You’ve written them a hundred times. Why keep writing them **Again and **AGAIN**!**

```erb
<!-- 200+ lines of controllers, views, policies, tests... -->
```

Plutonium turns all that into one command by giving you a production-grade code, generated and ready to ship.

## Just Generate It

With Plutonium, one command gives you production-grade features.

```bash
rails generate plutonium:resource Post title:string body:text published:boolean
```

→ Generates:
Model + Migration + Controller + Views + Policies + Tests + Routes + Stimulus + Tailwind UI

## Before vs After

Without Plutonium - you will have 127 lines of boilerplate:

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy]

  def index
    @posts = Post.all
  end

  # ... 100+ more lines
end
```

With Plutonium - 0 lines to write:

```bash
rails generate plutonium:resource Post
```

→ Done & Deploy-ready!

## 88% Less Code | 79% Faster MVP

Visualize how <span class="gradient-text"> Rails + Plutonium </span> saves you!

| Metric        | Standard Rails | Rails + Plutonium |  Savings   |
| :------------ | :------------: | :---------------: | :--------: |
| Lines of code |     2,110      |        427        |  79% less  |
| Setup time    |     3 days     |      30 mins      | 95% faster |

## Works Everywhere!

**Copy the command that suits you and write 88% less code with Plutonium**

Direct setup via Rails.

```bash
rails new myapp -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

Manual download.

```bash
curl -L https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb -o tmp/plutonium.rb
```

Setup for existing Rails app.

```bash
bin/rails app:template LOCATION=tmp/plutonium.rb
```

<a
href="/documentation/installation/01-installation"
target="\_blank"
rel="noopener noreferrer"
style="
display:inline-block;
padding:10px 20px;
background-color:#ff4d4d;
color:#ffffff;
border-radius:8px;
text-decoration:none;
font-weight:600;
font-size:15px;
transition:all 0.3s ease;
"
onmouseover="this.style.backgroundColor='#e62200ff'"
onmouseout="this.style.backgroundColor='#ff4d4d'">
Full Installation Guide →
</a>

<style>
:root {
  --vp-home-hero-name-color: transparent;
  --vp-home-hero-name-background: -webkit-linear-gradient(120deg, #da8ee7 30%, #5f4dff);

  --vp-home-hero-image-filter: blur(56px);
}

.gradient-text {
  background: linear-gradient(120deg, #da8ee7 30%, #5f4dff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  font-weight: 600;
}

</style>
