// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { StrictMode } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { App } from "../../src/ui/App";

const DIR = "/home/owner/kopanda-profiles";

const colorsoft = {
  id: "colorsoft",
  name: "Colorsoft",
  device: "Kindle Colorsoft SE",
  width: 1264,
  height: 1680,
  dpi: 300,
  color: true,
  has_settings: false,
};

const paperwhite = {
  id: "paperwhite",
  name: "Paperwhite",
  device: "Kindle Paperwhite",
  width: 1236,
  height: 1648,
  dpi: 300,
  color: false,
  has_settings: true,
};

const broken = { id: "broken", error: "profile.json is not valid JSON: Unexpected token" };

function settingsPath(id: string): string {
  return `${DIR}/${id}/settings/kopanda/settings.lua`;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

const fetchMock = vi.fn<typeof fetch>();

/** Answers each request by its URL from `routes`; an unrouted URL fails the test. */
function route(routes: Record<string, () => Response | Promise<Response>>): void {
  fetchMock.mockImplementation(async (input) => {
    const answer = routes[String(input)];
    if (!answer) throw new Error(`unexpected fetch ${String(input)}`);
    return answer();
  });
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((r) => {
    resolve = r;
  });
  return { promise, resolve };
}

function requestedUrls(): string[] {
  return fetchMock.mock.calls.map(([input]) => String(input));
}

beforeEach(() => {
  history.replaceState(null, "", "/");
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("the profile list", () => {
  it("shows the loading line before the answer arrives", async () => {
    const answer = deferred<Response>();
    route({ "/api/profiles": () => answer.promise });

    render(<App />);

    expect(screen.getByText("Loading profiles")).toBeInTheDocument();
    answer.resolve(json({ dir: DIR, profiles: [colorsoft] }));
    expect(await screen.findByRole("button", { name: /Colorsoft/ })).toBeInTheDocument();
    expect(screen.queryByText("Loading profiles")).not.toBeInTheDocument();
  });

  it("shows valid profiles as openable rows and an invalid one as its id and reason", async () => {
    route({ "/api/profiles": () => json({ dir: DIR, profiles: [broken, colorsoft, paperwhite] }) });

    render(<App />);

    const rows = await screen.findAllByRole("button");
    expect(rows).toHaveLength(2);
    const [first, second] = rows;
    expect(first).toHaveTextContent("Colorsoft");
    expect(first).toHaveTextContent("Kindle Colorsoft SE");
    expect(first).toHaveTextContent("1264×1680 · 300 dpi · colour");
    expect(first).toHaveTextContent("defaults");
    expect(first).not.toHaveTextContent("settings file");
    expect(second).toHaveTextContent("Paperwhite");
    expect(second).toHaveTextContent("Kindle Paperwhite");
    expect(second).toHaveTextContent("1236×1648 · 300 dpi · greyscale");
    expect(second).toHaveTextContent("settings file");

    const invalid = screen.getByText("broken");
    expect(invalid.closest("button")).toBeNull();
    expect(invalid.closest("a")).toBeNull();
    expect(screen.getByText(broken.error)).toBeInTheDocument();
  });

  it("shows a failed request's error text in place of the list", async () => {
    route({ "/api/profiles": () => json({ error: "EACCES: permission denied, scandir" }, 500) });

    render(<App />);

    expect(await screen.findByText("EACCES: permission denied, scandir")).toBeInTheDocument();
    expect(screen.queryByText("Loading profiles")).not.toBeInTheDocument();
    expect(screen.queryAllByRole("button")).toHaveLength(0);
  });

  it("shows an empty directory as No profiles in its dir", async () => {
    route({ "/api/profiles": () => json({ dir: DIR, profiles: [] }) });

    render(<App />);

    expect(await screen.findByText(`No profiles in ${DIR}`)).toBeInTheDocument();
  });
});

describe("opening a profile", () => {
  it("sets the hash and shows the profile's name, device facts, settings path and the defaults line", async () => {
    route({
      "/api/profiles": () => json({ dir: DIR, profiles: [colorsoft, paperwhite] }),
      "/api/profiles/colorsoft": () =>
        json({ ...colorsoft, settings_path: settingsPath("colorsoft") }),
    });
    render(<App />);

    fireEvent.click(await screen.findByRole("button", { name: /Colorsoft/ }));

    expect(location.hash).toBe("#/profiles/colorsoft");
    expect(await screen.findByRole("heading", { name: "Colorsoft" })).toBeInTheDocument();
    expect(screen.getByText("Kindle Colorsoft SE")).toBeInTheDocument();
    expect(screen.getByText("1264×1680 · 300 dpi · colour")).toBeInTheDocument();
    expect(screen.getByText(settingsPath("colorsoft"))).toBeInTheDocument();
    expect(screen.getByText("All settings at their defaults")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Paperwhite/ })).not.toBeInTheDocument();
  });

  it("leaves out the defaults line when the profile has a settings file", async () => {
    history.replaceState(null, "", "/#/profiles/paperwhite");
    route({
      "/api/profiles/paperwhite": () =>
        json({ ...paperwhite, settings_path: settingsPath("paperwhite") }),
    });

    render(<App />);

    expect(await screen.findByRole("heading", { name: "Paperwhite" })).toBeInTheDocument();
    expect(screen.getByText("1236×1648 · 300 dpi · greyscale")).toBeInTheDocument();
    expect(screen.getByText(settingsPath("paperwhite"))).toBeInTheDocument();
    expect(screen.queryByText("All settings at their defaults")).not.toBeInTheDocument();
  });

  it("opens the profile in the hash directly, without the list first", async () => {
    history.replaceState(null, "", "/#/profiles/paperwhite");
    route({
      "/api/profiles/paperwhite": () =>
        json({ ...paperwhite, settings_path: settingsPath("paperwhite") }),
    });

    render(<App />);

    expect(screen.queryByText("Loading profiles")).not.toBeInTheDocument();
    expect(await screen.findByRole("heading", { name: "Paperwhite" })).toBeInTheDocument();
    expect(requestedUrls()).toEqual(["/api/profiles/paperwhite"]);
  });

  it("shows No profile <id> for a 404, with a way back to the list", async () => {
    history.replaceState(null, "", "/#/profiles/nope");
    route({
      "/api/profiles/nope": () => json({ error: 'no profile "nope"' }, 404),
      "/api/profiles": () => json({ dir: DIR, profiles: [colorsoft] }),
    });
    render(<App />);

    expect(await screen.findByText("No profile nope")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("link", { name: "Profiles" }));

    expect(await screen.findByRole("button", { name: /Colorsoft/ })).toBeInTheDocument();
    expect(location.hash).toBe("#/");
  });

  it("shows a failed profile request's error text, with a way back to the list", async () => {
    history.replaceState(null, "", "/#/profiles/colorsoft");
    route({
      "/api/profiles/colorsoft": () => json({ error: "EIO: i/o error, read" }, 500),
      "/api/profiles": () => json({ dir: DIR, profiles: [colorsoft] }),
    });
    render(<App />);

    expect(await screen.findByText("EIO: i/o error, read")).toBeInTheDocument();
    expect(screen.queryByText(/No profile/)).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("link", { name: "Profiles" }));

    expect(await screen.findByRole("button", { name: /Colorsoft/ })).toBeInTheDocument();
  });

  it("goes back from an opened profile to the list, which it reads again", async () => {
    let listing = { dir: DIR, profiles: [colorsoft] as object[] };
    route({
      "/api/profiles": () => json(listing),
      "/api/profiles/colorsoft": () =>
        json({ ...colorsoft, settings_path: settingsPath("colorsoft") }),
    });
    render(<App />);
    fireEvent.click(await screen.findByRole("button", { name: /Colorsoft/ }));
    await screen.findByRole("heading", { name: "Colorsoft" });

    listing = { dir: DIR, profiles: [colorsoft, paperwhite] };
    fireEvent.click(screen.getByRole("link", { name: "Profiles" }));

    expect(await screen.findByRole("button", { name: /Paperwhite/ })).toBeInTheDocument();
    expect(requestedUrls()).toEqual([
      "/api/profiles",
      "/api/profiles/colorsoft",
      "/api/profiles",
    ]);
  });

  it("asks for an id from the hash as one encoded path segment", async () => {
    history.replaceState(null, "", "/#/profiles/a%2Fb%3F");
    route({ "/api/profiles/a%2Fb%3F": () => json({ error: 'no profile "a/b?"' }, 404) });

    render(<App />);

    expect(await screen.findByText("No profile a/b?")).toBeInTheDocument();
    expect(requestedUrls()).toEqual(["/api/profiles/a%2Fb%3F"]);
  });

  it.each(["%2e%2e", "..", "%2E", "."])(
    "shows No profile for the dot segment %s without asking for another API path",
    async (segment) => {
      history.replaceState(null, "", `/#/profiles/${segment}`);
      route({});

      render(<App />);

      expect(await screen.findByText(`No profile ${decodeURIComponent(segment)}`)).toBeInTheDocument();
      expect(fetchMock).not.toHaveBeenCalled();
    },
  );

  it("shows the profile the hash names now when an earlier answer arrives late", async () => {
    history.replaceState(null, "", "/#/profiles/colorsoft");
    const late = deferred<Response>();
    route({
      "/api/profiles/colorsoft": () => late.promise,
      "/api/profiles/paperwhite": () =>
        json({ ...paperwhite, settings_path: settingsPath("paperwhite") }),
    });
    render(<App />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1));

    location.hash = "#/profiles/paperwhite";
    expect(await screen.findByRole("heading", { name: "Paperwhite" })).toBeInTheDocument();
    late.resolve(json({ ...colorsoft, settings_path: settingsPath("colorsoft") }));
    await late.promise;
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(screen.getByRole("heading", { name: "Paperwhite" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Colorsoft" })).not.toBeInTheDocument();
    const firstSignal = fetchMock.mock.calls[0]?.[1]?.signal;
    expect(firstSignal?.aborted).toBe(true);
  });

  it("does not show the previous profile while the next one loads", async () => {
    history.replaceState(null, "", "/#/profiles/colorsoft");
    const next = deferred<Response>();
    route({
      "/api/profiles/colorsoft": () =>
        json({ ...colorsoft, settings_path: settingsPath("colorsoft") }),
      "/api/profiles/paperwhite": () => next.promise,
    });
    render(<App />);
    await screen.findByRole("heading", { name: "Colorsoft" });

    location.hash = "#/profiles/paperwhite";

    expect(await screen.findByText("Loading profile")).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Colorsoft" })).not.toBeInTheDocument();
    next.resolve(json({ ...paperwhite, settings_path: settingsPath("paperwhite") }));
    expect(await screen.findByRole("heading", { name: "Paperwhite" })).toBeInTheDocument();
  });

  it.each([
    ["the list", "/", "/api/profiles", "Loading profiles"],
    ["a profile", "/#/profiles/colorsoft", "/api/profiles/colorsoft", "Loading profile"],
  ])(
    "keeps loading %s, not showing an abort, when StrictMode cancels its first request",
    async (_screen, start, url, loading) => {
      history.replaceState(null, "", start);
      fetchMock.mockImplementation((input, init) => {
        expect(String(input)).toBe(url);
        return new Promise((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("The operation was aborted.", "AbortError")),
          );
        });
      });

      render(
        <StrictMode>
          <App />
        </StrictMode>,
      );
      await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2));
      await new Promise((resolve) => setTimeout(resolve, 0));

      expect(screen.getByText(loading)).toBeInTheDocument();
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    },
  );
});
