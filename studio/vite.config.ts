import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { loadConfig } from "./src/server/config.js";

const serverPort = loadConfig().port;

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { "/api": `http://127.0.0.1:${serverPort}` },
  },
  build: { outDir: "dist/ui", emptyOutDir: true },
});
