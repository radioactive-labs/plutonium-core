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
    "./lib/plutonium/initializers/simple_form.rb",
    // TODO: temporary workaround for buttons flex basis hack.
    // To be removed after moving buttons_helper to components.
    "./lib/plutonium/**/*.{rb,erb}"
  ],
  darkMode: "selector",
  plugins: [
    require('@tailwindcss/forms'),
    require('flowbite/plugin'),
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          '50': '#f0f7fe',
          '100': '#ddecfc',
          '200': '#c3dffa',
          '300': '#99ccf7',
          '400': '#69b0f1',
          '500': '#4691eb',
          '600': '#3174df',
          '700': '#285fcc',
          '800': '#274ea6',
          '900': '#244484',
          '950': '#1b2b50',
        },
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
