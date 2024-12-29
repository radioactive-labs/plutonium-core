import DOMPurify from 'dompurify';

export default class {
  static fromTemplate(template) {
    if (DOMPurify.isSupported) {
      return DOMPurify.sanitize(template, { USE_PROFILES: { html: true, svg: true }, RETURN_DOM: true }).children[0]
    }
    else {
      const html = new DOMParser().parseFromString(template, 'text/html').body.children[0]
      return santizeHTML(html)
    }
  }
}


// https://vanillajstoolkit.com/helpers/cleanhtml/

/*!
 * Sanitize an HTML node
 */
function santizeHTML(html) {
  // Sanitize it
  removeScripts(html)
  cleanAttributes(html)

  return html
}

/**
 * Remove <script> elements
 * @param  {Node} html The HTML
 */
function removeScripts(html) {
  let scripts = html.querySelectorAll('script')
  for (let script of scripts) {
    script.remove()
  }
}

/**
 * Check if the attribute is potentially dangerous
 * @param  {String}  name  The attribute name
 * @param  {String}  value The attribute value
 * @return {Boolean}       If true, the attribute is potentially dangerous
 */
function isPossiblyDangerous(name, value) {
  let val = value.replace(/\s+/g, '').toLowerCase()
  if (['src', 'href', 'xlink:href'].includes(name)) {
    if (val.includes('javascript:') || val.includes('data:')) return true
  }
  if (name.startsWith('on')) return true
}

/**
 * Remove potentially dangerous attributes from an element
 * @param  {Node} elem The element
 */
function removePossiblyDangerousAttributes(elem) {
  // Loop through each attribute
  // If it's dangerous, remove it
  let atts = elem.attributes
  for (let { name, value } of atts) {
    if (!isPossiblyDangerous(name, value)) continue
    elem.removeAttribute(name)
  }
}

/**
 * Remove dangerous stuff from the HTML document's nodes
 * @param  {Node} html The HTML document
 */
function cleanAttributes(html) {
  let nodes = html.children
  for (let node of nodes) {
    removePossiblyDangerousAttributes(node)
    cleanAttributes(node)
  }
}
