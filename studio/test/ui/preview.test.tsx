// @vitest-environment jsdom
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { schema } from "../../src/schema";
import { App } from "../../src/ui/App";
import type { Settings } from "../../src/ui/api";

const colorsoft = {
  id: "colorsoft",
  name: "Colorsoft",
  device: "Kindle Colorsoft SE",
  width: 1264,
  height: 1680,
  dpi: 300,
  color: true,
  has_settings: true,
  settings_path: "/home/owner/kopanda-profiles/colorsoft/settings/kopanda/settings.lua",
};

const paperwhite = {
  id: "paperwhite",
  name: "Paperwhite",
  device: "Kindle Paperwhite",
  width: 1236,
  height: 1648,
  dpi: 300,
  color: false,
  has_settings: false,
  settings_path: "/home/owner/kopanda-profiles/paperwhite/settings/kopanda/settings.lua",
};

const defaults = Object.fromEntries(schema.keys.map((key) => [key.id, key.default]));

function settings(values: Record<string, unknown> = {}): Settings {
  return {
    path: colorsoft.settings_path,
    exists: true,
    state: "writable",
    schema_version: 1,
    values: { ...defaults, ...values },
    invalid: [],
    unknown: [],
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function png(): Response {
  return new Response(new Uint8Array([0x89, 0x50, 0x4e, 0x47]), {
    status: 200,
    headers: { "content-type": "image/png" },
  });
}

/** One preview request the stub holds open until the test answers it. */
interface Render {
  url: string;
  look: string;
  night: boolean;
  signal: AbortSignal;
  answer: (res: Response) => void;
}

let renders: Render[] = [];
/** The settings each profile's GET answers and each PUT starts from. */
let stored: Record<string, Settings> = {};
/** The status a PUT answers; 200 writes the value. */
let putStatus = 200;

const fetchMock = vi.fn<typeof fetch>();

function stub(): void {
  fetchMock.mockImplementation((input, init) => {
    const url = String(input);
    const method = init?.method ?? "GET";
    const preview = /^\/api\/profiles\/([^/]+)\/preview$/.exec(url);
    if (method === "POST" && preview) {
      const body = JSON.parse(String(init?.body)) as { look: string; night: boolean };
      const signal = init!.signal!;
      return new Promise<Response>((resolve, reject) => {
        signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
        renders.push({ url, ...body, signal, answer: resolve });
      });
    }
    const put = /^\/api\/profiles\/([^/]+)\/settings\/(.+)$/.exec(url);
    if (method === "PUT" && put) {
      if (putStatus !== 200) return Promise.resolve(json({ error: "refused" }, putStatus));
      const id = put[1]!;
      const { value } = JSON.parse(String(init?.body)) as { value: unknown };
      stored[id] = { ...stored[id]!, values: { ...stored[id]!.values, [decodeURIComponent(put[2]!)]: value } };
      return Promise.resolve(json(stored[id]));
    }
    if (url === "/api/profiles/colorsoft") return Promise.resolve(json(colorsoft));
    if (url === "/api/profiles/paperwhite") return Promise.resolve(json(paperwhite));
    const settingsGet = /^\/api\/profiles\/([^/]+)\/settings$/.exec(url);
    if (settingsGet && stored[settingsGet[1]!]) return Promise.resolve(json(stored[settingsGet[1]!]));
    if (url === "/api/health") return Promise.resolve(json({ ok: true, host: "127.0.0.1", port: 4490, addresses: [] }));
    if (url.startsWith("/api/push/"))
      return Promise.resolve(json({ format: 1, profile: "x", hash: "0".repeat(64), files: [] }));
    return Promise.reject(new Error(`unexpected fetch ${method} ${url}`));
  });
}

/** Lets `ms` of fake time pass, settling every promise along the way. */
async function tick(ms = 0): Promise<void> {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(ms);
  });
}

/** Answers the render at index i with an image. */
async function succeed(i: number): Promise<void> {
  renders[i]!.answer(png());
  await tick();
}

/** Answers the render at index i with a failure. */
async function fail(i: number, status = 502, error = "The emulator crashed", log: string[] = []): Promise<void> {
  renders[i]!.answer(json({ error, log }, status));
  await tick();
}

/** Opens the profile at hash and waits for its screen. */
async function open(hash = "#/profiles/colorsoft") {
  history.replaceState(null, "", `/${hash}`);
  const result = render(<App />);
  await tick();
  expect(screen.getByRole("heading", { level: 1 })).toBeInTheDocument();
  return result;
}

function pane(): HTMLElement {
  return screen.getByRole("region", { name: "Preview" });
}

function frames(): HTMLElement[] {
  return within(pane()).queryAllByRole("figure");
}

function captions(): (string | null)[] {
  return frames().map((f) => f.querySelector("figcaption")!.textContent);
}

function frame(name: string): HTMLElement {
  return within(pane()).getByRole("figure", { name });
}

function image(name: string): HTMLImageElement | null {
  return within(frame(name)).queryByRole("img") as HTMLImageElement | null;
}

function rerender(): HTMLButtonElement {
  return within(pane()).getByRole("button", { name: "Re-render" });
}

/** Lands a write through the form: the stats toggle flipped. */
async function write(): Promise<void> {
  const box = screen.getByRole("checkbox", { name: "Show reading stats" });
  fireEvent.click(box);
  await tick();
}

let urls = 0;
const createObjectURL = vi.fn<(blob: Blob) => string>(() => `blob:preview-${++urls}`);
const revokeObjectURL = vi.fn<(url: string) => void>();

beforeEach(() => {
  vi.useFakeTimers();
  history.replaceState(null, "", "/");
  renders = [];
  urls = 0;
  putStatus = 200;
  stored = { colorsoft: settings(), paperwhite: { ...settings(), path: paperwhite.settings_path, exists: false } };
  fetchMock.mockReset();
  stub();
  vi.stubGlobal("fetch", fetchMock);
  createObjectURL.mockClear();
  revokeObjectURL.mockClear();
  URL.createObjectURL = createObjectURL;
  URL.revokeObjectURL = revokeObjectURL;
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe("the preview pane", () => {
  it("names the profile, its device and resolution, on the form and both editors", async () => {
    await open();
    expect(within(pane()).getByText("Colorsoft")).toBeInTheDocument();
    expect(within(pane()).getByText("Kindle Colorsoft SE · 1264×1680")).toBeInTheDocument();
    expect(within(pane()).getByRole("checkbox", { name: "Both looks" })).not.toBeChecked();
    expect(within(pane()).getByRole("checkbox", { name: "Night" })).not.toBeChecked();
    expect(rerender()).toBeInTheDocument();

    for (const view of ["layout", "launcher"]) {
      history.replaceState(null, "", `/#/profiles/colorsoft/${view}`);
      await act(async () => {
        window.dispatchEvent(new HashChangeEvent("hashchange"));
        await vi.advanceTimersByTimeAsync(0);
      });
      expect(within(pane()).getByText("Kindle Colorsoft SE · 1264×1680")).toBeInTheDocument();
    }
  });

  it("renders the profile's look at once, then shows the image and how long it took", async () => {
    stored.colorsoft = settings({ look: "editorial" });
    await open();

    expect(frames()).toHaveLength(1);
    expect(frame("Editorial")).toBeInTheDocument();
    expect(renders.map(({ url, look, night }) => ({ url, look, night }))).toEqual([
      { url: "/api/profiles/colorsoft/preview", look: "editorial", night: false },
    ]);
    expect(within(frame("Editorial")).getByText("Rendering in the emulator…")).toBeInTheDocument();
    expect(image("Editorial")).toBeNull();

    await tick(9_400);
    await succeed(0);

    expect(within(frame("Editorial")).getByText("Rendered in 9.4 s")).toBeInTheDocument();
    expect(image("Editorial")).toHaveAttribute("src", "blob:preview-1");
    expect(within(frame("Editorial")).queryByText("stale")).not.toBeInTheDocument();
  });

  it("keeps the frame at the device's aspect ratio", async () => {
    await open();
    const box = frame("Diner").querySelector<HTMLElement>(".preview-image");
    expect(box?.style.aspectRatio).toBe("1264 / 1680");
  });

  it("moves the single frame to the look the form writes, which renders", async () => {
    await open();
    await succeed(0);
    expect(renders[0]!.look).toBe("diner");

    fireEvent.click(
      within(document.querySelector<HTMLElement>('[data-key="look"]')!).getByRole("button", { name: "Editorial" }),
    );
    await tick();

    expect(frames()).toHaveLength(1);
    expect(frame("Editorial")).toBeInTheDocument();
    expect(renders).toHaveLength(2);
    expect(renders[1]!.look).toBe("editorial");
    expect(within(frame("Editorial")).getByText("Rendering in the emulator…")).toBeInTheDocument();

    await tick(1_500);
    await succeed(1);
    await tick(10_000);
    expect(renders).toHaveLength(2);
    expect(image("Editorial")).toHaveAttribute("src", "blob:preview-2");
    expect(within(frame("Editorial")).queryByText("stale")).not.toBeInTheDocument();
  });

  it("marks the image stale on a landed write and renders 1.5 s after the last write", async () => {
    await open();
    await succeed(0);

    await write();
    expect(within(frame("Diner")).getByText("stale")).toBeInTheDocument();
    expect(within(frame("Diner")).getByText("Settings changed · re-rendering in 1.5 s")).toBeInTheDocument();
    expect(image("Diner")).toHaveAttribute("src", "blob:preview-1");

    await tick(1_000);
    expect(renders).toHaveLength(1);
    await write();

    await tick(1_499);
    expect(renders).toHaveLength(1);
    await tick(1);
    expect(renders).toHaveLength(2);
    expect(renders[1]!.look).toBe("diner");
    expect(within(frame("Diner")).getByText("Rendering in the emulator…")).toBeInTheDocument();
    expect(within(frame("Diner")).getByText("stale")).toBeInTheDocument();
    expect(image("Diner")).toHaveClass("dimmed");

    await succeed(1);
    await tick(10_000);
    expect(renders).toHaveLength(2);
    expect(within(frame("Diner")).queryByText("stale")).not.toBeInTheDocument();
    expect(image("Diner")).toHaveAttribute("src", "blob:preview-2");
    expect(image("Diner")).not.toHaveClass("dimmed");
    expect(revokeObjectURL).toHaveBeenCalledWith("blob:preview-1");
  });

  it("does nothing for a write that fails", async () => {
    await open();
    await succeed(0);
    putStatus = 409;

    await write();
    await tick(10_000);

    expect(renders).toHaveLength(1);
    expect(within(frame("Diner")).queryByText("stale")).not.toBeInTheDocument();
  });

  it("renders a frame whose render ended within the pause when the pause ends", async () => {
    await open();
    await write();

    await tick(1_000);
    await succeed(0);
    expect(within(frame("Diner")).getByText("stale")).toBeInTheDocument();
    expect(within(frame("Diner")).getByText("Settings changed · re-rendering in 1.5 s")).toBeInTheDocument();

    await tick(499);
    expect(renders).toHaveLength(1);
    await tick(1);
    expect(renders).toHaveLength(2);

    await succeed(1);
    await tick(10_000);
    expect(renders).toHaveLength(2);
  });

  it("renders a frame whose render outlasted the pause again as soon as it ends", async () => {
    await open();
    await write();

    await tick(2_999);
    expect(renders).toHaveLength(1);
    await tick(1);
    await succeed(0);
    expect(renders).toHaveLength(2);
    expect(within(frame("Diner")).getByText("stale")).toBeInTheDocument();

    await succeed(1);
    await tick(10_000);
    expect(renders).toHaveLength(2);
    expect(within(frame("Diner")).queryByText("stale")).not.toBeInTheDocument();
  });

  it("renders a frame again as soon as it ends when the pause ended while it was hidden", async () => {
    await open();
    await write();
    const night = within(pane()).getByRole("checkbox", { name: "Night" });
    fireEvent.click(night);
    await tick();
    await tick(1_500);
    fireEvent.click(night);
    await tick();

    await succeed(0);
    await tick(10_000);
    expect(renders.filter(({ night }) => !night)).toHaveLength(2);
    await succeed(2);
    expect(within(frame("Diner")).queryByText("stale")).not.toBeInTheDocument();
  });

  it("leaves a frame whose render ended while hidden until it is shown", async () => {
    await open();
    await write();
    const night = within(pane()).getByRole("checkbox", { name: "Night" });
    fireEvent.click(night);
    await tick();
    await succeed(1);
    await tick(1_500);

    await succeed(0);
    await tick(10_000);
    expect(renders.map(({ night }) => night)).toEqual([false, true]);

    fireEvent.click(night);
    await tick();
    expect(renders.map(({ night }) => night)).toEqual([false, true, false]);
  });

  it("makes one request after a failed first render until Re-render", async () => {
    await open();
    await fail(0);

    await tick(60_000);
    expect(renders).toHaveLength(1);

    fireEvent.click(rerender());
    await tick();
    expect(renders).toHaveLength(2);
  });

  it("waits for a pause restarted while a render outlasted the one before", async () => {
    await open();
    await write();
    await tick(2_000);
    await write();

    await tick(500);
    await succeed(0);
    expect(renders).toHaveLength(1);
    expect(within(frame("Diner")).getByText("Settings changed · re-rendering in 1.5 s")).toBeInTheDocument();

    await tick(999);
    expect(renders).toHaveLength(1);
    await tick(1);
    expect(renders).toHaveLength(2);
    await succeed(1);
    await tick(10_000);
    expect(renders).toHaveLength(2);
  });

  it("renders a failed imageless frame that ended within the pause when the pause ends", async () => {
    await open();
    await write();

    await tick(1_000);
    await fail(0);
    await tick(499);
    expect(renders).toHaveLength(1);
    await tick(1);
    expect(renders).toHaveLength(2);

    await fail(1);
    await tick(60_000);
    expect(renders).toHaveLength(2);
  });

  it("renders a failed frame again when it is shown again", async () => {
    await open();
    await fail(0);
    const night = within(pane()).getByRole("checkbox", { name: "Night" });

    fireEvent.click(night);
    await tick();
    await succeed(1);
    fireEvent.click(night);
    await tick();

    expect(renders.map(({ night }) => night)).toEqual([false, true, false]);
  });

  it("renders a failed imageless frame again once a write lands", async () => {
    await open();
    await fail(0);

    await write();
    expect(renders).toHaveLength(2);

    await fail(1);
    await tick(60_000);
    expect(renders).toHaveLength(2);
  });

  it("shows both looks side by side, then night, keeping each frame's last good image", async () => {
    await open();
    await succeed(0);

    fireEvent.click(within(pane()).getByRole("checkbox", { name: "Both looks" }));
    await tick();
    expect(captions()).toEqual(["Diner", "Editorial"]);
    expect(renders.map(({ look, night }) => ({ look, night }))).toEqual([
      { look: "diner", night: false },
      { look: "editorial", night: false },
    ]);
    await succeed(1);
    expect(image("Diner")).toHaveAttribute("src", "blob:preview-1");
    expect(image("Editorial")).toHaveAttribute("src", "blob:preview-2");

    fireEvent.click(within(pane()).getByRole("checkbox", { name: "Night" }));
    await tick();
    expect(captions()).toEqual(["Diner · night", "Editorial · night"]);
    expect(renders.slice(2).map(({ look, night }) => ({ look, night }))).toEqual([
      { look: "diner", night: true },
      { look: "editorial", night: true },
    ]);
    await succeed(2);
    await succeed(3);
    expect(image("Diner · night")).toHaveAttribute("src", "blob:preview-3");
    expect(image("Editorial · night")).toHaveAttribute("src", "blob:preview-4");

    fireEvent.click(within(pane()).getByRole("checkbox", { name: "Night" }));
    await tick(10_000);
    expect(renders).toHaveLength(4);
    expect(image("Diner")).toHaveAttribute("src", "blob:preview-1");
    expect(image("Editorial")).toHaveAttribute("src", "blob:preview-2");

    fireEvent.click(within(pane()).getByRole("checkbox", { name: "Night" }));
    await tick(10_000);
    expect(renders).toHaveLength(4);
    expect(image("Diner · night")).toHaveAttribute("src", "blob:preview-3");
    expect(revokeObjectURL).not.toHaveBeenCalled();
  });

  it("renders a hidden frame that went stale when it is shown again", async () => {
    await open();
    await succeed(0);
    const night = within(pane()).getByRole("checkbox", { name: "Night" });
    fireEvent.click(night);
    await tick();
    await succeed(1);
    fireEvent.click(night);
    await tick();

    await write();
    await tick(1_500);
    expect(renders.map(({ night }) => night)).toEqual([false, true, false]);
    await succeed(2);

    fireEvent.click(night);
    await tick();
    expect(renders.map(({ night }) => night)).toEqual([false, true, false, true]);
  });

  it("renders every shown frame on Re-render, disabled until they end", async () => {
    await open();
    await succeed(0);
    fireEvent.click(within(pane()).getByRole("checkbox", { name: "Both looks" }));
    await tick();
    expect(rerender()).toBeDisabled();
    await succeed(1);
    expect(rerender()).toBeEnabled();

    fireEvent.click(rerender());
    await tick();
    expect(renders.slice(2).map(({ look }) => look)).toEqual(["diner", "editorial"]);
    expect(rerender()).toBeDisabled();
    await succeed(2);
    expect(rerender()).toBeDisabled();
    await succeed(3);
    expect(rerender()).toBeEnabled();
  });

  it("keeps the last good image through a failure and shows the error and its log", async () => {
    await open();
    await succeed(0);

    fireEvent.click(rerender());
    await tick();
    await fail(1, 502, "KOReader exited with 1", ["first log line", "last log line"]);

    const failed = frame("Diner");
    expect(image("Diner")).toHaveAttribute("src", "blob:preview-1");
    expect(within(failed).getByText("KOReader exited with 1")).toBeInTheDocument();
    expect(within(failed).getByText("Showing the last good render.")).toBeInTheDocument();
    expect(within(failed).getByText(/first log line\s+last log line/)).toBeInTheDocument();
    expect(within(failed).queryByText("stale")).not.toBeInTheDocument();
    expect(within(failed).queryByText(/^Rendered in/)).not.toBeInTheDocument();
  });

  it("shows the failure under a stale image whose render after the pause failed", async () => {
    await open();
    await succeed(0);
    await write();
    await tick(1_500);
    await fail(1);

    const failed = frame("Diner");
    expect(within(failed).getByText("stale")).toBeInTheDocument();
    expect(within(failed).getByText("The emulator crashed")).toBeInTheDocument();
    expect(within(failed).getByText("Showing the last good render.")).toBeInTheDocument();
    expect(within(failed).queryByText(/^Settings changed/)).not.toBeInTheDocument();
  });

  it("clears the failure once a later render succeeds", async () => {
    await open();
    await fail(0);
    fireEvent.click(rerender());
    await tick();
    await succeed(1);

    const shown = frame("Diner");
    expect(within(shown).getByText(/^Rendered in \d+\.\d s$/)).toBeInTheDocument();
    expect(within(shown).queryByText("The emulator crashed")).not.toBeInTheDocument();
    expect(within(shown).queryByText("No earlier render to show.")).not.toBeInTheDocument();
  });

  it("says there is no earlier render when the first render fails", async () => {
    await open();
    await fail(0, 503, "No emulator at /nowhere", ["usage line"]);

    expect(within(frame("Diner")).getByText("No emulator at /nowhere")).toBeInTheDocument();
    expect(within(frame("Diner")).getByText("No earlier render to show.")).toBeInTheDocument();
    expect(within(frame("Diner")).getByText("usage line")).toBeInTheDocument();
    expect(image("Diner")).toBeNull();
  });

  it("aborts the request in flight and revokes its images when the screen closes", async () => {
    const { unmount } = await open();
    await succeed(0);
    fireEvent.click(rerender());
    await tick();
    expect(renders[1]!.signal.aborted).toBe(false);

    unmount();

    expect(renders[1]!.signal.aborted).toBe(true);
    expect(revokeObjectURL).toHaveBeenCalledWith("blob:preview-1");
  });

  it("starts empty for another profile, aborting the first one's renders", async () => {
    await open();
    await succeed(0);
    fireEvent.click(rerender());
    await tick();

    history.replaceState(null, "", "/#/profiles/paperwhite");
    await act(async () => {
      window.dispatchEvent(new HashChangeEvent("hashchange"));
      await vi.advanceTimersByTimeAsync(0);
    });

    expect(renders[1]!.signal.aborted).toBe(true);
    expect(revokeObjectURL).toHaveBeenCalledWith("blob:preview-1");
    expect(within(pane()).getByText("Kindle Paperwhite · 1236×1648")).toBeInTheDocument();
    expect(image("Diner")).toBeNull();
    expect(renders[2]!.url).toBe("/api/profiles/paperwhite/preview");
    expect(within(frame("Diner")).getByText("Rendering in the emulator…")).toBeInTheDocument();
  });
});
