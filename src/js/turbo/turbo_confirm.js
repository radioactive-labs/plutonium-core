// Themed replacement for Turbo's default window.confirm. The dialog is
// built lazily and reused so per-call cost is just a textContent swap.

let dialog;
let messageEl;
let confirmButton;
let cancelButton;

function ensureDialog() {
  // Turbo Drive replaces document.body on full-page navigation, which
  // detaches the cached dialog. showModal() then throws InvalidStateError
  // ("not in a Document"). Re-attach if detached; the node itself plus
  // its listeners survive, so we don't have to rebuild.
  if (dialog) {
    if (!dialog.isConnected) document.body.appendChild(dialog);
    return;
  }

  dialog = document.createElement("dialog");
  // Surface (bg, border, radius, backdrop) comes from .pu-dialog; the
  // remaining utilities are positioning, size, and the opacity/scale
  // animation hooks driven by [data-open]. Matches Modal::Centered.
  dialog.className = [
    "pu-dialog",
    "top-1/2",
    "-translate-y-1/2",
    "left-1/2",
    "-translate-x-1/2",
    "w-full",
    "max-w-md",
    "p-0",
    "open:flex",
    "flex-col",
    "opacity-0",
    "scale-95",
    "data-[open]:opacity-100",
    "data-[open]:scale-100",
    "transition-[opacity,scale]",
    "duration-200",
    "ease-out",
  ].join(" ");
  dialog.setAttribute("aria-labelledby", "pu-turbo-confirm-message");

  const header = document.createElement("div");
  header.className = "px-6 pt-5 pb-4 border-b border-[var(--pu-border)]";

  messageEl = document.createElement("h2");
  messageEl.id = "pu-turbo-confirm-message";
  messageEl.className = "text-lg font-semibold text-[var(--pu-text)]";
  header.appendChild(messageEl);

  const footer = document.createElement("div");
  footer.className = "flex items-center justify-end gap-2 px-6 py-4";

  cancelButton = document.createElement("button");
  cancelButton.type = "button";
  cancelButton.className = "pu-btn pu-btn-md pu-btn-outline";
  cancelButton.textContent = "Cancel";

  confirmButton = document.createElement("button");
  confirmButton.type = "button";
  confirmButton.className = "pu-btn pu-btn-md pu-btn-primary";
  confirmButton.textContent = "Confirm";

  footer.appendChild(cancelButton);
  footer.appendChild(confirmButton);

  dialog.appendChild(header);
  dialog.appendChild(footer);
  document.body.appendChild(dialog);
}

async function animateClose() {
  dialog.removeAttribute("data-open");
  const animations = dialog.getAnimations({ subtree: true });
  await Promise.allSettled(animations.map((a) => a.finished));
  if (dialog.open) dialog.close();
}

function themedConfirm(message) {
  ensureDialog();
  messageEl.textContent = message || "Are you sure?";

  return new Promise((resolve) => {
    let settled = false;

    const settle = (value) => {
      if (settled) return;
      settled = true;
      cleanup();
      resolve(value);
      animateClose();
    };

    const onConfirm = () => settle(true);
    const onCancel = () => settle(false);
    const onClose = () => settle(false);

    const cleanup = () => {
      confirmButton.removeEventListener("click", onConfirm);
      cancelButton.removeEventListener("click", onCancel);
      dialog.removeEventListener("close", onClose);
    };

    confirmButton.addEventListener("click", onConfirm);
    cancelButton.addEventListener("click", onCancel);
    // Esc / backdrop / programmatic close — all resolve as cancel.
    dialog.addEventListener("close", onClose);

    dialog.showModal();
    // Double rAF so the closed-state styles paint before [data-open]
    // flips — same rationale as remote_modal_controller.
    requestAnimationFrame(() => {
      requestAnimationFrame(() => dialog.setAttribute("data-open", ""));
    });
    confirmButton.focus();
  });
}

if (typeof window !== "undefined" && window.Turbo) {
  // Turbo 8 deprecated setConfirmMethod in favor of config.forms.confirm.
  // Prefer the new path; fall back for older Turbo versions still in use.
  if (window.Turbo.config?.forms) {
    window.Turbo.config.forms.confirm = themedConfirm;
  } else if (window.Turbo.setConfirmMethod) {
    window.Turbo.setConfirmMethod(themedConfirm);
  }
}
