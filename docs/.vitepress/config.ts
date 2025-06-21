import { defineConfig } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid";

const base = "/plutonium-core/"

// https://vitepress.dev/reference/site-config
export default defineConfig(withMermaid({
  base: base,
  title: "Plutonium",
  description: "The Ultimate Rapid Application Development Toolkit (RADKit) for Rails",
  head: [["link", { rel: "icon", href: `${base}favicon.ico` }]],
  ignoreDeadLinks: 'localhostLinks',
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: "/plutonium.png",
    search: {
      provider: 'local'
    },
    nav: [
      { text: "Home", link: "/" },
      { text: "Guide", link: "/guide/introduction/01-what-is-plutonium" },
      { text: "Tutorial", link: "/guide/tutorial/01-project-setup" },
      { text: "Modules", link: "/modules/" },
      { text: "Demo", link: "https://plutonium-app.onrender.com/" }
    ],
    sidebar: {
      '/guide/': [
        {
          text: "Getting Started",
          items: [
            { text: "Installation", link: "/guide/getting-started/01-installation" },
          ]
        },
        {
          text: "Introduction",
          items: [
            { text: "What is Plutonium?", link: "/guide/introduction/01-what-is-plutonium" },
            { text: "Core Concepts", link: "/guide/introduction/02-core-concepts" },
          ]
        },
        {
          text: "Tutorial (Building a Blog)",
          collapsed: false,
          items: [
            { text: "1. Project Setup", link: "/guide/tutorial/01-project-setup" },
            { text: "2. Creating a Feature Package", link: "/guide/tutorial/02-creating-a-feature-package" },
            { text: "3. Defining Resources", link: "/guide/tutorial/03-defining-resources" },
            { text: "4. Creating a Portal", link: "/guide/tutorial/04-creating-a-portal" },
            { text: "5. Customizing the UI", link: "/guide/tutorial/05-customizing-the-ui" },
            { text: "6. Adding Custom Actions", link: "/guide/tutorial/06-adding-custom-actions" },
            { text: "7. Implementing Authorization", link: "/guide/tutorial/07-implementing-authorization" },
          ]
        },
        {
          text: "Deep Dive",
          items: [
            { text: "Resources", link: "/guide/deep-dive/resources" },
            { text: "Authorization", link: "/guide/deep-dive/authorization" },
            { text: "Modules", link: "/modules/" },
          ]
        },
        {
          text: "Developer Tools",
          items: [
            { text: "Cursor Rules", link: "/guide/cursor-rules" },
          ]
        }
      ],
      '/modules/': [
        {
          text: "Modules",
          items: [
            { text: "Overview", link: "/modules/" },
            { text: "Action", link: "/modules/action" },
            { text: "Authentication", link: "/modules/authentication" },
            { text: "Configuration", link: "/modules/configuration" },
            { text: "Core", link: "/modules/core" },
            { text: "Definition", link: "/modules/definition" },
            { text: "Display", link: "/modules/display" },
            { text: "Form", link: "/modules/form" },
            { text: "Generator", link: "/modules/generator" },
            { text: "Interaction", link: "/modules/interaction" },
            { text: "Package", link: "/modules/package" },
            { text: "Policy", link: "/modules/policy" },
            { text: "Portal", link: "/modules/portal" },
            { text: "Query", link: "/modules/query" },
            { text: "Resource Record", link: "/modules/resource_record" },
            { text: "Routing", link: "/modules/routing" },
            { text: "Table", link: "/modules/table" },
            { text: "UI", link: "/modules/ui" },
          ]
        }
      ]
    },
    socialLinks: [
      { icon: "github", link: "https://github.com/radioactive-labs/plutonium-core" }
    ],
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024-present Stefan Froelich'
    }
  },
  cleanUrls: true,
}))
