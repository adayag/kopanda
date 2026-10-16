import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts", "test/**/*.test.tsx"],
    // A file opts into jsdom with a `// @vitest-environment jsdom` docblock; the setup file acts only in those.
    environment: "node",
    setupFiles: ["test/ui/setup.ts"],
  },
});
