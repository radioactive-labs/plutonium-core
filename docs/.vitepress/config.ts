import { defineConfig } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid";

const base = "/plutonium-core/"

// https://vitepress.dev/reference/site-config
export default defineConfig(withMermaid({
  base: base,
  title: "Plutonium",
  description: "The Ultimate Rapid Application Development Toolkit (RADKit) for Rails",
  head: [["link", { rel: "icon", href: `${base}favicon.ico` }]],
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: "/plutonium.png",
    search: {
      provider: 'local'
    },
    nav: [
      { text: "Home", link: "/" },
      { text: "Guide", link: "/guide/getting-started" },
      { text: "Demo", link: "https://plutonium-app.onrender.com/" }
    ],
    sidebar: {
      '/guide/': [

        {
          text: "Introduction",
          items: [
            { text: "What is Plutonium?", link: "/guide/what-is-plutonium" },
            { text: "Tutorial", link: "/guide/tutorial" },
          ]
        },
        {
          text: "Getting Started",
          items: [
            { text: "Overview", link: "/guide/getting-started/" },
            { text: "Installation", link: "/guide/getting-started/installation" },
            { text: "Core Concepts", link: "/guide/getting-started/core-concepts" },
            { text: "Resources", link: "/guide/getting-started/resources" },
            { text: "Authorization", link: "/guide/getting-started/authorization" },
          ]
        },
        // { text: "Quick Start", link: "/installation" },

        // {
        //   text: "Examples",
        //   items: [
        //     { text: "Markdown Examples", link: "/installation" },
        //     { text: "Runtime API Examples", link: "/api-examples" }
        //   ]
        // }
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
