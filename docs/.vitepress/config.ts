import { text } from "mermaid/dist/rendering-util/rendering-elements/shapes/text.js";
import { defineConfig } from "vitepress";
import { withMermaid } from "vitepress-plugin-mermaid";

const base = "/plutonium-core/";

// https://vitepress.dev/reference/site-config
export default defineConfig(
  withMermaid({
    base: base,
    title: "Plutonium",
    description:
      "The Ultimate Rapid Application Development Toolkit (RADKit) for Rails",
    head: [["link", { rel: "icon", href: `${base}favicon.ico` }]],
    ignoreDeadLinks: "localhostLinks",
    themeConfig: {
      // https://vitepress.dev/reference/default-theme-config
      logo: "/plutonium.png",
      search: {
        provider: "local",
      },

      nav: [
        {
          text: "Fundamentals",
          items: [
            {
              text: "What is Plutonium?",
              link: "/documentation/fundamental-idea/01-what-is-plutonium",
            },
            {
              text: "Core Concepts",
              link: "/documentation/fundamental-idea/02-core-concepts",
            },
          ],
        },
        {
          text: "Documentation",
          items: [
            {
              text: "Installation",
              link: "/documentation/installation/01-installation",
            },
            {
              text: "Tutorial (Building a Blog)",
              link: "/documentation/tutorial/01-project-setup",
            },
            {
              text: "Advanced Concepts",
              link: "/documentation/advanced-concept/authorization",
            },
          ],
        },
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
          ],
        },
        {
          text: "Help",
          items: [
            {
              text: "Contribute",
              link: "https://github.com/radioactive-labs/plutonium-core",
            },
            {
              text: "Open an issue",
              link: "https://github.com/radioactive-labs/plutonium-core/issues/",
            },
            {
              text: "Claude Code Guide",
              link: "/documentation/claude-code-guide",
            },
          ],
        },
        {
          text: "Plutonium in 30 mins",
          link: "https://youtu.be/HMjzj-vVLIU?si=plRAOK2y5xIXcrDX",
        },
      ],

      sidebar: {
        "/documentation/": [
          {
            text: "Fundamentals",
            items: [
              {
                text: "What is Plutonium?",
                link: "/documentation/fundamental-idea/01-what-is-plutonium",
              },
              {
                text: "Core Concepts",
                link: "/documentation/",
              },
            ],
          },
          {
            text: "Documentation",
            items: [
              {
                text: "Installation",
                link: "/documentation/installation/01-installation",
              },
              {
                text: "Tutorial (Building a Blog)",
                collapsed: false,
                items: [
                  {
                    text: "1. Project Setup",
                    link: "/documentation/tutorial/01-project-setup",
                  },
                  {
                    text: "2. Creating a Feature Package",
                    link: "/documentation/tutorial/02-creating-a-feature-package",
                  },
                  {
                    text: "3. Defining Resources",
                    link: "/documentation/tutorial/03-defining-resources",
                  },
                  {
                    text: "4. Creating a Portal",
                    link: "/documentation/tutorial/04-creating-a-portal",
                  },
                  {
                    text: "5. Customizing the UI",
                    link: "/documentation/tutorial/05-customizing-the-ui",
                  },
                  {
                    text: "6. Adding Custom Actions",
                    link: "/documentation/tutorial/06-adding-custom-actions",
                  },
                  {
                    text: "7. Implementing Authorization",
                    link: "/documentation/tutorial/07-implementing-authorization",
                  },
                ],
              },
              {
                text: "Advanced Concepts",
                collapsed: false,
                items: [
                  {
                    text: "Resources",
                    link: "/documentation/advanced-concept/resources",
                  },
                  {
                    text: "Authorization",
                    link: "/documentation/advanced-concept/authorization",
                  },
                  {
                    text: "Multitenancy",
                    link: "/documentation/advanced-concept/multitenancy",
                  },
                ],
              },
            ],
          },
          {
            text: "Modules",
            collapsed: true,
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
            ],
          },
          {
            text: "Help",
            items: [
              {
                text: "Contribute",
                link: "https://github.com/radioactive-labs/plutonium-core",
              },
              {
                text: "Open an issue",
                link: "https://github.com/radioactive-labs/plutonium-core/issues/",
              },
              {
                text: "Claude Code Guide",
                link: "/documentation/claude-code-guide",
              },
            ],
          },
          {
            text: "Plutonium in 30 mins",
            link: "https://youtu.be/HMjzj-vVLIU?si=plRAOK2y5xIXcrDX",
          },
        ],
      },
      socialLinks: [
        {
          icon: "github",
          link: "https://github.com/radioactive-labs/plutonium-core",
        },
      ],
      footer: {
        message: "Released under the MIT License.",
        copyright: `Copyright © ${new Date().getFullYear()} - Radioactive Labs`,
      },
    },
    cleanUrls: true,
  })
);
