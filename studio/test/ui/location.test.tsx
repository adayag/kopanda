// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { schema } from "../../src/schema";
import type { Candidate } from "../../src/server/geocoding";
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

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((r) => {
    resolve = r;
  });
  return { promise, resolve };
}

const fetchMock = vi.fn<typeof fetch>();

type Answer = (body: unknown) => Response | Promise<Response>;

/** Answers each request by "<METHOD> <url>" from `routes`; an unrouted request fails the test. */
function route(routes: Record<string, Answer>): void {
  fetchMock.mockImplementation(async (input, init) => {
    const name = `${init?.method ?? "GET"} ${String(input)}`;
    const answer = routes[name];
    if (!answer) throw new Error(`unexpected fetch ${name}`);
    return answer(typeof init?.body === "string" ? JSON.parse(init.body) : undefined);
  });
}

function puts(): [string, unknown][] {
  return fetchMock.mock.calls
    .filter(([, init]) => init?.method === "PUT")
    .map(([input, init]) => [String(input), JSON.parse(String(init?.body))]);
}

function searches(): string[] {
  return fetchMock.mock.calls.map(([input]) => String(input)).filter((url) => url.startsWith("/api/geocode"));
}

const PUT_LOCATION = "PUT /api/profiles/colorsoft/settings/weather.location";

const chicago: Candidate = {
  name: "Chicago, Illinois",
  latitude: 41.85003,
  longitude: -87.65005,
  shown: "Chicago, Illinois, United States",
};
const jalisco: Candidate = {
  name: "Chicago, Jalisco",
  latitude: 22.33944,
  longitude: -104.15972,
  shown: "Chicago, Jalisco, Mexico",
};
const tokyo: Candidate = { name: "Tokyo, Japan", latitude: 35.6895, longitude: 139.69171, shown: "Tokyo, Japan" };

async function open(answer: Settings, routes: Record<string, Answer> = {}) {
  history.replaceState(null, "", "/#/profiles/colorsoft");
  route({
    "GET /api/profiles/colorsoft": () => json(colorsoft),
    "GET /api/profiles/colorsoft/settings": () => json(answer),
    ...routes,
  });
  render(<App />);
  await screen.findByRole("heading", { name: "Colorsoft" });
}

function place() {
  const found = document.querySelector<HTMLElement>('[data-key="weather.location"]');
  if (!found) throw new Error("no control for weather.location");
  return within(found);
}

function search(query: string) {
  const field = place().getByPlaceholderText("City or ZIP code");
  fireEvent.change(field, { target: { value: query } });
  fireEvent.click(place().getByRole("button", { name: "Search" }));
}

beforeEach(() => {
  history.replaceState(null, "", "/");
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("the place search", () => {
  it("shows Searching… for the trimmed query, then Choose a place with each candidate's shown text", async () => {
    const answer = deferred<Response>();
    await open(settings(), { "GET /api/geocode?q=Chicago": () => answer.promise });

    search("  Chicago ");

    expect(await place().findByText("Searching…")).toBeInTheDocument();
    answer.resolve(json({ candidates: [chicago, jalisco] }));
    expect(await place().findByText("Choose a place")).toBeInTheDocument();
    expect(place().queryByText("Searching…")).not.toBeInTheDocument();
    expect(place().getByRole("button", { name: chicago.shown })).toBeInTheDocument();
    expect(place().getByRole("button", { name: jalisco.shown })).toBeInTheDocument();
    expect(searches()).toEqual(["/api/geocode?q=Chicago"]);
  });

  it("searches on Enter too, sending the query encoded", async () => {
    await open(settings(), { "GET /api/geocode?q=S%C3%A3o%20Paulo%20%26%20co": () => json({ candidates: [tokyo] }) });
    const field = place().getByPlaceholderText("City or ZIP code");

    fireEvent.change(field, { target: { value: "São Paulo & co" } });
    fireEvent.submit(field);

    expect(await place().findByRole("button", { name: tokyo.shown })).toBeInTheDocument();
  });

  it("does nothing for an empty query", async () => {
    await open(settings());

    search(" \t ");

    expect(place().queryByText("Searching…")).not.toBeInTheDocument();
    expect(searches()).toEqual([]);
  });

  it("writes exactly the picked place's name, latitude and longitude in one PUT", async () => {
    let answer = settings();
    await open(answer, {
      "GET /api/geocode?q=Chicago": () => json({ candidates: [chicago, jalisco] }),
      [PUT_LOCATION]: (body) => {
        answer = settings({ "weather.location": (body as { value: unknown }).value });
        return json(answer);
      },
    });
    search("Chicago");

    fireEvent.click(await place().findByRole("button", { name: jalisco.shown }));

    await waitFor(() => expect(place().getByText("Chicago, Jalisco")).toBeInTheDocument());
    expect(puts()).toEqual([
      [
        "/api/profiles/colorsoft/settings/weather.location",
        { value: { name: "Chicago, Jalisco", latitude: 22.33944, longitude: -104.15972 } },
      ],
    ]);
    expect(place().getByText("22.33944, -104.15972")).toBeInTheDocument();
    expect(place().queryByText("Choose a place")).not.toBeInTheDocument();
  });

  it("sends nothing when the place picked is the one stored", async () => {
    const stored = { name: chicago.name, latitude: chicago.latitude, longitude: chicago.longitude };
    await open(settings({ "weather.location": stored }), {
      "GET /api/geocode?q=Chicago": () => json({ candidates: [chicago] }),
    });
    search("Chicago");

    fireEvent.click(await place().findByRole("button", { name: chicago.shown }));

    await waitFor(() => expect(place().queryByText("Choose a place")).not.toBeInTheDocument());
    expect(puts()).toEqual([]);
  });

  it("names the query in a note when no place is found, writing nothing", async () => {
    await open(settings(), { "GET /api/geocode?q=Nowhereville": () => json({ candidates: [] }) });

    search(" Nowhereville ");

    expect(await place().findByText("No place found for “Nowhereville”.")).toBeInTheDocument();
    expect(place().queryByText("Choose a place")).not.toBeInTheDocument();
    expect(puts()).toEqual([]);
  });

  it("says it couldn't search when the server answers 502, writing nothing", async () => {
    await open(settings(), {
      "GET /api/geocode?q=Chicago": () => json({ error: "couldn't reach Open-Meteo: fetch failed" }, 502),
    });

    search("Chicago");

    expect(await place().findByText("Couldn't search for places.")).toBeInTheDocument();
    expect(place().queryByText("Searching…")).not.toBeInTheDocument();
    expect(puts()).toEqual([]);
  });

  it("says it couldn't search when the server can't be reached", async () => {
    await open(settings(), {
      "GET /api/geocode?q=Chicago": () => Promise.reject(new TypeError("Failed to fetch")),
    });

    search("Chicago");

    expect(await place().findByText("Couldn't search for places.")).toBeInTheDocument();
  });

  it("replaces the list with a new search's", async () => {
    const second = deferred<Response>();
    await open(settings(), {
      "GET /api/geocode?q=Chicago": () => json({ candidates: [chicago, jalisco] }),
      "GET /api/geocode?q=Tokyo": () => second.promise,
    });
    search("Chicago");
    await place().findByRole("button", { name: chicago.shown });

    search("Tokyo");

    expect(await place().findByText("Searching…")).toBeInTheDocument();
    expect(place().queryByRole("button", { name: chicago.shown })).not.toBeInTheDocument();
    second.resolve(json({ candidates: [tokyo] }));
    expect(await place().findByRole("button", { name: tokyo.shown })).toBeInTheDocument();
    expect(place().queryByRole("button", { name: jalisco.shown })).not.toBeInTheDocument();
  });

  it("replaces a note with the next search's list", async () => {
    await open(settings(), {
      "GET /api/geocode?q=Nowhereville": () => json({ candidates: [] }),
      "GET /api/geocode?q=Tokyo": () => json({ candidates: [tokyo] }),
    });
    search("Nowhereville");
    await place().findByText("No place found for “Nowhereville”.");

    search("Tokyo");

    expect(await place().findByRole("button", { name: tokyo.shown })).toBeInTheDocument();
    expect(place().queryByText("No place found for “Nowhereville”.")).not.toBeInTheDocument();
  });
});
