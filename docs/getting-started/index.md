# Getting Started

Welcome to Plutonium.

## Prerequisites

- **Ruby 3.2+**
- **Rails 7.2+** (Rails 8 recommended)
- **Node.js 18+** (for asset compilation)
- Basic familiarity with Ruby on Rails

## Pick your starting point

### New Rails app

The fastest way — use the application template:

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

This sets up Rails + Propshaft + esbuild + TailwindCSS + Plutonium in one shot, with Rodauth ready to go.

[→ Installation](./installation)

### Existing Rails app

For pre-existing apps, use `base.rb` (not `plutonium.rb` — that one runs full app bootstrap and clobbers history):

```bash
bin/rails app:template \
  LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb
```

[→ Installation › Existing app](./installation#existing-application)

### Tutorial

Want to learn by building? The [8-step tutorial](./tutorial/) walks through a complete blog app — auth, authorization, custom actions, nested resources, multi-portal.

[→ Tutorial](./tutorial/)

## After installation

1. **Create resources** with `pu:res:scaffold` (see [Adding resources](/guides/adding-resources))
2. **Connect them to a portal** with `pu:res:conn`
3. **Customize** the definition, policy, controller as needed

Reference for each layer: [App](/reference/app/), [Resource](/reference/resource/), [Behavior](/reference/behavior/), [UI](/reference/ui/), [Auth](/reference/auth/), [Tenancy](/reference/tenancy/), [Testing](/reference/testing/).
