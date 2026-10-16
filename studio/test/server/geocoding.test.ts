import { describe, expect, it, vi } from "vitest";
import fs from "node:fs";
import request from "supertest";
import { createApp } from "../../src/server/app.js";
import { loadConfig } from "../../src/server/config.js";
import { geocodeUrl, parseGeocoding, trim, urlEncode } from "../../src/server/geocoding.js";
import { get, LuaTable, parse, toJson } from "../../src/core/lua.js";

// The corpus spec/unit/studio_geocoding_spec.lua holds the plugin's LocationSearch to, read with the
// studio's own reader, and the recorded Open-Meteo responses it names.
const corpusUrl = new URL("../../../spec/fixtures/studio/geocoding_cases.lua", import.meta.url);
const geocodingDir = new URL("../../../spec/fixtures/geocoding/", import.meta.url);

function fixture(name: string): string {
  return fs.readFileSync(new URL(name, geocodingDir), "utf8");
}

function readCorpus() {
  const result = parse(fs.readFileSync(corpusUrl));
  if (!result.ok) throw new Error(`geocoding_cases.lua is unreadable: ${result.error}`);
  if (!(result.value instanceof LuaTable)) throw new Error("geocoding_cases.lua returns no table");
  const list = (key: string) => {
    const t = get(result.value as LuaTable, key);
    if (!(t instanceof LuaTable)) throw new Error(`geocoding_cases.lua has no ${key}`);
    return [...t.fields.values()].map((item) => {
      if (!(item instanceof LuaTable)) throw new Error(`a case in ${key} is not a table`);
      return item;
    });
  };
  return {
    urls: list("urls").map((c) => ({ query: String(get(c, "query")), url: String(get(c, "url")) })),
    parses: list("parses").map((c) => {
      const candidates = get(c, "candidates");
      if (!(candidates instanceof LuaTable)) throw new Error("a parse case has no candidates");
      return { fixture: String(get(c, "fixture")), candidates: toJson(candidates) };
    }),
  };
}

const cases = readCorpus();

describe("geocodeUrl on the shared corpus", () => {
  it("has the plan's queries", () => {
    expect(cases.urls.map((c) => c.query)).toEqual(
      expect.arrayContaining(["  Chicago ", "New York", "60614", "606140", "6061A", "São Paulo", "a&b=c", "St. John's (NL)!"]),
    );
  });

  cases.urls.forEach((c, i) => {
    it(`url case ${i + 1}: ${JSON.stringify(c.query)}`, () => {
      expect(geocodeUrl(c.query)).toBe(c.url);
    });
  });
});

describe("parseGeocoding on the shared corpus", () => {
  it("covers every recorded response", () => {
    const recorded = fs.readdirSync(geocodingDir).filter((name) => name.endsWith(".json"));

    expect(cases.parses.map((c) => c.fixture).sort()).toEqual(recorded.sort());
  });

  cases.parses.forEach((c) => {
    it(`parse case: ${c.fixture}`, () => {
      expect(parseGeocoding(fixture(c.fixture))).toEqual(c.candidates);
    });
  });
});

describe("trim and urlEncode, as KOReader's util", () => {
  it("trims Lua's %s set only: ASCII whitespace, not a no-break or ideographic space", () => {
    expect(trim(" \t\n\v\f\rParis \t\n\v\f\r")).toBe("Paris");
    expect(trim(" Paris　")).toBe(" Paris　");
    expect(trim(" \t ")).toBe("");
  });

  it("encodes every byte outside A-Z a-z 0-9 - . _ ~, upper case", () => {
    expect(urlEncode("Az09-._~ !'()*/é")).toBe("Az09-._~%20%21%27%28%29%2A%2F%C3%A9");
  });
});

describe("parseGeocoding", () => {
  it("reads text that is not JSON, or JSON that is not a table, as unreadable", () => {
    expect(parseGeocoding("<html>")).toBeNull();
    expect(parseGeocoding("42")).toBeNull();
    expect(parseGeocoding('"results"')).toBeNull();
    expect(parseGeocoding("null")).toBeNull();
  });

  it("reads JSON with no list of results as none", () => {
    expect(parseGeocoding("{}")).toEqual([]);
    expect(parseGeocoding('{"results":{"name":"Paris"}}')).toEqual([]);
    expect(parseGeocoding("[]")).toEqual([]);
  });

  // The device's parse raises indexing a number, a boolean or null (rapidjson's userdata), so its
  // search ends without a chooser; a string or a list it indexes to nil, so skips.
  it("reads a result that is a number, a boolean or null as unreadable, and skips a string or a list", () => {
    expect(parseGeocoding('{"results":[{"name":"Kept","latitude":1,"longitude":2},3]}')).toBeNull();
    expect(parseGeocoding('{"results":[true]}')).toBeNull();
    expect(parseGeocoding('{"results":[null]}')).toBeNull();
    expect(parseGeocoding('{"results":["x",[1],{"name":"Kept","latitude":1,"longitude":2}]}')).toEqual([
      { name: "Kept", latitude: 1, longitude: 2, shown: "Kept" },
    ]);
  });

  it("skips an empty name and a missing coordinate", () => {
    const body = JSON.stringify({
      results: [
        { name: "", latitude: 1.5, longitude: 1.5 },
        { name: "Nolon", latitude: 1.5 },
        { name: "Kept", latitude: 1.5, longitude: 2.5, admin1: "", country: "" },
      ],
    });

    expect(parseGeocoding(body)).toEqual([{ name: "Kept", latitude: 1.5, longitude: 2.5, shown: "Kept" }]);
  });
});

const CHICAGO_URL = "https://geocoding-api.open-meteo.com/v1/search?name=Chicago&count=10&language=en&format=json";

/** The app with fetch answered by `answer`, and the stub to read its calls from. */
function appWith(answer: (url: string, init?: RequestInit) => Promise<Response>, timeoutMs?: number) {
  const stub = vi.fn((input: string | URL | Request, init?: RequestInit) => answer(String(input), init));
  const app = createApp(loadConfig({}), { geocode: { fetch: stub as typeof fetch, timeoutMs } });
  return { app, stub };
}

describe("GET /api/geocode", () => {
  it("answers the candidates of a 200, having asked Open-Meteo for the trimmed query's URL", async () => {
    const { app, stub } = appWith(async () => new Response(fixture("chicago.json"), { status: 200 }));

    const res = await request(app).get("/api/geocode").query({ q: "  Chicago " });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ candidates: cases.parses.find((c) => c.fixture === "chicago.json")!.candidates });
    expect(stub).toHaveBeenCalledTimes(1);
    expect(stub.mock.calls[0]![0]).toBe(CHICAGO_URL);
  });

  it("asks for each corpus query's exact URL", async () => {
    for (const c of cases.urls) {
      const { app, stub } = appWith(async () => new Response(fixture("none.json"), { status: 200 }));

      await request(app).get("/api/geocode").query({ q: c.query });

      expect(stub.mock.calls.map((call) => call[0]), JSON.stringify(c.query)).toEqual([c.url]);
    }
  });

  it("answers an empty list for a response with no results", async () => {
    const { app } = appWith(async () => new Response(fixture("none.json"), { status: 200 }));

    const res = await request(app).get("/api/geocode?q=nowhere");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ candidates: [] });
  });

  it("answers 400 for an empty query, asking nothing", async () => {
    const { app, stub } = appWith(async () => new Response(fixture("chicago.json")));

    for (const path of ["/api/geocode?q=%20", "/api/geocode?q=", "/api/geocode", "/api/geocode?q=%09%0A"]) {
      const res = await request(app).get(path);

      expect(res.status, path).toBe(400);
      expect(res.body.error, path).toEqual(expect.any(String));
    }
    expect(stub).not.toHaveBeenCalled();
  });

  const failures: [string, (url: string, init?: RequestInit) => Promise<Response>][] = [
    ["a status other than 200", async () => new Response(fixture("chicago.json"), { status: 500 })],
    ["a 2xx other than 200", async () => new Response(fixture("chicago.json"), { status: 203 })],
    ["an unreadable body", async () => new Response("<html>", { status: 200 })],
    ["a failed request", () => Promise.reject(new TypeError("fetch failed"))],
  ];

  for (const [why, answer] of failures) {
    it(`answers 502 for ${why}`, async () => {
      const { app } = appWith(answer);

      const res = await request(app).get("/api/geocode?q=Chicago");

      expect(res.status).toBe(502);
      expect(res.body.error).toEqual(expect.any(String));
    });
  }

  it("answers 502 when Open-Meteo doesn't answer in time", async () => {
    const { app } = appWith(() => new Promise<Response>(() => {}), 50);

    const res = await request(app).get("/api/geocode?q=Chicago");

    expect(res.status).toBe(502);
    expect(res.body.error).toEqual(expect.any(String));
  });

  it("answers 502 when the body doesn't arrive in time", async () => {
    const { app } = appWith(
      async () => new Response(new ReadableStream({ start() {} }), { status: 200 }),
      50,
    );

    const res = await request(app).get("/api/geocode?q=Chicago");

    expect(res.status).toBe(502);
  });
});
