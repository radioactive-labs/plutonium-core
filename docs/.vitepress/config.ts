import { defineConfig } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid";

const base = "/plutonium-core/"

// https://vitepress.dev/reference/site-config
export default defineConfig(withMermaid({
  base: base,
  title: "Plutonium",
  description: "Build production-ready Rails apps in minutes, not days",
  head: [
    ["link", { rel: "icon", href: `${base}favicon.ico` }],
    ["meta", { property: "og:type", content: "website" }],
    ["meta", { property: "og:title", content: "Plutonium - Build Production-Ready Rails Apps in Minutes" }],
    ["meta", { property: "og:description", content: "Build production-ready Rails applications in minutes, not days. Convention-driven, fully customizable. Built for the AI era." }],
    ["meta", { property: "og:image", content: "https://radioactive-labs.github.io/plutonium-core/og-image.png" }],
    ["meta", { property: "og:url", content: "https://radioactive-labs.github.io/plutonium-core/" }],
    ["meta", { name: "twitter:card", content: "summary_large_image" }],
    ["meta", { name: "twitter:title", content: "Plutonium - Build Production-Ready Rails Apps in Minutes" }],
    ["meta", { name: "twitter:description", content: "Build production-ready Rails applications in minutes, not days. Convention-driven, fully customizable. Built for the AI era." }],
    ["meta", { name: "twitter:image", content: "https://radioactive-labs.github.io/plutonium-core/og-image.png" }],
  ],
  ignoreDeadLinks: 'localhostLinks',
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: "/plutonium.png",
    search: {
      provider: 'local'
    },
    nav: [
      { text: "Home", link: "/" },
      { text: "Getting Started", link: "/getting-started/" },
      { text: "Guides", link: "/guides/" },
      { text: "Reference", link: "/reference/" },
      { text: "Cookbook", link: "/cookbook/" },
      { text: "Demo", link: "https://github.com/radioactive-labs/plutonium-core/tree/master/test/dummy" }
    ],
    sidebar: {
      '/getting-started/': [
        {
          text: "Getting Started",
          items: [
            { text: "Overview", link: "/getting-started/" },
            { text: "Installation", link: "/getting-started/installation" },
          ]
        },
        {
          text: "Tutorial: Building a Blog",
          collapsed: false,
          items: [
            { text: "Overview", link: "/getting-started/tutorial/" },
            { text: "1. Project Setup", link: "/getting-started/tutorial/01-setup" },
            { text: "2. First Resource", link: "/getting-started/tutorial/02-first-resource" },
            { text: "3. Authentication", link: "/getting-started/tutorial/03-authentication" },
            { text: "4. Authorization", link: "/getting-started/tutorial/04-authorization" },
            { text: "5. Custom Actions", link: "/getting-started/tutorial/05-custom-actions" },
            { text: "6. Nested Resources", link: "/getting-started/tutorial/06-nested-resources" },
            { text: "7. Customizing UI", link: "/getting-started/tutorial/07-customizing-ui" },
          ]
        }
      ],
      '/concepts/': [
        {
          text: "Core Concepts",
          items: [
            { text: "Overview", link: "/concepts/" },
            { text: "Architecture", link: "/concepts/architecture" },
            { text: "Resources", link: "/concepts/resources" },
            { text: "Packages & Portals", link: "/concepts/packages-portals" },
            { text: "Auto-Detection", link: "/concepts/auto-detection" },
          ]
        }
      ],
      '/guides/': [
        {
          text: "Guides",
          items: [
            { text: "Overview", link: "/guides/" },
          ]
        },
        {
          text: "Setup & Resources",
          items: [
            { text: "Adding Resources", link: "/guides/adding-resources" },
            { text: "Creating Packages", link: "/guides/creating-packages" },
          ]
        },
        {
          text: "Auth",
          items: [
            { text: "Authentication", link: "/guides/authentication" },
            { text: "Authorization", link: "/guides/authorization" },
          ]
        },
        {
          text: "Features",
          items: [
            { text: "Custom Actions", link: "/guides/custom-actions" },
            { text: "Nested Resources", link: "/guides/nested-resources" },
            { text: "Multi-tenancy", link: "/guides/multi-tenancy" },
            { text: "Search & Filtering", link: "/guides/search-filtering" },
          ]
        },
        {
          text: "Customization",
          items: [
            { text: "Theming", link: "/guides/theming" },
          ]
        }
      ],
      '/reference/': [
        {
          text: "Reference",
          items: [
            { text: "Overview", link: "/reference/" },
          ]
        },
        {
          text: "Model",
          collapsed: false,
          items: [
            { text: "Model", link: "/reference/model/" },
            { text: "Features", link: "/reference/model/features" },
          ]
        },
        {
          text: "Definition",
          collapsed: false,
          items: [
            { text: "Definition", link: "/reference/definition/" },
            { text: "Fields", link: "/reference/definition/fields" },
            { text: "Actions", link: "/reference/definition/actions" },
            { text: "Query", link: "/reference/definition/query" },
          ]
        },
        {
          text: "Policy",
          collapsed: false,
          items: [
            { text: "Policy", link: "/reference/policy/" },
          ]
        },
        {
          text: "Controller",
          collapsed: false,
          items: [
            { text: "Controller", link: "/reference/controller/" },
          ]
        },
        {
          text: "Interaction",
          collapsed: false,
          items: [
            { text: "Interaction", link: "/reference/interaction/" },
          ]
        },
        {
          text: "Views",
          collapsed: false,
          items: [
            { text: "Views", link: "/reference/views/" },
            { text: "Forms", link: "/reference/views/forms" },
          ]
        },
        {
          text: "Assets",
          collapsed: false,
          items: [
            { text: "Assets", link: "/reference/assets/" },
          ]
        },
        {
          text: "Infrastructure",
          collapsed: false,
          items: [
            { text: "Generators", link: "/reference/generators/" },
            { text: "Portal", link: "/reference/portal/" },
          ]
        }
      ],
      '/cookbook/': [
        {
          text: "Cookbook",
          items: [
            { text: "Overview", link: "/cookbook/" },
            { text: "Blog Application", link: "/cookbook/blog" },
            { text: "SaaS Application", link: "/cookbook/saas" },
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
