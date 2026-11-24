import { svelte } from "@sveltejs/vite-plugin-svelte";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const webRoot = fileURLToPath(new URL(".", import.meta.url));

export default defineConfig({
  root: webRoot,
  base: "./",
  plugins: [svelte()],
  server: {
    fs: { allow: [resolve(webRoot, "..")] },
  },
  build: {
    outDir: resolve(webRoot, "dist"),
    emptyOutDir: true,
    assetsDir: "assets",
    sourcemap: false,
  },
});
