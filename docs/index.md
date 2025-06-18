---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: Plutonium
  text: The Rails RAD Toolkit
  tagline: Build feature-rich, enterprise-ready applications at lightning speed. Stop writing boilerplate, start building features.
  image:
    src: /plutonium.png
    alt: Plutonium
  actions:
    - theme: brand
      text: Start the Tutorial
      link: /guide/tutorial/01-project-setup
    - theme: alt
      text: Core Concepts
      link: /guide/introduction/02-core-concepts

features:
  - icon: 🚀
    title: Unmatched Developer Experience
    details: Smart generators, convention-over-configuration, and intelligent defaults let you focus on what matters.
  - icon: 🏗️
    title: Robust Architecture
    details: Built-in multitenancy, modular packages, and advanced authorization provide a solid foundation for any project.
  - icon: 🎨
    title: Flexible UI & Theming
    details: Start with a beautiful, modern UI out-of-the-box, then customize any aspect with a powerful and expressive API.

---

<style>
:root {
  --vp-home-hero-name-color: transparent;
  --vp-home-hero-name-background: -webkit-linear-gradient(120deg, #da8ee7 30%, #5f4dff);

  --vp-home-hero-image-filter: blur(56px);
}
</style>
