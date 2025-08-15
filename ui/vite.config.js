import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    host: true,
    port: 5173,
    strictPort: true,
    allowedHosts: 'all',
    // HMR over Cloudflare/HTTPS:
    hmr: {
      clientPort: 443,
      host: 'linksmlm.com',
      protocol: 'wss'
    },
    // Proxy removed - API is served directly through Cloudflare Tunnel
  },
  preview: {
    port: 5173,
    strictPort: true
  }
})