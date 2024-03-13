/** @type {import('tailwindcss').Config} */

const colors = require('tailwindcss/colors');

let safelist = [];
Object.keys(colors).forEach((color) => {
  if (typeof colors[color] === 'object') {
    Object.keys(colors[color]).forEach((shade) => {
      safelist.push(`bg-${color}-${shade}`);
      safelist.push(`text-${color}-${shade}`);
      // Add other utilities as needed
    });
  }
});

module.exports = {
  content: [
    "./app/assets/**/*.css",
    "./app/views/**/*.{rb,erb}",
    "./node_modules/flowbite/**/*.js",
    "./lib/plutonium/initializers/simple_form.rb"
  ],
  darkMode: "selector",
  plugins: [
    require('@tailwindcss/forms'),
    require('flowbite/plugin'),
  ],
  theme: {
    extend: {
      colors: {
        primary: { "50": "#fffbeb", "100": "#fef3c7", "200": "#fde68a", "300": "#fcd34d", "400": "#fbbf24", "500": "#f59e0b", "600": "#d97706", "700": "#b45309", "800": "#92400e", "900": "#78350f", "950": "#451a03" }
      },
      screens: {
        'xs': '475px',
      },
    },
    fontFamily: {
      'body': [
        'Lato',
        'ui-sans-serif',
        'system-ui',
        '-apple-system',
        'system-ui',
        'Segoe UI',
        'Roboto',
        'Helvetica Neue',
        'Arial',
        'Noto Sans',
        'sans-serif',
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'Segoe UI Symbol',
        'Noto Color Emoji'
      ],
      'sans': [
        'Lato',
        'ui-sans-serif',
        'system-ui',
        '-apple-system',
        'system-ui',
        'Segoe UI',
        'Roboto',
        'Helvetica Neue',
        'Arial',
        'Noto Sans',
        'sans-serif',
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'Segoe UI Symbol',
        'Noto Color Emoji'
      ]
    }
  },
  safelist: safelist,
}
