/** @type {import('tailwindcss').Config} */

const options = require("./tailwind.options.js")

export const content = options.content
export const darkMode = options.darkMode
export const plugins = options.plugins.map((plugin) => require(plugin))
export const theme = options.theme
export const safelist = options.safelist
