# Tutorial: Building a Blog

In this tutorial, you'll build a complete blog application with Plutonium. You'll learn:

- How to structure a Plutonium application
- Creating resources with models, definitions, and policies
- Setting up authentication with Rodauth
- Implementing authorization rules
- Adding custom actions with Interactions
- Customizing the UI

## What We'll Build

A blog application with:
- **Posts** - Articles with title, body, and publication status
- **Comments** - Nested under posts
- **Users** - Authors who can manage their own posts
- **Admin Portal** - Full access for administrators
- **Author Portal** - Limited access for content authors

## Prerequisites

- Ruby 3.2+
- Rails 8.0+ (or 7.1+)
- Node.js 18+
- PostgreSQL (or SQLite for development)

## Time Required

This tutorial takes approximately 45-60 minutes to complete.

## Chapters

### [1. Project Setup](./01-setup)
Create a new Plutonium application and understand the project structure.

### [2. Creating Your First Resource](./02-first-resource)
Generate the Post resource with model, definition, policy, and controller.

### [3. Setting Up Authentication](./03-authentication)
Configure Rodauth for user authentication with multiple account types.

### [4. Implementing Authorization](./04-authorization)
Add policies to control who can view, create, edit, and delete posts.

### [5. Adding Custom Actions](./05-custom-actions)
Create a "Publish" action using Interactions for business logic.

### [6. Nested Resources](./06-nested-resources)
Add Comments as a nested resource under Posts.

### [7. Creating an Author Portal](./07-author-portal)
Create a second portal with different access levels for content authors.

### [8. Customizing the UI](./08-customizing-ui)
Customize forms, tables, and views to match your requirements.

## Getting Help

If you get stuck:
- Check the [Guides](/guides/) for detailed explanations
- Browse the [Reference Documentation](/reference/) for API details
- Visit our [GitHub Issues](https://github.com/radioactive-labs/plutonium-core/issues)

Let's get started!

[Begin Chapter 1: Project Setup →](./01-setup)
