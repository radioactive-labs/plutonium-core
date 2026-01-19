# Getting Started

Welcome to Plutonium! This guide will help you get up and running quickly.

## What You'll Learn

- How to install Plutonium in a new or existing Rails application
- The basic concepts behind Plutonium's architecture
- How to create your first resource and connect it to a portal

## Prerequisites

Before you begin, make sure you have:

- **Ruby 3.2+** installed
- **Rails 7.2+** (Rails 8 recommended)
- **Node.js 18+** (for asset compilation)
- Basic familiarity with Ruby on Rails

## Choose Your Path

### New Application

If you're starting fresh, use our application template:

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

This creates a fully configured Plutonium application with authentication ready to go.

[Continue to Installation →](./installation)

### Existing Application

Adding Plutonium to an existing Rails app requires a few more steps but is fully supported.

[Continue to Installation →](./installation#existing-application)

### Tutorial

Want to learn by building? Follow our step-by-step tutorial to create a complete blog application.

[Start the Tutorial →](./tutorial/)

## Next Steps

After installation, you'll typically:

1. **Create a Feature Package** - Organize your business logic
2. **Generate Resources** - Create your models and scaffolds
3. **Create a Portal** - Set up the web interface
4. **Connect Resources** - Make resources accessible through the portal
5. **Customize** - Override defaults as needed

Each of these steps is covered in detail in the [Tutorial](./tutorial/).
