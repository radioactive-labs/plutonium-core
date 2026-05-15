---
layout: page
sidebar: false
aside: false
---

<SectionLanding
  eyebrow="Guides"
  title="How to do the things Plutonium apps do."
  lede="Task-oriented walkthroughs for the parts of the framework you reach for most."
  mode="categorized"
  :rail="[
    { group: 'Setup & Resources', items: [
      { name: 'Adding resources', link: '/plutonium-core/guides/adding-resources' },
      { name: 'Creating packages', link: '/plutonium-core/guides/creating-packages' },
    ]},
    { group: 'Auth', items: [
      { name: 'Authentication', link: '/plutonium-core/guides/authentication' },
      { name: 'Authorization', link: '/plutonium-core/guides/authorization' },
    ]},
    { group: 'Features', items: [
      { name: 'Custom actions', link: '/plutonium-core/guides/custom-actions' },
      { name: 'Nested resources', link: '/plutonium-core/guides/nested-resources' },
      { name: 'Multi-tenancy', link: '/plutonium-core/guides/multi-tenancy' },
      { name: 'Search & filtering', link: '/plutonium-core/guides/search-filtering' },
      { name: 'User invites', link: '/plutonium-core/guides/user-invites' },
    ]},
    { group: 'Customization', items: [
      { name: 'Theming', link: '/plutonium-core/guides/theming' },
    ]},
    { group: 'Quality', items: [
      { name: 'Testing', link: '/plutonium-core/guides/testing' },
    ]},
  ]"
  :sidebar="[
    { heading: 'New to Plutonium?', items: [
      { label: 'Start with the tutorial', href: '/plutonium-core/getting-started/tutorial/' },
    ]},
    { heading: 'Looking for APIs?', items: [
      { label: 'Browse the reference', href: '/plutonium-core/reference/' },
    ]},
    { heading: 'Need help?', items: [
      { label: 'GitHub Discussions', href: 'https://github.com/radioactive-labs/plutonium-core/discussions' },
    ]},
  ]"
/>
