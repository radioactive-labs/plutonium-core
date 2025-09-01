# 1. Project Setup

Welcome to the Plutonium tutorial! In this guide, we'll build a complete blog application from scratch.

First, let's get a new Rails application up and running with Plutonium installed.

## Prerequisites

Before you begin, make sure you have the following installed:

- Ruby 3.2.2 or higher
- Rails 7.1 or higher
- Node.js and Yarn

If you're new to Rails, we highly recommend the official [Rails Getting Started Guide](https://guides.rubyonrails.org/getting_started.html) first.

## Create a New Rails App

We'll use the Plutonium Rails template to create a new application. This is the fastest way to get started.

Open your terminal and run the following command:

```bash
rails new plutonium_blog -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

This command creates a new Rails app named `plutonium_blog` and configures it with:
- `propshaft` for assets
- `esbuild` for JavaScript bundling
- `TailwindCSS` for styling
- The base Plutonium gem and configurations

## Explore the Project

Once the command finishes, navigate into your new project's directory:

```bash
cd plutonium_blog
```

The installer has already set up the core files you need. Here are the most important ones for now:

```
plutonium_blog/
├── app/
│   ├── controllers/
│   │   ├── plutonium_controller.rb # Base controller for Plutonium
│   │   └── resource_controller.rb  # Base for all resource controllers
│   └── views/
│       └── layouts/
│           └── resource.html.erb   # Default layout for Plutonium views
├── config/
│   ├── initializers/
│   │   └── plutonium.rb           # Main Plutonium configuration
│   └── packages.rb                # How custom packages are loaded
└── packages/                      # Where you'll build your features
    └── .keep
```

## Start the Server

Let's boot up the Rails server to make sure everything is working correctly.

```bash
bin/dev
```

Open your web browser and navigate to [http://localhost:3000](http://localhost:3000). You should see the default Rails welcome page.

## Next Steps

Congratulations! You have a fresh Plutonium application ready to go.

In the next chapter, we'll create our first **Feature Package** to house all the logic for our blog.
