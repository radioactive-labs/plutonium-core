// Add a redirect stream action
Turbo.StreamActions.redirect = function () {
  // See: https://github.com/hotwired/turbo/issues/554
  Turbo.cache.clear();

  const url = this.getAttribute("url")
  Turbo.visit(url)
}
