/** @type {import('tailwindcss').Config} */

const tailwindPlugin = require('tailwindcss/plugin')
const options = require("./tailwind.options.js")

export const content = options.content
export const darkMode = options.darkMode
export const plugins = options.plugins.map(function (plugin) {
  switch (typeof plugin) {
    case "function":
      return tailwindPlugin(plugin)
    case "string":
      return require(plugin)
    default:
      throw Error(`unsupported plugin: ${plugin}: ${(typeof plugin)}`)
  }
})
export const theme = options.theme
export const safelist = options.safelist
