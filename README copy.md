# Plutonium

Plutonium is a rapid application development toolkit built on top of rails. It is a generator based framework that gives you full control over your application.

It builds upon years of frustration re-implementing almost identical applications over and over.

After trying out lots of dashboard gems and starter kits, we always found them lacking.
Either they did way too much and customizing them was close to impossible, or they did too little and were still had to customize.

We set out to solve a one problem.

Create something that did 90% of what we wanted, while allowing us the freedom of achieving the remainder.

Plutonium takes care of

1. Authentication
2. Authorization
3. CRUD including tables, details, forms, pagination, actions, fully customizable fields and inputs, scopes, search and filtering, routing, nested resources etc.
4. Modularizating i.e it includes a packaging system based on rails engines and adds improved namespacing supporting
5. Advanced generators to handle repetitive tasks

# Design Choices

Like Rails itself, Plutonium is [omakase](https://dhh.dk/2012/rails-is-omakase.html).
We provide a few conventions outside of which you are able to write your application just like you would a normal rails app.

While traditional admin dashboard tools ship as a rails engine, Plutonium integrates into your project, generating integration points to the core library. Similar to how Rails provides an Application which inherits ActiveRecord::Base, Plutonium adds a few base classes. This is the cost of plugging the leak in the abstraction.

Plutonium is MVC. It is the most productive way to build that I have found. Coupled with [hotwire](TODO), we are able to build an interactive,responsive and extremely robust functionality. Most of our features are progressively enhanced, allowing them to be used with hotwire turned off. Features requiring hotwire will be indicated.

The same principle of progressive enhancement applies to how features are built. Features start as basic plumbing, exposing a fully customizable api. The framework then builds nicer layers on top of this. This makes us consumers of our own api forcing us to improve upon it when we hit a roadblock. If you can't do it, that means we can't do it either. Let us know, we are committed to improving customizability.

A Plutonium app is a rails app. We reuse the same patterns used for controllers, routing and models. If you know rails, picking up plutonium requires only learning a few new concepts.

Rails does an amazing number of things right. Especially around view resolution and how it handles inheritance.
We have leveraged this such that you can apply customizations granularly, from groups of resources to individual resources.
If you don't like how we do something, easy, override a method or a view and voila.

A lot of our functionality is built on and inspired by gems we carefully considered for robustness and customizability.

- [ActiveInteraction](https://github.com/AaronLasseigne/active_interaction): 💼 Manage application specific business logic. Powers [actions](TODO).
- [Pagy](https://github.com/ddnexus/pagy): 🏆 The Best Pagination Ruby Gem 🥇. Powers [collection view](TODO)
- [Action Policy](https://actionpolicy.evilmartians.io/): Authorization framework for Ruby and Rails. Composable. Extensible. Performant. Powers [authorization](TODO).
- [Simple Form](https://github.com/heartcombo/simple_form): Forms made easy for Rails! It's tied to a simple DSL, with no opinion on markup. Powers [inputs](TODO). Heavily inspired the fields api 💡💡💡.
- [Rodauth\*](https://github.com/jeremyevans/rodauth): Ruby's Most Advanced Authentication Framework. Used via the [rodauth-rails](https://github.com/janko/rodauth-rails) gem. Powers [authentication](TODO). \*Rodauth is optional. You can bring your own auth.

## Installation

Add to your gemfile

    gem "plutonium", github: "radioactive-labs/plutonium-core"
    gem "plutonium_generators", github: "radioactive-labs/plutonium-generators", group: [:development, :test]

<!--
gem "plutonium", path: "/Users/stefan/code/plutonium/starters/plutonium/"
gem "plutonium_generators", path: "/Users/stefan/code/plutonium/plutonium_generators", group: [:development, :test]
-->

Install new gems

    bundle

Setup Plutonium in your application

    rails g pu:core:install

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/plutonium.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
