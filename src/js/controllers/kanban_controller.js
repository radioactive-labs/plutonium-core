import { Controller } from "@hotwired/stimulus"
import { morphTurboFrameElements } from "@hotwired/turbo"

// Connects to data-controller="kanban"
//
// Enables drag-and-drop reordering of kanban cards across columns using the
// browser's native HTML5 drag-and-drop API (no additional npm dependency).
//
// ## DOM contract
//
// Board wrapper (this element):
//   data-controller="kanban"
//   data-kanban-move-url-template-value="/path/__ID__/kanban_move"
//     — the collection path with an __ID__ placeholder; the controller
//       substitutes the dragged card's record id at drop time.
//
// Column wrapper (rendered by Kanban::Column as the turbo-frame body):
//   data-kanban-col="<key>"            — unique wrapper identifier for JS
//   data-kanban-accepts="all|none|<key>,<key>,…"
//     — "all": any card may be dropped here
//     — "none": no card may be dropped here
//     — comma list: only cards whose source column key is in the list
//   data-kanban-locked="true|false"
//     — true: cards in this column cannot be dragged out of it
//
// Column drop zone (rendered by Kanban::Column inside each turbo-frame):
//   data-kanban-target="column"
//   data-kanban-column-key-value="<key>"
//
// Draggable card (rendered by Kanban::Card):
//   draggable="true"
//   data-kanban-record-id="<id>"
//   data-kanban-column-key="<source-column-key>"
//
// Column toggle control (button inside the strip / expanded header):
//   data-action="click->kanban#toggleColumn"
//   data-kanban-column-key="<key>"
//
// ## Collapse toggle
//
// toggleColumn reads data-kanban-column-key from the clicked button, finds the
// matching [data-kanban-col] wrapper, and flips `pu-kanban-column-collapsed` on
// it for instant feedback. CSS handles show/hide of strip vs body.
//
// The choice is persisted in a per-board cookie (name/path supplied via the
// collapse-cookie / collapse-path values) storing ONLY columns whose state
// differs from their server default — read from data-kanban-default-collapsed.
// Because the SERVER reads that cookie and renders each column in the user's
// state, there is no client re-apply on any render path (lazy load, search
// morph, move stream) and therefore no collapse FOUC. The delta encoding keeps
// the cookie compact and self-trimming (default board → no cookie).
//
// ## Frozen board (search / filter / scope)
//
// The board wrapper is `data-turbo-permanent`, so it survives index
// navigations intact rather than being re-rendered as empty lazy shells (which
// blanked the columns on every search keystroke). Turbo transplants the
// permanent element into the new page, which disconnects→reconnects this
// controller — so connect() runs on every nav, and the frozen frames still
// carry the PREVIOUS URL's src. #syncColumnsToUrl (called from connect() and on
// every `turbo:load`) reconciles each frame's src with the current URL,
// reloading only the frames that differ; `turbo:before-frame-render` upgrades
// those reloads to a MORPH so cards diff in place instead of blanking. The sync
// is stateless (frame-src-vs-URL, no "last synced" flag) precisely because the
// reconnect would reset any such flag before it could be used.
//
// ## Drop hints
//
// On dragstart:
//   1. Determine whether the source column is locked (cards cannot leave).
//   2. For each column wrapper, compute whether a drop would be accepted and
//      add the CSS class `pu-kanban-no-drop` to wrappers that would reject.
//   3. Also suppress the browser's `dragover` preventDefault() for no-drop
//      columns so the native "no entry" cursor shows.
// On dragend: clear all hint classes.
//
// ## Move flow
//
// 1. dragstart — record which card was grabbed and apply an opacity hint.
// 2. dragover  — highlight the target column drop zone; suppress the browser's
//                "forbidden" cursor by calling preventDefault(). For columns
//                marked pu-kanban-no-drop we skip preventDefault so the native
//                "no entry" cursor shows instead.
// 3. drop      — compute to_index (vertical cursor position within the column),
//                POST {from_column, to_column, to_index} to the move endpoint,
//                and feed the Turbo Stream response to Turbo.renderStreamMessage.
//                On success the server re-renders both column frames; on 422 it
//                re-renders only the source column so the card snaps back — the
//                controller never hand-manages rollback state.
// 4. dragend   — clean up opacity + highlights + drop-hint classes.
export default class extends Controller {
  static values = { moveUrlTemplate: String, collapseCookie: String, collapsePath: String }
  static targets = ["column"]

  connect() {
    this.draggedCard = null

    this.onDragStart = this.#onDragStart.bind(this)
    this.onDragOver = this.#onDragOver.bind(this)
    this.onDragLeave = this.#onDragLeave.bind(this)
    this.onDrop = this.#onDrop.bind(this)
    this.onDragEnd = this.#onDragEnd.bind(this)

    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragover", this.onDragOver)
    this.element.addEventListener("dragleave", this.onDragLeave)
    this.element.addEventListener("drop", this.onDrop)
    this.element.addEventListener("dragend", this.onDragEnd)

    // Preserve horizontal scroll across navs AND full page reloads. The browser
    // never restores an inner container's scroll, and neither a Turbo reattach
    // (permanent board detached→reattached, scrollLeft reset to 0) nor an F5
    // (fresh DOM) keeps it — so we persist it in sessionStorage, keyed per board,
    // and restore it below. scrollTarget is the in-memory copy (seeded from
    // storage on every connect, so it survives reconnects too).
    this.scrollTarget = this.#readStoredScroll()

    this.captureScroll = this.#captureScroll.bind(this)

    // Trailing debounce: a scroll event only (re)arms the timer — it reads NO
    // layout, so it can't force a reflow / stutter. The capture reads
    // scrollLeft/scrollWidth once, after scrolling settles.
    this.onBoardScroll = () => {
      if (this.restoringScroll) return
      clearTimeout(this.scrollSaveTimer)
      this.scrollSaveTimer = setTimeout(this.captureScroll, 120)
    }
    this.element.addEventListener("scroll", this.onBoardScroll, { passive: true })

    // A genuine scroll gesture during the restore window means the user has taken
    // over — stop pinning so we don't fight them.
    this.onUserScrollIntent = () => this.#endScrollRestore()
    this.element.addEventListener("wheel", this.onUserScrollIntent, { passive: true })
    this.element.addEventListener("touchmove", this.onUserScrollIntent, { passive: true })

    // Capture immediately before an F5 / cross-document nav unloads us, so a
    // reload mid-scroll (before the debounce fires) still saves the position.
    this.onPageHide = this.captureScroll
    window.addEventListener("pagehide", this.onPageHide)

    // ── Frozen-board sync (see class header) ──
    this.onTurboLoad = this.#syncColumnsToUrl.bind(this)
    this.onBeforeFrameRender = this.#onBeforeFrameRender.bind(this)
    this.onFrameRender = this.#onFrameRender.bind(this)
    this.onBeforeStreamRender = this.#onBeforeStreamRender.bind(this)

    // After each navigation, reconcile the column frames' src with the new URL.
    document.addEventListener("turbo:load", this.onTurboLoad)
    // Force a MORPH render on column-frame reloads (a plain src change would
    // blank→fill; morphing diffs cards in place).
    document.addEventListener("turbo:before-frame-render", this.onBeforeFrameRender)
    // turbo:frame-render (nav reload) and turbo:before-stream-render (move /
    // realtime) are hooked only to keep the horizontal scroll pinned as columns
    // re-render — collapse state no longer needs re-applying, because the server
    // renders each column in the user's cookie-persisted state directly.
    document.addEventListener("turbo:frame-render", this.onFrameRender)
    document.addEventListener("turbo:before-stream-render", this.onBeforeStreamRender)

    // Reconcile immediately: when Turbo transplants the permanent board it
    // disconnects→reconnects this controller, so connect() itself runs on every
    // nav. A stale frame (src carrying the previous URL's params) is reloaded
    // here; a fresh board (frames already matching the URL) is a no-op.
    this.#syncColumnsToUrl()

    // connect() runs right after reattach — put the horizontal scroll back.
    this.#restoreScrollLeft()

    // Refresh cached columns after a write (see #reloadAfterWrite).
    this.#reloadAfterWrite()
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragover", this.onDragOver)
    this.element.removeEventListener("dragleave", this.onDragLeave)
    this.element.removeEventListener("drop", this.onDrop)
    this.element.removeEventListener("dragend", this.onDragEnd)

    // Capture before we lose this instance to a Turbo reconnect, so the next
    // connect reads an up-to-date position.
    this.#captureScroll()
    this.element.removeEventListener("scroll", this.onBoardScroll)
    this.element.removeEventListener("wheel", this.onUserScrollIntent)
    this.element.removeEventListener("touchmove", this.onUserScrollIntent)
    window.removeEventListener("pagehide", this.onPageHide)
    clearTimeout(this.restoreScrollTimer)
    clearTimeout(this.scrollSaveTimer)

    document.removeEventListener("turbo:load", this.onTurboLoad)
    document.removeEventListener("turbo:before-frame-render", this.onBeforeFrameRender)
    document.removeEventListener("turbo:frame-render", this.onFrameRender)
    document.removeEventListener("turbo:before-stream-render", this.onBeforeStreamRender)
  }

  // ─── Frozen-board URL sync ────────────────────────────────────────────────────

  // Reconcile every column frame's src with the current URL's board params
  // (q / scope / sort). The board is frozen (data-turbo-permanent), so its
  // frames keep whatever src they were last loaded with; this is what reflects a
  // new search / filter / scope into the columns.
  //
  // STATELESS by design: we compare each frame's actual src against the src the
  // current URL implies and reload only the ones that differ. We deliberately do
  // NOT track "last synced URL" — Turbo reconnects this controller on every nav
  // (the permanent board is transplanted), so any per-connect state would be
  // reset to the new URL before we could diff against it, and the sync would
  // never fire. Comparing frame-src-vs-URL has no such blind spot and is
  // self-limiting: once a frame matches the URL, it won't reload again.
  // A create/update/destroy that returns to the board redirects to a URL the
  // server tagged with kanban_reload=1 (see KanbanActions#kanban_reload_url).
  // The board is data-turbo-permanent, so its already-loaded column frames are
  // kept as-is on arrival — stale (missing a new card, still showing a deleted
  // one). Force every column to re-fetch, then strip the marker so a later
  // reload / back-nav doesn't re-trigger it. The restore window opened by
  // #restoreScrollLeft keeps the scroll pinned as the fresh frames render.
  #reloadAfterWrite() {
    const url = new URL(window.location.href)
    if (!url.searchParams.has("kanban_reload")) return
    url.searchParams.delete("kanban_reload")
    history.replaceState(history.state, "", `${url.pathname}${url.search}${url.hash}`)
    this.#columnFrames().forEach(frame => frame.reload())
  }

  #syncColumnsToUrl() {
    this.#columnFrames().forEach(frame => {
      const desired = this.#columnFrameSrc(frame.dataset.kanbanColFrame)
      const current = frame.getAttribute("src")
      if (current && this.#canonicalUrl(current) === this.#canonicalUrl(desired)) return
      // Assigning src reloads the frame; #onBeforeFrameRender upgrades that
      // reload to a morph so the cards diff in place.
      frame.src = desired
    })
  }

  // The src a column frame should carry for the current URL: the page's query
  // params with view=kanban + column=<key> forced on. Mirrors the server's
  // Kanban::Resource#column_frame_src so a freshly-rendered board's frames
  // already match (no spurious reload).
  #columnFrameSrc(key) {
    const params = new URLSearchParams(window.location.search)
    params.set("view", "kanban")
    params.set("column", key)
    return `${window.location.pathname}?${params.toString()}`
  }

  // Order-independent identity for a frame src: path + alphabetically sorted
  // query params. The server serialises params sorted (Hash#to_query) while
  // URLSearchParams preserves insertion order, so raw string comparison would
  // report a false difference and reload every frame on every nav.
  #canonicalUrl(src) {
    const url = new URL(src, window.location.origin)
    url.searchParams.sort()
    return `${url.pathname}?${url.searchParams.toString()}`
  }

  // Turbo fires this before a frame renders fetched content. For our column
  // frames we swap in a morph render so the reload diffs the card list rather
  // than replacing it (which would blank the column). Uses Turbo's own frame
  // morph so before/after hooks (turbo:before-frame-morph) still fire.
  #onBeforeFrameRender(event) {
    if (!this.#isColumnFrame(event.target)) return
    // Diff the card list in place instead of blank→fill. Collapse state rides
    // along correctly because the server rendered the fetched frame in the
    // user's state, so morphing to it keeps that state — no re-apply needed.
    event.detail.render = (currentElement, newElement) =>
      morphTurboFrameElements(currentElement, newElement)
  }

  #onFrameRender(event) {
    if (!this.#isColumnFrame(event.target)) return
    // Each column render can change the board's width and clamp scrollLeft. On a
    // full reload the columns lazy-load one at a time AFTER connect, so keep
    // pinning — and push the restore window out — with every frame that lands.
    if (this.restoringScroll) {
      this.#pinScroll()
      this.#bumpRestoreTimer()
    }
  }

  // Apply the saved horizontal position: to the live max when the user was at
  // the end (so it tracks late width changes), otherwise to the exact offset.
  // No-op when nothing meaningful was saved so it can't yank a fresh board to 0.
  #pinScroll() {
    const t = this.scrollTarget
    if (!t || (!t.l && !t.e)) return
    this.element.scrollLeft = t.e ? this.element.scrollWidth : t.l
  }

  // Re-apply the saved horizontal scroll across a window that extends with each
  // column render, because renders (morph on nav, replace on move, lazy load on
  // full reload) settle their width late and each settle can clamp scrollLeft
  // back toward 0. Used by the reattach, turbo-stream, and initial-load paths.
  #scheduleScrollRestore() {
    if (!this.scrollTarget || (!this.scrollTarget.l && !this.scrollTarget.e)) return
    this.restoringScroll = true
    this.#pinScroll()
    requestAnimationFrame(() => this.#pinScroll())
    this.#bumpRestoreTimer()
  }

  // (Re)arm the timer that ends the restore window. Reset on every column render
  // so the window lives ~400ms past the LAST column to settle — enough for slow
  // lazy frames on a fresh load without pinning forever.
  #bumpRestoreTimer() {
    clearTimeout(this.restoreScrollTimer)
    this.restoreScrollTimer = setTimeout(() => this.#endScrollRestore(), 400)
  }

  #endScrollRestore() {
    if (!this.restoringScroll) return
    this.#pinScroll()
    this.restoringScroll = false
    clearTimeout(this.restoreScrollTimer)
  }

  // Restore on connect — covers Turbo reattach (search/filter) and a full page
  // reload (F5), since scrollTarget is seeded from sessionStorage either way.
  #restoreScrollLeft() {
    this.#scheduleScrollRestore()
  }

  // ── scroll persistence (sessionStorage) ──
  // Per-tab and auto-cleared on tab close, so it can't accumulate. Keyed by the
  // board's collection path (tenant + resource scoped) via the move template.

  #scrollKey() {
    const path = this.moveUrlTemplateValue.replace("/__ID__/kanban_move", "")
    return `pu-kanban-scroll:${path}`
  }

  #readStoredScroll() {
    try {
      const raw = sessionStorage.getItem(this.#scrollKey())
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  }

  // Read the live position (unless a restore currently owns scrollTarget) and
  // persist it. Runs on the scroll debounce, on pagehide, and on disconnect —
  // never on the raw scroll event, so the layout read can't stutter scrolling.
  #captureScroll() {
    const el = this.element
    // Skip the read when the board has no layout: on a nav teardown the element
    // is detached, so scrollLeft/scrollWidth/clientWidth all read 0 — which would
    // compute a bogus "at-end" (0 >= -2) and pin the next restore to the far end.
    // The last in-memory target already reflects the user's real position, so
    // keep it. `e` also requires genuine overflow, never a zero-width board.
    if (!this.restoringScroll && el.clientWidth > 0) {
      const maxScroll = el.scrollWidth - el.clientWidth
      this.scrollTarget = {
        l: el.scrollLeft,
        e: maxScroll > 0 && el.scrollLeft >= maxScroll - 2
      }
    }
    if (!this.scrollTarget) return
    try {
      sessionStorage.setItem(this.#scrollKey(), JSON.stringify(this.scrollTarget))
    } catch { /* private mode / quota — in-memory target still works this session */ }
  }

  // A move / realtime update re-renders columns via turbo-stream (replace). The
  // server renders them in the user's collapse state, so we only need to protect
  // the horizontal scroll: freeze tracking BEFORE the swap (replacing a column
  // briefly removes it, narrowing the board so scrollLeft clamps toward 0 — that
  // clamp would otherwise be saved as the new position, a visible jump at the
  // far end), then restore once the columns are back.
  #onBeforeStreamRender(event) {
    // Only interfere with streams that target one of THIS board's column
    // frames. Any other stream (a redirect, a flash append, another board's
    // update, the remote_modal empty on drop-interaction success) must render
    // untouched so unrelated stream actions don't surface through this wrapper.
    if (!this.#streamTargetsColumn(event.target)) return

    const render = event.detail.render
    event.detail.render = async (streamElement) => {
      this.restoringScroll = true
      await render(streamElement)
      this.#scheduleScrollRestore()
    }
  }

  // True when the <turbo-stream> element targets a column frame contained by
  // this board — via its `target` (frame id) or `targets` (CSS selector).
  #streamTargetsColumn(streamElement) {
    if (!streamElement) return false
    const target = streamElement.getAttribute("target")
    if (target) return this.#isColumnFrame(document.getElementById(target))
    const targets = streamElement.getAttribute("targets")
    if (targets) {
      return [...document.querySelectorAll(targets)].some(el => this.#isColumnFrame(el))
    }
    return false
  }

  #columnFrames() {
    return this.element.querySelectorAll("turbo-frame[data-kanban-col-frame]")
  }

  #isColumnFrame(el) {
    return el?.matches?.("turbo-frame[data-kanban-col-frame]") && this.element.contains(el)
  }

  // ─── Collapse toggle ─────────────────────────────────────────────────────────

  // Stimulus action: data-action="click->kanban#toggleColumn"
  // Expected on the expand button in the collapsed strip and the collapse
  // button in the expanded header.  data-kanban-column-key on the button
  // identifies which column to toggle.
  toggleColumn(event) {
    const key = event.currentTarget.dataset.kanbanColumnKey
    if (!key) return

    const wrapper = this.element.querySelector(`[data-kanban-col="${key}"]`)
    if (!wrapper) return

    const strip = wrapper.querySelector("[data-kanban-role='strip']")
    const body  = wrapper.querySelector("[data-kanban-role='body']")
    if (!strip || !body) return

    // `pu-kanban-column-collapsed` on the wrapper is what CSS uses to decide
    // which half to show. Flip it for instant feedback, then persist the choice
    // as a delta from the column's server default so the next render (from the
    // server) comes back in this same state.
    const nowCollapsed = wrapper.classList.toggle("pu-kanban-column-collapsed")
    const defaultCollapsed = wrapper.dataset.kanbanDefaultCollapsed === "true"
    this.#persistCollapse(key, nowCollapsed !== defaultCollapsed)
  }

  // ─── drag lifecycle ──────────────────────────────────────────────────────────

  #onDragStart(event) {
    const card = event.target.closest("[data-kanban-record-id]")
    if (!card) return

    this.draggedCard = card
    event.dataTransfer.effectAllowed = "move"
    // Store the id so native DnD still carries data if the card is dropped
    // outside the board (where we won't handle it, but no error).
    event.dataTransfer.setData("text/plain", card.dataset.kanbanRecordId)

    // Defer the opacity change so the drag ghost image is captured first.
    requestAnimationFrame(() => card.classList.add("pu-kanban-dragging"))

    // Mark columns that would reject a drop from this card's source column.
    this.#applyDropHints(card.dataset.kanbanColumnKey)
  }

  #onDragOver(event) {
    const column = event.target.closest("[data-kanban-target='column']")
    if (!column) return

    // Skip preventDefault for no-drop columns so the browser shows a
    // "no entry" cursor rather than the move cursor.
    const wrapper = event.target.closest("[data-kanban-col]")
    if (wrapper?.classList.contains("pu-kanban-no-drop")) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.#highlightColumn(column)
  }

  #onDragLeave(event) {
    // Only clear the highlight when the cursor leaves the board entirely.
    // relatedTarget is null when leaving the viewport, or a node outside
    // the board wrapper when crossing the edge.
    if (!this.element.contains(event.relatedTarget)) {
      this.#clearHighlights()
    }
  }

  async #onDrop(event) {
    event.preventDefault()
    this.#clearHighlights()

    if (!this.draggedCard) return

    // Respect client-side drop hints: skip the POST for columns the client
    // knows would reject. The server enforces this authoritatively on every
    // request, so skipping saves a round-trip and avoids a 422 flash.
    const wrapper = event.target.closest("[data-kanban-col]")
    if (wrapper?.classList.contains("pu-kanban-no-drop")) return

    const column = event.target.closest("[data-kanban-target='column']")
    if (!column) return

    const recordId = this.draggedCard.dataset.kanbanRecordId
    const fromColumn = this.draggedCard.dataset.kanbanColumnKey
    const toColumn = column.dataset.kanbanColumnKeyValue

    // Cards currently in the destination column, excluding the dragged card
    // itself (it may already be there for a same-column reorder).
    const existingCards = [...column.querySelectorAll("[data-kanban-record-id]")]
      .filter(c => c !== this.draggedCard)

    const toIndex = this.#computeDropIndex(event.clientY, existingCards)

    // Columns that declare a drop_interaction, on a CROSS-column drop:
    //   • immediate (input-less) interaction  → commit directly via the normal
    //     POST (the server runs the interaction with no params); honour an
    //     optional confirmation first. No empty modal.
    //   • input-collecting interaction         → open the interaction modal; the
    //     card is left in place until the modal resolves.
    // Same-column reorders (from == toColumn) fall through to the direct POST,
    // which the server treats as positioning-only — mirroring the server's rule.
    const destWrapper = column.closest("[data-kanban-col]")
    if (destWrapper?.dataset.kanbanDropInteraction === "true" && fromColumn !== toColumn) {
      if (destWrapper.dataset.kanbanDropImmediate === "true") {
        const confirmMsg = destWrapper.dataset.kanbanDropConfirm
        // Abort on decline — the card was never moved in the DOM, so there is
        // nothing to restore.
        if (confirmMsg && !window.confirm(confirmMsg)) return
        // fall through to #submitMove (direct commit, no modal)
      } else if (this.#openDropInteraction(destWrapper, { recordId, fromColumn, toColumn, toIndex })) {
        return
      }
      // Immediate (confirmed), or the modal frame was unavailable — fall through
      // to the direct POST so a drop is never silently dropped.
    }

    this.#submitMove(recordId, { fromColumn, toColumn, toIndex })
  }

  // Direct move: POST {from_column, to_column, to_index} to the move endpoint
  // and feed the Turbo Stream response to Turbo. On success the server
  // re-renders the from + to column frames; on 422 it re-renders only the
  // source frame so the card snaps back — the controller never hand-manages
  // rollback state.
  async #submitMove(recordId, { fromColumn, toColumn, toIndex }) {
    const url = this.moveUrlTemplateValue.replace("__ID__", recordId)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content ?? ""

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken,
        },
        body: new URLSearchParams({
          from_column: fromColumn,
          to_column: toColumn,
          to_index: toIndex,
        }),
        credentials: "same-origin",
      })

      // Only feed genuine Turbo Stream responses to Turbo. A rejected move can
      // come back as a plain HTML document — e.g. a 403 Unauthorized renders an
      // error page, not a stream. Passing that to renderStreamMessage makes
      // Turbo morph the error page's markup into the board (the "page turns red"
      // bug). Native HTML5 DnD never re-parented the card, so on a non-stream
      // rejection there is nothing to snap back — the board already shows the
      // card in its source column.
      const contentType = response.headers.get("Content-Type") || ""
      const isTurboStream = contentType.includes("text/vnd.turbo-stream.html")

      if (isTurboStream && window.Turbo) {
        const body = await response.text()
        // #onBeforeStreamRender re-asserts the persisted collapse state for each
        // column the stream re-renders (synchronously, before paint), so the
        // move doesn't reset a column the user expanded/collapsed.
        Turbo.renderStreamMessage(body)
      } else if (!response.ok) {
        console.error(`[kanban] move rejected (${response.status}); leaving card in place`)
      }
    } catch (error) {
      console.error("[kanban] move request failed:", error)
    }
  }

  // ─── drop-interaction modal ────────────────────────────────────────────────
  //
  // A cross-column drop into a drop_interaction column opens the interaction's
  // form in the shared remote-modal frame instead of committing the move.
  //
  // Native HTML5 drag-and-drop never re-parents the card's DOM node — the card
  // physically stays in its SOURCE column throughout, so there is nothing to
  // snap back on cancel: dismissing the modal simply leaves the board as it
  // already is. On success the server's turbo-stream re-renders the kanban-col-*
  // frames and empties the remote_modal frame, so the board updates naturally.
  //
  // Returns true when the modal was opened (caller should stop), false when the
  // remote-modal frame is unavailable (caller falls back to the direct POST).
  #openDropInteraction(destWrapper, { recordId, fromColumn, toColumn, toIndex }) {
    const template = destWrapper.dataset.kanbanDropFormUrlTemplate
    // Plutonium::REMOTE_MODAL_FRAME — rendered once by the layout, outside this
    // (permanent) board element.
    const frame = document.getElementById("remote_modal")
    if (!frame || !template) return false

    const params = new URLSearchParams({
      from_column: fromColumn,
      to_column: toColumn,
      to_index: toIndex,
    })
    const url = `${template.replace("__ID__", recordId)}?${params.toString()}`

    // Point the modal frame at the interaction form. On success the server
    // empties this frame; on 422 it re-renders the form (errors + preserved
    // hidden fields) in place.
    frame.src = url
    return true
  }

  #onDragEnd(_event) {
    this.#clearHighlights()
    this.#clearDropHints()
    if (this.draggedCard) {
      this.draggedCard.classList.remove("pu-kanban-dragging")
      this.draggedCard = null
    }
  }

  // ─── drop hints ──────────────────────────────────────────────────────────────

  // Marks each column wrapper with `pu-kanban-no-drop` when it would refuse
  // a card dragged from sourceKey. The server remains the authority; this
  // is a display-only hint to give the user immediate visual feedback.
  #applyDropHints(sourceKey) {
    // If the source column is locked, no card can leave it — all targets are
    // effectively invalid.
    const sourceWrapper = this.element.querySelector(`[data-kanban-col="${sourceKey}"]`)
    const sourceLocked = sourceWrapper?.dataset.kanbanLocked === "true"

    this.element.querySelectorAll("[data-kanban-col]").forEach(wrapper => {
      const noDrop = sourceLocked || !this.#columnAccepts(wrapper.dataset.kanbanAccepts, sourceKey)
      wrapper.classList.toggle("pu-kanban-no-drop", noDrop)
    })
  }

  #clearDropHints() {
    this.element.querySelectorAll("[data-kanban-col]")
      .forEach(w => w.classList.remove("pu-kanban-no-drop"))
  }

  // Returns true if the column described by `accepts` (the serialised form
  // from data-kanban-accepts) would accept a card from `sourceKey`.
  #columnAccepts(accepts, sourceKey) {
    if (!accepts || accepts === "all") return true
    if (accepts === "none") return false
    return accepts.split(",").map(k => k.trim()).includes(sourceKey)
  }

  // ─── collapse persistence (cookie delta) ───────────────────────────────────
  //
  // The cookie stores ONLY the column keys whose state differs from the server
  // default, comma-joined (e.g. "todo,done"). The server reads it and renders
  // each column in the user's state directly, so there's no client re-apply and
  // no FOUC on any render path. The delta encoding keeps it compact and
  // self-trimming: a board at its defaults has no cookie, and toggling a column
  // back to default drops its key (and an empty set deletes the cookie).

  // `flipped` = the column's state now differs from its default.
  #persistCollapse(key, flipped) {
    const keys = new Set(this.#readCollapseCookie())
    if (flipped) keys.add(key)
    else keys.delete(key)
    this.#writeCollapseCookie([...keys])
  }

  #readCollapseCookie() {
    const name = this.collapseCookieValue
    if (!name) return []
    const entry = document.cookie.split("; ").find(c => c.startsWith(`${name}=`))
    if (!entry) return []
    return decodeURIComponent(entry.slice(name.length + 1)).split(",").filter(Boolean)
  }

  #writeCollapseCookie(keys) {
    const name = this.collapseCookieValue
    if (!name) return
    const path = this.collapsePathValue || "/"
    if (keys.length === 0) {
      // Board back to all-defaults — drop the cookie entirely.
      document.cookie = `${name}=; path=${path}; max-age=0; SameSite=Lax`
      return
    }
    const value = encodeURIComponent(keys.join(","))
    // ~6 months: refreshed on every toggle, so boards in active use persist and
    // stale ones expire on their own — another guard against unbounded growth.
    document.cookie = `${name}=${value}; path=${path}; max-age=${60 * 60 * 24 * 180}; SameSite=Lax`
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  // Returns the 0-based insertion index within the destination column by
  // comparing the cursor y-position against each card's vertical midpoint.
  // The card is inserted before the first card whose midpoint is below the
  // cursor, or appended after all cards if the cursor is below every midpoint.
  #computeDropIndex(clientY, cards) {
    for (let i = 0; i < cards.length; i++) {
      const rect = cards[i].getBoundingClientRect()
      if (clientY < rect.top + rect.height / 2) return i
    }
    return cards.length
  }

  #highlightColumn(column) {
    this.columnTargets.forEach(c => {
      c.classList.toggle("pu-kanban-drop-target", c === column)
    })
  }

  #clearHighlights() {
    this.columnTargets.forEach(c => c.classList.remove("pu-kanban-drop-target"))
  }
}
