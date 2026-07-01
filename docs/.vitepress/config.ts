import { defineConfig } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid";
import llmstxt from "vitepress-plugin-llms";

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
  srcExclude: ['superpowers/**'],
  vite: {
    plugins: [
      // Generates llms.txt, llms-full.txt, and a raw .md twin for every page.
      llmstxt({
        // Site base (/plutonium-core/) is appended automatically — domain must not include it.
        domain: "https://radioactive-labs.github.io",
        // public/ is served verbatim (skills live there); superpowers/ is internal.
        // Section landing pages are Vue components with no markdown content.
        ignoreFiles: [
          "superpowers/**",
          "public/**",
          "getting-started/index.md",
          "guides/index.md",
          "reference/index.md",
        ],
      }),
    ],
  },
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
      { text: "For AI Agents", link: "/ai" }
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
            { text: "7. Author Portal", link: "/getting-started/tutorial/07-author-portal" },
            { text: "8. Customizing UI", link: "/getting-started/tutorial/08-customizing-ui" },
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
            { text: "User Invites", link: "/guides/user-invites" },
            { text: "Wizards", link: "/guides/wizards" },
            { text: "Kanban Boards", link: "/guides/kanban" },
          ]
        },
        {
          text: "Customization",
          items: [
            { text: "Theming", link: "/guides/theming" },
          ]
        },
        {
          text: "Quality",
          items: [
            { text: "Testing", link: "/guides/testing" },
          ]
        }
      ],
      '/reference/': [
        {
          text: "Reference",
          items: [
            { text: "Overview", link: "/reference/" },
            { text: "Configuration", link: "/reference/configuration" },
          ]
        },
        {
          text: "App",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/app/" },
            { text: "Packages", link: "/reference/app/packages" },
            { text: "Portals", link: "/reference/app/portals" },
            { text: "Generators", link: "/reference/app/generators" },
            { text: "Lite (SQLite) Generators", link: "/reference/generators/lite" },
          ]
        },
        {
          text: "Resource",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/resource/" },
            { text: "Model", link: "/reference/resource/model" },
            { text: "Definition", link: "/reference/resource/definition" },
            { text: "Query", link: "/reference/resource/query" },
            { text: "Actions", link: "/reference/resource/actions" },
            { text: "CSV Export", link: "/reference/resource/export" },
          ]
        },
        {
          text: "Behavior",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/behavior/" },
            { text: "Controllers", link: "/reference/behavior/controllers" },
            { text: "Policies", link: "/reference/behavior/policies" },
            { text: "Interactions", link: "/reference/behavior/interactions" },
          ]
        },
        {
          text: "UI",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/ui/" },
            { text: "Pages", link: "/reference/ui/pages" },
            { text: "Forms", link: "/reference/ui/forms" },
            { text: "Displays", link: "/reference/ui/displays" },
            { text: "Tables", link: "/reference/ui/tables" },
            { text: "Components", link: "/reference/ui/components" },
            { text: "Layouts", link: "/reference/ui/layouts" },
            { text: "Assets", link: "/reference/ui/assets" },
          ]
        },
        {
          text: "Auth",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/auth/" },
            { text: "Accounts", link: "/reference/auth/accounts" },
            { text: "Profile", link: "/reference/auth/profile" },
          ]
        },
        {
          text: "Tenancy",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/tenancy/" },
            { text: "Entity scoping", link: "/reference/tenancy/entity-scoping" },
            { text: "Nested resources", link: "/reference/tenancy/nested-resources" },
            { text: "Invites", link: "/reference/tenancy/invites" },
          ]
        },
        {
          text: "Wizard",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/wizard/" },
            { text: "DSL", link: "/reference/wizard/dsl" },
            { text: "Anchoring & resume", link: "/reference/wizard/anchoring-resume" },
            { text: "Storage & config", link: "/reference/wizard/storage-config" },
            { text: "Registration & launch", link: "/reference/wizard/registration-launch" },
            { text: "One-time", link: "/reference/wizard/one-time" },
          ]
        },
        {
          text: "Kanban",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/kanban/" },
            { text: "DSL", link: "/reference/kanban/dsl" },
            { text: "Positioning", link: "/reference/kanban/positioning" },
            { text: "Authorization", link: "/reference/kanban/authorization" },
          ]
        },
        {
          text: "Testing",
          collapsed: false,
          items: [
            { text: "Overview", link: "/reference/testing/" },
          ]
        }
      ],
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
