import { createContentLoader } from "vitepress"

export interface Post {
  title: string
  url: string
  description: string
  author?: string
  tags: string[]
  date: { time: number; string: string }
}

declare const data: Post[]
export { data }

export default createContentLoader("blog/*.md", {
  transform(raw): Post[] {
    return raw
      // The section index has no date: that's what separates it from a post.
      .filter(({ frontmatter }) => frontmatter.date && !frontmatter.draft)
      // Dated ahead means unpublished. The cutoff is applied at BUILD time, so a
      // post goes live on the first build after its date, not on the date itself.
      .filter(({ frontmatter }) => +new Date(frontmatter.date) <= Date.now())
      .map(({ url, frontmatter }) => ({
        title: frontmatter.title,
        url,
        description: frontmatter.description ?? "",
        author: frontmatter.author,
        tags: frontmatter.tags ?? [],
        date: formatDate(frontmatter.date),
      }))
      .sort((a, b) => b.date.time - a.date.time)
  },
})

function formatDate(raw: string | Date): Post["date"] {
  const date = new Date(raw)
  // Frontmatter dates parse as UTC midnight; nudge to midday so the rendered
  // day doesn't slip backwards for readers behind UTC.
  date.setUTCHours(12)
  return {
    time: +date,
    string: date.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" }),
  }
}
