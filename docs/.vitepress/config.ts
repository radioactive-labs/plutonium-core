import { defineConfig, createContentLoader, type SiteConfig, type HeadConfig } from "vitepress"
import { withMermaid } from "vitepress-plugin-mermaid";
import llmstxt from "vitepress-plugin-llms";
import { Feed } from "feed";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const base = "/plutonium-core/"
// Origin + base, with no trailing slash — content-loader URLs already start with one.
const hostname = "https://radioactive-labs.github.io/plutonium-core"

// Whether the blog has anything a reader could actually open: a post that is not
// a draft and whose date has arrived. Same rule the loader and the feed apply, so
// the nav entry and the RSS advert never point at an empty page.
const hasPublishedPost = fs
  .readdirSync(fileURLToPath(new URL("../blog", import.meta.url)))
  .filter((f) => f.endsWith(".md") && f !== "index.md")
  .some((f) => {
    const raw = fs.readFileSync(fileURLToPath(new URL(`../blog/${f}`, import.meta.url)), "utf8")
    const frontmatter = raw.split("---")[1] ?? ""
    if (/^draft:\s*true\s*$/m.test(frontmatter)) return false
    const date = frontmatter.match(/^date:\s*(.+)$/m)?.[1]?.trim()
    return !!date && +new Date(date) <= Date.now()
  })

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
    ...(hasPublishedPost
      ? ([["link", { rel: "alternate", type: "application/rss+xml", title: "Plutonium Blog", href: `${hostname}/blog/feed.rss` }]] as HeadConfig[])
      : []),
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
          "blog/index.md",
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
      ...(hasPublishedPost ? [{ text: "Blog", link: "/blog/" }] : []),
      { text: "For AI Agents", link: "/ai" },
      { text: "Radioactive Labs", link: "https://radioactive-labs.github.io/" }
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
            { text: "Performance", link: "/guides/performance" },
            { text: "Troubleshooting", link: "/guides/troubleshooting" },
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
            { text: "Positioning & drag-to-reorder", link: "/reference/positioning" },
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
            { text: "Async Interactions", link: "/reference/behavior/async-interactions" },
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
      copyright: 'Copyright © 2024-present Stefan Froelich · <a href="https://radioactive-labs.github.io/" target="_blank" rel="noopener">Radioactive Labs</a>'
    }
  },
  cleanUrls: true,
  async buildEnd(config: SiteConfig) {
    const feed = new Feed({
      title: "Plutonium",
      description: "Release notes, design notes, and what's new in Plutonium.",
      id: `${hostname}/blog/`,
      link: `${hostname}/blog/`,
      language: "en",
      image: `${hostname}/og-image.png`,
      favicon: `${hostname}/favicon.ico`,
      copyright: "Copyright © 2024-present Stefan Froelich · Radioactive Labs",
    })

    const posts = await createContentLoader("blog/*.md", { render: true }).load()

    posts
      // Build-time cutoff: a feed cannot re-filter itself later, so a post dated
      // ahead stays out until the next build after its date.
      .filter(({ frontmatter }) => frontmatter.date && !frontmatter.draft)
      .filter(({ frontmatter }) => +new Date(frontmatter.date) <= Date.now())
      .sort((a, b) => +new Date(b.frontmatter.date) - +new Date(a.frontmatter.date))
      .forEach(({ url, html, frontmatter }) => {
        const link = `${hostname}${url}`
        feed.addItem({
          title: frontmatter.title,
          id: link,
          link,
          description: frontmatter.description,
          content: absolutize(html ?? "", link),
          author: frontmatter.author ? [{ name: frontmatter.author }] : undefined,
          category: frontmatter.tags?.map((name: string) => ({ name })),
          date: new Date(frontmatter.date),
        })
      })

    fs.mkdirSync(path.join(config.outDir, "blog"), { recursive: true })
    fs.writeFileSync(path.join(config.outDir, "blog", "feed.rss"), feed.rss2())
  },
}))

// A feed reader has no page to resolve links against, so everything the renderer
// left relative has to be made absolute before it ships.
function absolutize(html: string, link: string): string {
  return html
    // The renderer emits .html even though the site serves clean URLs.
    .replace(new RegExp(`(="${base}[^"]*?)\\.html(?=["#])`, "g"), "$1")
    .replaceAll(`="${base}`, `="${hostname}/`)
    // Bare fragments would point at whatever page the reader happens to be showing.
    .replaceAll('href="#', `href="${link}#`)
}
