# Plutonium: Nuclear ☢️ Reactor Included

[![Ruby](https://github.com/radioactive-labs/plutonium-core/actions/workflows/main.yml/badge.svg)](https://github.com/radioactive-labs/plutonium-core/actions/workflows/main.yml)

**Plutonium** picks up where Rails left off, introducing application level concepts and tooling, transforming the way you build applications with Rails.
It's a culmination of lessons learned from years of developing nearly identical applications and is designed to save you from the drudgery of re-implementation.

**Why Choose Plutonium?**

- **Efficiency by Design:** Plutonium is built for developers who demand efficiency without compromise. It automates 90% of your application needs while giving you the flexibility to tailor the remaining 10% to your specific requirements.
- **Comprehensive Features:** Plutonium covers a wide array of functionalities out of the box:
  - Authentication & Authorization
  - Complete CRUD operations with advanced features: customizable inputs, fields, tables, forms, pagination, actions, search, scopes, filtering, nested resources and much more.
  - Modular architecture leveraging Rails engines for improved packaging and namespacing.
  - Time-saving generators for boilerplate tasks.
- **Omakase with a Twist:** Inspired by Rails' omakase philosophy, Plutonium delivers a convention-based approach but doesn't box you in. It's seamlessly integrated into your project, allowing you to write your application as you would with vanilla Rails but with powerful extensions.
- **MVC and Beyond:** Plutonium adopts the MVC pattern, enhanced with modern web technologies like [hotwire](TODO), to deliver an interactive and robust user experience. It emphasizes progressive enhancement, ensuring a smooth development process and end-user experience.
- **Rails Harmony:** A Plutonium app is a Rails app at its core. It respects and builds upon Rails' conventions, making it intuitive for Rails developers. If you know Rails, learning Plutonium requires only a few new concepts.
- **Effortless Customization:** Plutonium is designed for easy customization to meet your unique requirements. Whether adjusting the functionality of entire resource groups or fine-tuning individual elements, our accessible low-level APIs and the familiar Rails conventions offer unparalleled flexibility. This ensures that any modifications you need to make can be implemented swiftly and smoothly, reducing complexity and enhancing your development experience.
- **Community-Driven Dependencies:** Plutonium stands on the shoulders of giants, integrating with well-established gems chosen for their robustness and flexibility, including:
  - [ActiveInteraction](https://github.com/AaronLasseigne/active_interaction) for business logic
  - [Pagy](https://github.com/ddnexus/pagy) for pagination
  - [Pundit](https://github.com/varvet/pundit) for authorization
  - [Simple Form](https://github.com/heartcombo/simple_form) for forms
  - [Rodauth](https://github.com/jeremyevans/rodauth) (via [rodauth-rails](https://github.com/janko/rodauth-rails)) for authentication. Rodauth is optional, allowing flexibility in choosing your auth solution

## Quick Start

Get Plutonium up and running in your Rails application with these simple steps:

1. **Add Plutonium to your Gemfile:**

```ruby
gem "plutonium"
```

2. **Bundle Install:**

```shell
bundle
```

3. **Install Plutonium:**

```shell
rails g pu:core:install
```

Start building your Rails applications faster, with more flexibility and less boilerplate. **Plutonium** is here to revolutionize your development process.

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/plutonium.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

<!--
# ------------------------------

gem "plutonium", path: "/Users/stefan/code/plutonium/starters/plutonium/"
gem "plutonium_generators", github: "radioactive-labs/plutonium-generators", group: [:development, :test]



# rails new vulcan \
#                --skip-action-mailbox --skip-action-text --skip-active-storage --skip-action-cable --skip-jbuilder \
#                --skip-test --skip-system-test --javascript=esbuild --css=bootstrap --database=postgresql

-->

```bash
rails new pluton8_starter --name="Pluton8 Starter" --database=sqlite3 --skip-action-mailbox --skip-action-text --skip-active-storage --asset-pipeline=propshaft --skip-jbuilder --javascript=importmap --css=tailwind

bin/rails app:template LOCATION=~/template.rb
```
