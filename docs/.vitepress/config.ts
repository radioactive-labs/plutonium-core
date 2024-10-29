import { defineConfig } from 'vitepress'

const base = "/plutonium-core/"

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: base,
  title: "Plutonium",
  description: "A Rapid Application Development Toolkit (RADKit) for Rails",
  head: [['link', { rel: 'icon', href: `${base}favicon.ico` }]],
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: "/plutonium.png",
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Examples', link: '/markdown-examples' }
    ],
    sidebar: [
      {
        text: 'Examples',
        items: [
          { text: 'Markdown Examples', link: '/markdown-examples' },
          { text: 'Runtime API Examples', link: '/api-examples' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/vuejs/vitepress' }
    ]
  },
  cleanUrls: true,
})
