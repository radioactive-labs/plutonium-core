// Monkeypatch to fix turbo issue of wrong turbo-frame
// See: https://github.com/hotwired/turbo/pull/579
document.addEventListener("turbo:before-fetch-request", (event) => {
  const targetTurboFrame = event.target.getAttribute("data-turbo-frame");
  const fetchTurboFrame = event.detail.fetchOptions.headers["Turbo-Frame"];
  if (
    targetTurboFrame &&
    targetTurboFrame != fetchTurboFrame &&
    document.querySelector(`turbo-frame#${targetTurboFrame}`)
  ) {
    event.detail.fetchOptions.headers["Turbo-Frame"] = targetTurboFrame;
  }
});

// // Reload the entire page if we are missing a frame
// // See: https://stackoverflow.com/a/75704489/644571
// document.addEventListener("turbo:frame-missing", (event) => {
//   if (event.target.id != 'modal') return

//   const { detail: { response, visit } } = event;
//   event.preventDefault();
//   visit(response);
// });
