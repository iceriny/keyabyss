import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { viteSingleFile } from "vite-plugin-singlefile";
import { audioPreview } from './tools/audio-preview-plugin.ts';
import { appDefine } from './tools/app-metadata.mjs';
export default defineConfig({
  base: "./",
  define: appDefine,
  server: { host: "127.0.0.1", port: 4318 },
  plugins: [react(), viteSingleFile(), audioPreview()],
  build: { target: "es2022", sourcemap: false, reportCompressedSize: false },
});
