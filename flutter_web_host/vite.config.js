import { defineConfig } from 'vite';

export default defineConfig({
  root: './',
  publicDir: 'build/web', // папка Flutter Web билда
  server: {
    port: 5173, // можно изменить, если хочешь
    open: true,
  },
  build: {
    outDir: 'dist', // куда соберётся сайт после билда
  },
});
