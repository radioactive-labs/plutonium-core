// Add a redirect stream action
Turbo.StreamActions.redirect = function () {
  // See: https://github.com/hotwired/turbo/issues/554
  Turbo.cache.clear();

  const url = this.getAttribute("url")
  Turbo.visit(url)
}

// Closes the <dialog> rendered inside the targeted turbo-frame and
// empties the frame so the dialog can be re-opened later. Used by the
// stacked-modal flow: after a successful create inside the secondary
// modal, the server tells the browser to dismiss it.
Turbo.StreamActions.close_frame = function () {
  const frameId = this.getAttribute("target")
  if (!frameId) return

  const frame = document.getElementById(frameId)
  if (!frame) return

  const dialog = frame.querySelector("dialog")
  if (dialog && typeof dialog.close === "function") dialog.close()

  // Clearing the frame's content keeps a future visit to the same URL
  // re-fetching (turbo would otherwise treat the frame as cached).
  frame.innerHTML = ""
  frame.removeAttribute("src")
}

// Reloads the targeted turbo-frame from its current src. Used after a
// secondary-modal action mutates data the primary modal depends on
// (e.g. a newly created association option) so the primary re-renders.
Turbo.StreamActions.reload_frame = function () {
  const frameId = this.getAttribute("target")
  if (!frameId) return

  const frame = document.getElementById(frameId)
  if (!frame || typeof frame.reload !== "function") return

  frame.reload()
}
