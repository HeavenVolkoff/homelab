const handleHref = () => {
  for (const element of document.querySelectorAll("article")) {
    const anchor = element.querySelector('a[href]')
    if (!anchor) continue

    element.dataset.href = anchor.href

    const redirect = event => {
      if ((!('isPrimary' in event) || event.isPrimary) && event.button === 0) {
        window.location = anchor.href
        event.preventDefault()
      }
    }

    if ('PointerEvent' in window) {
      element.addEventListener("pointerup", redirect)
    } else {
      element.addEventListener("click", redirect)
    }
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", handleHref)
} else {
  handleHref()
}
