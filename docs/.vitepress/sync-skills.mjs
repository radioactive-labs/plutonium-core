// Syncs .claude/skills/*/SKILL.md into docs/public/skills/ so the docs site
// serves them as raw, crawlable markdown at /skills/<name>.md.
// Runs before `docs:dev` and `docs:build` (see package.json). Output is gitignored.
import { readdirSync, readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")
const skillsDir = join(root, ".claude", "skills")
const outDir = join(root, "docs", "public", "skills")

rmSync(outDir, { recursive: true, force: true })
mkdirSync(outDir, { recursive: true })

const skills = []

for (const entry of readdirSync(skillsDir, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue
  const source = join(skillsDir, entry.name, "SKILL.md")
  if (!existsSync(source)) continue // skip dirs that aren't skills (no SKILL.md)
  let content = readFileSync(source, "utf8")

  const description = content.match(/^description:\s*(.+)$/m)?.[1] ?? ""

  // Wiki-style [[skill-name]] cross-links become relative markdown links so
  // crawlers can follow them between the published files.
  content = content.replace(/\[\[([\w-]+)\]\]/g, "[$1]($1.md)")

  writeFileSync(join(outDir, `${entry.name}.md`), content)
  skills.push({ name: entry.name, description })
}

skills.sort((a, b) => (a.name === "plutonium" ? -1 : b.name === "plutonium" ? 1 : a.name.localeCompare(b.name)))

const index = `# Plutonium Skills

Task-focused guides for AI agents working with the [Plutonium](https://radioactive-labs.github.io/plutonium-core/) Rails RAD framework. Each file is self-contained markdown. Start with \`plutonium.md\` — it routes to the others.

These are the same skills the gem installs into projects via \`rails g pu:skills:sync\` (Claude Code loads them automatically from \`.claude/skills/\`). Any agent can fetch them directly from the URLs below.

${skills.map((s) => `- [${s.name}](${s.name}.md) — ${s.description}`).join("\n")}
`

writeFileSync(join(outDir, "index.md"), index)
console.log(`Synced ${skills.length} skills to docs/public/skills/`)
