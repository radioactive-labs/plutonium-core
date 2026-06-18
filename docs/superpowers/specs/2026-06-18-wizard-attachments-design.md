# Wizard attachments: token → attachment bridge

Status: **design / implementing**
Date: 2026-06-18

## Problem

A wizard step can render a file input — the real-world pattern (a colleague's):

```ruby
step :photo, label: "Photo" do
  attribute :photo, :string
  input :photo, as: :uppy, direct_upload: true, hint: "Optional — …"
end
```

— but attachments don't display end to end:

- The `Uppy` input and `Display::Components::Attachment` expect a value that
  **quacks like an attachment** (`.url`, `.filename`, `.content_type`, …).
- A wizard stages **plain typed scalars**. A direct-upload field submits its
  backend's upload **token** (an ActiveStorage signed_id, or Shrine cached-file
  JSON), so `data.photo` is a `String`.
- `SummaryDisplay` (the review auto-summary) hardcodes `f.string_tag` for every
  field — an attachment shows as a raw token, never a preview.
- On Back/resume, the `Uppy` input calls `.url` on the staged `String` — wrong.

## Backends — there is more than ActiveStorage

Plutonium attachment fields can be backed by **ActiveStorage** *or* **active_shrine**
(Shrine) — see `Plutonium::UI::Avatar.resolve_image_src`, which branches (AS resolves
its URL via Rails routing; Shrine via its own `#url`). They carry different upload
tokens, and active_shrine is **not a core-gem dependency** (generator-installed), so
it isn't exercised by this repo's suite. The bridge must therefore be
backend-agnostic by construction; the dummy covers the AS path.

## Key decision — model-free resolution by token SHAPE

The field is bare (`attribute :photo, :string`, no `using:` model), so there is **no
model to resolve against** — and we don't need one. The staged token is one of two
shapes, and they're distinguishable:

- **Shrine** cached-file data is **JSON** (`{"id":…,"storage":"cache",…}`) →
  `Shrine.uploaded_file(data)` revives it from the globally-registered storages.
- An **ActiveStorage** signed_id is **not** JSON → `ActiveStorage::Blob.find_signed`.

```ruby
Plutonium::Wizard::Attachments.resolve(token) # → [Shrine::UploadedFile | ActiveStorage::Blob]
#   JSON.parse succeeds → Shrine ; else → ActiveStorage ; blank/tampered → dropped
```

`data` stays plain strings (no custom ActiveModel type; `encrypt_data`, merge, sweep
untouched). Resolution is **display-only** — staging and `execute` never call it.

Why token-shape over a source model: the actual usage is a **modelless** `as: :uppy`
field, so there's no `using:` model to assign to; and the two token shapes are
unambiguous, so a model would be ceremony, not information. (A custom Shrine uploader
with derivative-specific URLs would want its own attacher, but a cached file's `.url`
from the base `Shrine` is correct for the in-flight preview/review.)

## The four boundaries

1. **Declaration.** `attribute :photo, :string` + `input :photo, as: :uppy`
   (`/:file`/`:attachment`), `direct_upload: true`. Multiple → an array attribute +
   `multiple: true`. An attachment field = a step input whose `as:` is a file alias
   (`Attachments.field?`).
2. **Staging.** The submitted token(s) extract through the step form like any other
   field and stage as the string/array — no special handling (verify in a request
   test).
3. **Input rehydration (Back/resume).** The wizard step form wraps its data object so
   an attachment field READS as the resolved attachment object(s) (for the `Uppy`
   preview) while every other field reads normally. Render-only: the submitted value
   is still the token the hidden preview field posts, so staging is unaffected.
4. **Review.** `SummaryDisplay` detects attachment fields (`field?`) and renders the
   resolved attachment via `Display::Components::Attachment` instead of `string_tag`.

## Execute

Author code, unchanged shape: `succeed(Member.create!(photo: data.photo.photo))`.
The staged token round-trips into the model's attachment natively (AS or Shrine).

## Risks / dependencies

- **Direct-upload endpoint.** `Uppy` posts to `/upload` (AS DirectUploads, or Shrine's
  `upload_endpoint`). A shell-less / main-app wizard must have it reachable. Host
  concern; document it.
- **Orphaned uploads.** A token staged then abandoned (cancel/sweep) leaves an
  unattached blob / cached Shrine file; each backend's own cleanup handles it. Note it.
- **Bad/expired token** → resolution drops the entry (no raise), so a tampered token
  never 500s the review or the form.
- **active_shrine untestable in-repo** (not a dep) — the dummy proves the AS path; the
  Shrine branch is unit-stubbed and rides the same `.url`/`.filename` contract
  (confirmed for display by `Avatar.resolve_image_src`).

## Build order

1. `Plutonium::Wizard::Attachments` — `field?` + token-shape `resolve`. ✅ done
2. `SummaryDisplay`: attachment-aware rendering + a dummy `as: :uppy` step + review test.
3. Input rehydration wrapper + a Back/resume request test.
4. Full dummy flow (upload token → review → execute assigns the attachment) +
   integration test. Requires AS tables provisioned in the dummy.
