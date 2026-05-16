// Themed replacement for Turbo's default window.confirm. The dialog is
// built lazily and reused so per-call cost is just a textContent swap.

let dialog;
let messageEl;
let confirmButton;
let cancelButton;

function ensureDialog() {
  if (dialog) return;

  dialog = document.createElement("dialog");
  dialog.className = [
    "pu-confirm-dialog",
    "rounded-[var(--pu-radius-lg)]",
    "bg-[var(--pu-surface)]",
    "border",
    "border-[var(--pu-border)]",
    "backdrop:bg-black/60",
    "backdrop:backdrop-blur-sm",
    "top-1/2",
    "-translate-y-1/2",
    "left-1/2",
    "-translate-x-1/2",
    "w-full",
    "max-w-md",
    "p-0",
    "hidden",
    "open:flex",
    "flex-col",
    "opacity-0",
    "open:opacity-100",
    "transition-opacity",
    "duration-200",
    "ease-in-out",
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

function themedConfirm(message) {
  ensureDialog();
  messageEl.textContent = message || "Are you sure?";

  return new Promise((resolve) => {
    let settled = false;

    const settle = (value) => {
      if (settled) return;
      settled = true;
      resolve(value);
      cleanup();
      if (dialog.open) dialog.close();
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
    confirmButton.focus();
  });
}

if (typeof window !== "undefined" && window.Turbo?.setConfirmMethod) {
  window.Turbo.setConfirmMethod(themedConfirm);
}
