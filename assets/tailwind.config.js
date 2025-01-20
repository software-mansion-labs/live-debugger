// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
const colors = require('tailwindcss/colors');
const plugin = require('tailwindcss/plugin');
const fs = require('fs');
const path = require('path');

module.exports = {
  darkMode: 'selector',
  content: ['./js/**/*.js', '../lib/**/*.ex'],
  safelist: [
    {
      pattern:
        /(text|bg|border)-(primary|secondary|success|danger|warning|info|gray)-(50|100|200|300|400|500|600|700|800|900|950)/,
      variants: ['hover', 'focus', 'active', 'md', 'lg', 'sm'],
    },
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#001A72',
          50: '#2B5BFF',
          100: '#164BFF',
          200: '#0036EC',
          300: '#002DC4',
          400: '#00239B',
          500: '#001A72',
          600: '#00155E',
          700: '#001149',
          800: '#000C35',
          900: '#000720',
          950: '#000516',
        },
        secondary: colors.pink,
        success: colors.green,
        danger: colors.red,
        warning: colors.yellow,
        info: colors.sky,
        gray: colors.gray,
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    plugin(({ addVariant }) =>
      addVariant('phx-click-loading', [
        '&.phx-click-loading',
        '.phx-click-loading &',
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-submit-loading', [
        '&.phx-submit-loading',
        '.phx-submit-loading &',
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-change-loading', [
        '&.phx-change-loading',
        '.phx-change-loading &',
      ])
    ),
    // Plugin for adding Heroicons
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, './icons/heroicons/');
      let values = {};
      let icons = [
        ['', '/24/outline'],
        ['-solid', '/24/solid'],
        ['-mini', '/20/solid'],
        ['-micro', '/16/solid'],
      ];
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, '.svg') + suffix;
          values[name] = {
            name,
            fullPath: path.join(iconsDir, dir, file),
          };
        });
      });
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, '');
            let size = theme('spacing.6');
            if (name.endsWith('-mini')) {
              size = theme('spacing.5');
            } else if (name.endsWith('-micro')) {
              size = theme('spacing.4');
            }
            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              '-webkit-mask': `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              'mask-repeat': 'no-repeat',
              'background-color': 'currentColor',
              'vertical-align': 'middle',
              display: 'inline-block',
              width: size,
              height: size,
            };
          },
        },
        { values }
      );
    }),
  ],
};
