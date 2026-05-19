---
layout: page
sidebar: false
aside: false
---

<SectionLanding
  eyebrow="Getting Started"
  title="Learn Plutonium by building."
  lede="Walk the path top to bottom, or skip to the part you need."
  mode="numbered"
  :rail="[
    { name: 'Project setup', desc: 'Bootstrap a Rails app with the Plutonium template.', link: '/plutonium-core/getting-started/tutorial/01-setup' },
    { name: 'First resource', desc: 'Model, definition, scaffold, connect to a portal.', link: '/plutonium-core/getting-started/tutorial/02-first-resource' },
    { name: 'Authentication', desc: 'Add Rodauth with login + signup.', link: '/plutonium-core/getting-started/tutorial/03-authentication' },
    { name: 'Authorization', desc: 'ActionPolicy-scoped resource access.', link: '/plutonium-core/getting-started/tutorial/04-authorization' },
    { name: 'Custom actions', desc: 'Add a domain-specific action to a resource.', link: '/plutonium-core/getting-started/tutorial/05-custom-actions' },
    { name: 'Nested resources', desc: 'Posts → Comments, scoped through routing.', link: '/plutonium-core/getting-started/tutorial/06-nested-resources' },
    { name: 'Author portal', desc: 'A second portal with its own auth and pages.', link: '/plutonium-core/getting-started/tutorial/07-author-portal' },
    { name: 'Customizing UI', desc: 'Theme tokens, custom Phlex components, layouts.', link: '/plutonium-core/getting-started/tutorial/08-customizing-ui' },
  ]"
  :sidebar="[
    { heading: 'Already know your way around?', items: [
      { label: 'Installation', href: '/plutonium-core/getting-started/installation', note: 'bootstrap a new app' },
      { label: 'Concepts overview', href: '/plutonium-core/reference/' },
      { label: 'Generators reference', href: '/plutonium-core/reference/app/generators' },
    ]},
    { heading: 'Need help?', items: [
      { label: 'GitHub Discussions', href: 'https://github.com/radioactive-labs/plutonium-core/discussions' },
      { label: 'Open an issue', href: 'https://github.com/radioactive-labs/plutonium-core/issues' },
    ]},
  ]"
/>
