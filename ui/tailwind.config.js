// data-dev:styles-tailwind-config
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx,js,jsx}'],
  theme: {
    extend: {
      colors: {
        jade: { 
          50: '#e6faf2',
          100: '#c0f0db',
          200: '#96e5c3',
          300: '#69d8aa',
          400: '#3fcb93',
          500: '#19bd7f',
          600: '#00A36C',
          700: '#07885a',
          800: '#0b6d4a',
          900: '#0c5a3e',
          DEFAULT: '#00A86B', 
          light: '#33B98D'
        },
        ink: '#0A0A0A',
        'text-primary': '#FFFFFF',
        'text-secondary': '#B3B3B3',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      backgroundImage: {
        'ink-gradient': 'radial-gradient(600px 300px at 10% 10%, rgba(0,168,107,0.12), transparent 60%)',
      },
      backdropBlur: {
        xs: '2px',
      }
    },
  },
  plugins: [],
}