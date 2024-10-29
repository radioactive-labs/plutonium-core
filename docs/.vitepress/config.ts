import { defineConfig } from "vitepress"

const base = "/plutonium-core/"

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: base,
  title: "Plutonium",
  description: "A Rapid Application Development Toolkit (RADKit) for Rails",
  head: [["link", { rel: "icon", href: `${base}favicon.ico` }]],
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: "/plutonium.png",
    search: {
      provider: 'local'
    },
    nav: [
      { text: "Home", link: "/" },
      { text: "Guide", link: "/guide/installation" }
    ],
    sidebar: {
      '/guide/': [
        {
          text: "Introduction",
          items: [
            { text: "What is Plutonium?", link: "/guide/what-is-plutonium" },
            { text: "Installation", link: "/guide/installation" },
            { text: "Getting Started", link: "/guide/getting-started" },
            // { text: "Quick Start", link: "/installation" },
          ]
        },
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
})
