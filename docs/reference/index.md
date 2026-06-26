---
layout: page
sidebar: false
aside: false
---

<SectionLanding
  eyebrow="Reference"
  title="Every API, in one place."
  lede="The full surface area of Plutonium — controllers, policies, definitions, fields, interactions, generators."
  mode="categorized"
  :rail="[
    { group: 'App', items: [
      { name: 'Overview', link: '/plutonium-core/reference/app/' },
      { name: 'Packages', link: '/plutonium-core/reference/app/packages' },
      { name: 'Portals', link: '/plutonium-core/reference/app/portals' },
      { name: 'Generators', link: '/plutonium-core/reference/app/generators' },
    ]},
    { group: 'Resource', items: [
      { name: 'Overview', link: '/plutonium-core/reference/resource/' },
      { name: 'Model', link: '/plutonium-core/reference/resource/model' },
      { name: 'Definition', link: '/plutonium-core/reference/resource/definition' },
      { name: 'Query', link: '/plutonium-core/reference/resource/query' },
      { name: 'Actions', link: '/plutonium-core/reference/resource/actions' },
    ]},
    { group: 'Behavior', items: [
      { name: 'Overview', link: '/plutonium-core/reference/behavior/' },
      { name: 'Controllers', link: '/plutonium-core/reference/behavior/controllers' },
      { name: 'Policies', link: '/plutonium-core/reference/behavior/policies' },
      { name: 'Interactions', link: '/plutonium-core/reference/behavior/interactions' },
    ]},
    { group: 'UI', items: [
      { name: 'Overview', link: '/plutonium-core/reference/ui/' },
      { name: 'Pages', link: '/plutonium-core/reference/ui/pages' },
      { name: 'Forms', link: '/plutonium-core/reference/ui/forms' },
      { name: 'Displays', link: '/plutonium-core/reference/ui/displays' },
      { name: 'Tables', link: '/plutonium-core/reference/ui/tables' },
      { name: 'Components', link: '/plutonium-core/reference/ui/components' },
      { name: 'Layouts', link: '/plutonium-core/reference/ui/layouts' },
      { name: 'Assets', link: '/plutonium-core/reference/ui/assets' },
    ]},
    { group: 'Wizard', items: [
      { name: 'Overview', link: '/plutonium-core/reference/wizard/' },
      { name: 'DSL', link: '/plutonium-core/reference/wizard/dsl' },
      { name: 'Anchoring & resume', link: '/plutonium-core/reference/wizard/anchoring-resume' },
      { name: 'Storage & config', link: '/plutonium-core/reference/wizard/storage-config' },
      { name: 'Registration & launch', link: '/plutonium-core/reference/wizard/registration-launch' },
      { name: 'One-time', link: '/plutonium-core/reference/wizard/one-time' },
    ]},
    { group: 'Auth', items: [
      { name: 'Overview', link: '/plutonium-core/reference/auth/' },
      { name: 'Accounts', link: '/plutonium-core/reference/auth/accounts' },
      { name: 'Profile', link: '/plutonium-core/reference/auth/profile' },
    ]},
    { group: 'Tenancy', items: [
      { name: 'Overview', link: '/plutonium-core/reference/tenancy/' },
      { name: 'Entity scoping', link: '/plutonium-core/reference/tenancy/entity-scoping' },
      { name: 'Nested resources', link: '/plutonium-core/reference/tenancy/nested-resources' },
      { name: 'Invites', link: '/plutonium-core/reference/tenancy/invites' },
    ]},
    { group: 'Kanban', items: [
      { name: 'Overview', link: '/plutonium-core/reference/kanban/' },
      { name: 'DSL', link: '/plutonium-core/reference/kanban/dsl' },
      { name: 'Positioning', link: '/plutonium-core/reference/kanban/positioning' },
      { name: 'Authorization', link: '/plutonium-core/reference/kanban/authorization' },
    ]},
    { group: 'Testing', items: [
      { name: 'Overview', link: '/plutonium-core/reference/testing/' },
    ]},
  ]"
  :sidebar="[
    { heading: 'Learning?', items: [
      { label: 'Tutorial', href: '/plutonium-core/getting-started/tutorial/' },
    ]},
    { heading: 'Solving a problem?', items: [
      { label: 'Guides', href: '/plutonium-core/guides/' },
    ]},
    { heading: 'Need help?', items: [
      { label: 'GitHub Discussions', href: 'https://github.com/radioactive-labs/plutonium-core/discussions' },
    ]},
  ]"
/>
