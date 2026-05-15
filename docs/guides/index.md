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
      { name: 'User profile', link: '/plutonium-core/guides/user-profile' },
      { name: 'User invites', link: '/plutonium-core/guides/user-invites' },
    ]},
    { group: 'Features', items: [
      { name: 'Custom actions', link: '/plutonium-core/guides/custom-actions' },
      { name: 'Nested resources', link: '/plutonium-core/guides/nested-resources' },
      { name: 'Multi-tenancy', link: '/plutonium-core/guides/multi-tenancy' },
      { name: 'Search & filtering', link: '/plutonium-core/guides/search-filtering' },
    ]},
    { group: 'Customization', items: [
      { name: 'Theming', desc: 'Colors, branding, and design-token overrides.', link: '/plutonium-core/guides/theming' },
      { name: 'Pages', desc: 'Override page classes, add hooks, swap chrome.', link: '/plutonium-core/reference/ui/pages' },
      { name: 'Forms', desc: 'Custom layouts, sections, field tags, themes.', link: '/plutonium-core/reference/ui/forms' },
      { name: 'Displays & tables', desc: 'Custom show-page displays and index tables.', link: '/plutonium-core/reference/ui/displays' },
      { name: 'Components', desc: 'Built-in Phlex kit and writing your own.', link: '/plutonium-core/reference/ui/components' },
      { name: 'Layouts & shell', desc: 'Eject and override the chrome per portal.', link: '/plutonium-core/reference/ui/layouts' },
      { name: 'Assets, Tailwind, Stimulus', desc: 'plutoniumTailwindConfig, .pu-* classes, controllers.', link: '/plutonium-core/reference/ui/assets' },
    ]},
    { group: 'Quality', items: [
      { name: 'Testing', link: '/plutonium-core/guides/testing' },
      { name: 'Troubleshooting', link: '/plutonium-core/guides/troubleshooting' },
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
