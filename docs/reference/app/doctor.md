# Doctor

`pu:core:doctor` checks a booted application for Plutonium mistakes that fail silently.

```bash
bin/rails g pu:core:doctor
bin/rails g pu:core:doctor --strict           # warnings fail too
bin/rails g pu:core:doctor --portal=admin_portal
```

It writes nothing. It boots the app, walks every portal's registered resources, and prints what it found. With `--strict` it exits non-zero when anything at all is reported; without it, only errors fail the run.

## What it is for

Plutonium raises wherever it can. Defining `relation_scope` as an instance method raises the moment the method is defined. A `columns:` key copied from a form layout into a display layout raises. Registering a model that never included `Plutonium::Resource::Record` raises.

The doctor covers what is left: code that is legal, runs, and quietly does nothing. That is the rule for every check here, and for any check added later. **If a mistake can be made to raise, it belongs in the framework, not in the doctor.** A raise reaches every application the moment the mistake is written. A check reaches only the people who run it.

## Checks

### `missing_policy_rule` (error)

An action with no `<action>?` on the policy.

```ruby
# PostDefinition
action :publish, interaction: PublishPost, record_action: true

# PostPolicy — nothing about :publish
```

`Action::Base#permitted_by?` asks `policy.allowed_to?(:publish?)`, and ActionPolicy answers `false` for a rule that does not exist rather than raising. The button never renders, and nothing says why.

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def publish? = update?
end
```

Hidden actions are exempt. `hidden: true` means the action renders nowhere, so there is no missing button to explain, and a kanban column's `enter_interaction` is predicate-less by design: `kanban_move?` authorizes the drop.

### `autodetected_permitted_attributes` (error)

A policy that never says which attributes it permits.

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def create? = true
  def read? = true
  # no permitted_attributes_for_create / _read
end
```

`autodetect_permitted_fields` permits every field on the model, and outside development it raises instead. In development it only writes to the log, so this works on the machine it was written on and 500s on deploy.

```ruby
def permitted_attributes_for_create = %i[title body published_at]
def permitted_attributes_for_read = %i[title body published_at author]
```

An entry point the application answers for itself is not reported, even when the base method underneath it is still Plutonium's. A policy defining `permitted_attributes_for_index` and `permitted_attributes_for_show` never reaches `permitted_attributes_for_read`.

### `condition_as_authorization` (warning)

An action whose only user check is its `condition:`.

```ruby
action :publish,
  interaction: PublishPost,
  record_action: true,
  condition: -> { current_user.admin? }   # hides the button

def publish? = update?                     # allows anyone who can update
```

`condition:` decides whether a button renders. The policy decides whether the action may run. The route stays live, so a direct POST reaches the interaction for anyone `publish?` allows.

Both halves have to hold before this reports: the condition reads like an authorization decision, and the policy predicate does not. A predicate that delegates (`def publish? = update?`) counts as not deciding, because it answers a different question than the condition asks. The report quotes the condition so you can judge it at a glance.

Keep the `condition:` if it is also doing presentation work. Move the user check into the policy either way.

### `redundant_field_declaration` (warning)

A `field`, `display`, or `column` declaration carrying no options and no block.

```ruby
field :title      # dead: this is exactly what was already inferred
```

Plutonium renders every permitted attribute from the model already. The surfaces only look declarations up by name while iterating a list that comes from the policy, so a declaration with no options is read and discarded. Declare one when you are overriding something: `as: :markdown`, a `hint:`, a `wrapper:`, a `condition:`, or a block.

To make a field appear or disappear, change `permitted_attributes_for_*` on the policy. A declaration in the definition has no say in it.

`input` is never checked. Its keys are a source list rather than a lookup: nested resource fields, structured inputs and wizard steps all take their field set from `defined_inputs.keys`, so a bare `input :title` is load-bearing there.

## Suppressing a finding

Every check is a judgement about intent, and some of those judgements will be wrong about a particular line. Put a `.plutonium-doctor.yml` in the application root:

```yaml
# Turn a check off entirely.
disable:
  - redundant_field_declaration

# Silence individual findings, by the key the report prints under each one.
ignore:
  - missing_policy_rule:Blogging::Post#publish
```

The report prints each finding's key so the line can be copied straight out of the output.

## Portals

Definitions and policies are resolved the way a request resolves them: portal namespace first, top level as the fallback. A portal that overrides `PostDefinition` with `AdminPortal::PostDefinition` is checked against the class that actually serves the request.

One mistake reached through several portals is reported once, with the portals named. A finding that only exists in one portal, because that portal overrode the definition or the policy, is reported against that portal alone.

## In CI

```yaml
- run: bin/rails g pu:core:doctor --strict
```

Start without `--strict` if an existing app has warnings to work through. Errors fail the run either way.
