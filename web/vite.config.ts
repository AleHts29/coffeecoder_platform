import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'

// En desarrollo la PWA habla con la API por proxy (mismo origen → sin CORS
// ni cookies cross-site). API_URL permite apuntar a otro puerto.
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    // Service worker mínimo: precachea el shell (assets con hash) y se
    // actualiza solo. La API nunca se cachea; el video va directo al CDN.
    VitePWA({
      registerType: 'autoUpdate',
      manifest: false, // usamos public/manifest.webmanifest
      workbox: {
        globPatterns: ['**/*.{js,css,html,woff2,svg}'],
        navigateFallbackDenylist: [/^\/api\//],
        runtimeCaching: [],
      },
      devOptions: { enabled: false },
    }),
  ],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  server: {
    port: 5173,
    proxy: {
      '/api': { target: process.env.API_URL ?? 'http://localhost:8081', changeOrigin: true },
    },
  },
})
