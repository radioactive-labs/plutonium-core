export const content = [
  `${__dirname}/src/**/*.{css,js}`,
  `${__dirname}/app/views/**/*.{rb,erb,js}`,
  `${__dirname}/config/initializers/simple_form.rb`,
  `${__dirname}/lib/plutonium/**/*.rb`,

  // node modules are not packaged as part of the gem.
  // requires users to have flowbite installed in their own project.
  './node_modules/flowbite/**/*.js',
];
export const darkMode = "selector";
export const plugins = [
  // requires users to have the required packages installed in their own project.
  "@tailwindcss/forms",
  "flowbite/plugin"
];
export const theme = {
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
    ],
    'mono': [
      'ui-monospace',
      'SFMono-Regular',
      'Menlo',
      'Monaco',
      'Consolas',
      'Liberation Mono',
      'Courier New',
      'monospace'
    ]
  }
};

export const safelist = [];

// // Object.keys(colors).forEach((color) => {
// //   if (typeof colors[color] === 'object') {
// //     Object.keys(colors[color]).forEach((shade) => {
// //       safelist.push(`bg-${color}-${shade}`);
// //       safelist.push(`text-${color}-${shade}`);
// //       // Add other utilities as needed
// //     });
// //   }
// // });
// export const safelist = _safelist;
