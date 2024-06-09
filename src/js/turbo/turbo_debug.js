[
  'turbo:click',
  'turbo:before-visit',
  'turbo:visit',
  'turbo:submit-start',
  'turbo:before-fetch-request',
  'turbo:before-fetch-response',
  'turbo:submit-end',
  'turbo:before-cache',
  'turbo:before-render',
  'turbo:before-stream-render',
  'turbo:render',
  'turbo:load',
  'turbo:before-frame-render',
  'turbo:frame-render',
  'turbo:frame-load',
  'turbo:frame-missing',
  'turbo:fetch-request-error',
  'turbo:reload', // https://github.com/hotwired/turbo/pull/556
  'turbo:morph',
  'turbo:before-morph-element',
  'turbo:morph-attribute',
  'turbo:morph',
].forEach(eventName => {
  document.addEventListener(eventName, (event) => {
    console.log(event.type, event);
  });
});
