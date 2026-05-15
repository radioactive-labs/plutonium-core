# Runbook — Demo capture for HomeWalkthrough assets

Manual steps to produce the 4 assets that Task 13 wires into `HomeWalkthrough.vue`:

- `docs/public/asciinema/home-scaffold.cast`
- `docs/public/images/home-portal.png`
- `docs/public/images/home-index.png`
- `docs/public/images/home-form.png`

Why manual: asciinema needs a real TTY and screenshots need your keyboard — neither can be automated by a subagent in this environment.

---

## Step 1 — Scaffold the demo (records asciinema while it runs)

Open a fresh terminal (NOT the one running Claude). Asciinema captures the whole session.

```bash
mkdir -p /tmp/plutonium-demo && cd /tmp/plutonium-demo
asciinema rec --idle-time-limit=2 --title "Plutonium scaffold" /tmp/scaffold-raw.cast
```

Inside the recording session, run:

```bash
rails new blog -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
cd blog
clear
rails g pu:res:scaffold Post title:string body:text published:boolean
rails g pu:res:scaffold Comment 'post:references' body:text
rails g pu:res:conn Post Comment --dest=admin_portal
rails db:migrate
exit
```

Notes:
- `clear` before the `pu:*` commands wipes the noisy `rails new` preamble so the recording starts clean on the Plutonium part.
- When you type `exit`, asciinema stops and writes `/tmp/scaffold-raw.cast`.

## Step 2 — Move the cast into the docs site

```bash
# Optional: inspect duration first
asciinema cat /tmp/scaffold-raw.cast | head -1

# If the cast is long (60s+) consider trimming. Simplest option: just use the raw
# cast — the player loops, and viewers don't watch end-to-end. To trim manually,
# edit the .cast file: line 1 is the JSON header, subsequent lines are
# [time, "o", "text"] records — drop records outside the time range you want.

cp /tmp/scaffold-raw.cast \
   /Users/stefan/Documents/plutonium/plutonium-core/docs/public/asciinema/home-scaffold.cast
```

## Step 3 — Seed posts and boot for screenshots

```bash
cd /tmp/plutonium-demo/blog
bin/rails runner '3.times { |i| Post.create!(title: "Hello world #{i+1}", body: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", published: true) }; Post.create!(title: "Draft post", body: "Consectetur adipiscing elit.", published: false)'
bin/rails s
```

## Step 4 — Take 3 screenshots at 1280×800

Open Chrome or Safari. In DevTools → device toolbar (`Cmd+Shift+M` in Chrome), set the viewport to **Responsive → 1280×800**. Visit each URL below, take a clean PNG screenshot, and save to the listed filename in `docs/public/images/`.

| URL                                          | Filename          | Notes                                                |
| -------------------------------------------- | ----------------- | ---------------------------------------------------- |
| `http://localhost:3000/admin`                | `home-portal.png` | Wide shot — sidebar + posts table visible            |
| `http://localhost:3000/admin/posts`          | `home-index.png`  | Close-up of the posts table with the 4 seeded rows   |
| `http://localhost:3000/admin/posts/new`      | `home-form.png`   | Close-up of the auto-generated form                  |

Drop all three into:

```
/Users/stefan/Documents/plutonium/plutonium-core/docs/public/images/
```

## Step 5 — Tell Claude when done

Once these four files exist:

```
docs/public/asciinema/home-scaffold.cast
docs/public/images/home-portal.png
docs/public/images/home-index.png
docs/public/images/home-form.png
```

say "done" in chat. Task 13 (wire assets) will then replace the placeholder boxes in `HomeWalkthrough.vue` with the real images and an asciinema-player embed.

## Troubleshooting

- **Template URL 404 / hangs.** The template lives at `https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb`. If the GitHub Pages site is rebuilding, retry after a minute, or point at the local file:
  ```bash
  rails new blog ... -m /Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/plutonium.rb
  ```
- **`pu:res:scaffold` errors.** Confirm the template installed the gem — `bundle list | grep plutonium` should show the version. If the gem isn't there, re-run the template via `bin/rails app:template LOCATION=...`.
- **Screenshot has wrong aspect ratio.** Confirm DevTools device toolbar is set to exactly 1280×800 (not a different preset) before capturing.
- **Asciinema cast won't play in browser later.** Check the cast file starts with `{"version": 2, ...` JSON header on line 1.
