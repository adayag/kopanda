import { afterEach } from "vitest";

// Vitest runs this before every test file. Only the files that ask for jsdom (`// @vitest-environment jsdom`)
// have a document, and only they get the DOM matchers and the clean-up below.
if (typeof document !== "undefined") {
  await import("@testing-library/jest-dom/vitest");
  const { cleanup } = await import("@testing-library/react");

  afterEach(() => {
    cleanup();
  });
}
