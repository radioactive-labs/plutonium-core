# 2. Creating a Feature Package

Now that we have our Rails application, it's time to start organizing our code. In Plutonium, we do this using **Packages**.

## What are Packages?

Packages are like mini-Rails applications (Rails Engines) that live inside your main app. They help you group related code together, making your application more modular and easier to maintain.

There are two main types of packages, but for now, we'll focus on **Feature Packages**.

A **Feature Package** holds all the business logic for a specific feature. In our case, we'll create a `Blogging` package to hold everything related to blog posts and comments.

## Generate the Package

Plutonium comes with a generator to create feature packages. Run the following command in your terminal:

```bash
rails generate pu:pkg:package blogging
```

This command creates a new directory at `packages/blogging` with the structure for your new package.

```
packages/
└── blogging/
    ├── app/
    │   ├── controllers/
    │   │   └── blogging/           # Controllers for this package
    │   ├── definitions/
    │   │   └── blogging/           # Resource definitions
    │   ├── interactions/
    │   │   └── blogging/           # Business logic actions
    │   ├── models/
    │   │   └── blogging/           # ActiveRecord models
    │   └── policies/
    │       └── blogging/           # Authorization policies
    └── lib/
        └── engine.rb             # The engine configuration
```

Every file and class inside this package will be automatically namespaced under the `Blogging` module to prevent conflicts with other parts of your application.

## Next Steps

With our `Blogging` package in place, we're ready to define the core data models for our application. In the next chapter, we'll create the `Post` and `Comment` resources.
