// data-dev:styles-tailwind-config
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx,js,jsx}'],
  theme: {
    extend: {
      colors: {
        jade: { 
          DEFAULT: '#00A86B', 
          light: '#33B98D', 
          900: '#0B3F2F' 
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