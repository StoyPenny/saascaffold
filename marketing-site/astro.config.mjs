import { defineConfig } from 'astro/config';

export default defineConfig({
  site: process.env.SITE_URL || 'http://marketing.localhost',

  vite: {
    server: {
      host: '0.0.0.0',
      port: 4321,
      watch: {
        // Required for file watching to work through Docker volume mounts on
        // Linux/WSL2 where inotify events don't propagate reliably.
        usePolling: true,
        interval: 300,
      },
    },
  },
});
