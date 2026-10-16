// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { schema, type Key, type Schema } from "../../src/schema";
import { App } from "../../src/ui/App";
import type { Settings } from "../../src/ui/api";
import { SettingsForm } from "../../src/ui/settings/SettingsForm";

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

/** A settings answer: every key at its default unless changed. */
function settings(changes: Partial<Settings> = {}, values: Record<string, unknown> = {}): Settings {
  return {
    path: colorsoft.settings_path,
    exists: true,
    state: "writable",
    schema_version: 1,
    values: { ...defaults, ...values },
    invalid: [],
    unknown: [],
    ...changes,
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
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

/** The PUTs sent, as [url, body]. */
function puts(): [string, unknown][] {
  return fetchMock.mock.calls
    .filter(([, init]) => init?.method === "PUT")
    .map(([input, init]) => [String(input), JSON.parse(String(init?.body))]);
}

function gets(url: string): number {
  return fetchMock.mock.calls.filter(([input, init]) => String(input) === url && (init?.method ?? "GET") === "GET").length;
}

const PROFILE = "GET /api/profiles/colorsoft";
const SETTINGS = "GET /api/profiles/colorsoft/settings";
const SETTINGS_URL = "/api/profiles/colorsoft/settings";

/** Opens the colorsoft profile at hash with the settings answer, plus any other routes. */
async function open(answer: Settings, routes: Record<string, Answer> = {}, hash = "#/profiles/colorsoft") {
  history.replaceState(null, "", `/${hash}`);
  route({ [PROFILE]: () => json(colorsoft), [SETTINGS]: () => json(answer), ...routes });
  render(<App />);
  await screen.findByRole("heading", { name: "Colorsoft" });
}

/** The control of the key with this id. */
function control(id: string): HTMLElement {
  const found = document.querySelector<HTMLElement>(`[data-key="${id}"]`);
  if (!found) throw new Error(`no control for ${id}`);
  return found;
}

function keyIds(): string[] {
  return [...document.querySelectorAll<HTMLElement>("[data-key]")].map((el) => el.dataset.key!);
}

/** Whether nothing in el can be operated: every button and field disabled, no link that goes anywhere. */
function inert(el: HTMLElement): boolean {
  const fields = [...el.querySelectorAll<HTMLButtonElement | HTMLInputElement>("button, input")];
  return fields.every((field) => field.disabled) && el.querySelector("a[href]") === null;
}

beforeEach(() => {
  history.replaceState(null, "", "/");
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

/** The form's props beside its settings when nothing is being written. */
const idle = { pending: new Set<string>(), errors: {}, onWrite: () => Promise.resolve(true) };

describe("the form's controls", () => {
  it("has exactly one control per schema key, in schema order, under the groups' headings", () => {
    render(<SettingsForm profileId="colorsoft" settings={settings()} {...idle} />);

    expect(keyIds()).toEqual(schema.keys.map((key) => key.id));
    expect(keyIds()[0]).toBe("look");
    expect(screen.getAllByRole("heading", { level: 2 }).map((h) => h.textContent)).toEqual([
      "Appearance",
      "Home",
      "Weather",
      "Quote",
      "Stats",
      "Featured",
      "Launcher",
    ]);
    for (const key of schema.keys) {
      expect(within(control(key.id)).getAllByText(key.label, { exact: false }).length).toBeGreaterThan(0);
    }
  });

  it("reports a key of a type with no control and renders every other", () => {
    const odd = { id: "x", label: "X", group: "appearance", type: "widgetty", default: 1 } as unknown as Key;
    const withOdd: Schema = { ...schema, keys: [schema.keys[0]!, odd, ...schema.keys.slice(1)] };

    render(<SettingsForm schema={withOdd} profileId="colorsoft" settings={settings()} {...idle} />);

    expect(screen.getByText("No control for widgetty (x).")).toBeInTheDocument();
    expect(keyIds()).toEqual(schema.keys.map((key) => key.id));
  });

  it("shows a choice per button, the current one pressed", () => {
    render(
      <SettingsForm
        profileId="colorsoft"
        settings={settings({}, { text_size: "large" })}
        {...idle}
      />,
    );

    const size = within(control("text_size"));
    expect(size.getAllByRole("button").map((b) => b.textContent)).toEqual(["Small", "Medium", "Large"]);
    expect(size.getByRole("button", { name: "Large" })).toHaveAttribute("aria-pressed", "true");
    expect(size.getByRole("button", { name: "Medium" })).toHaveAttribute("aria-pressed", "false");
  });

  it("shows quote.source's one choice as one button, already selected", () => {
    render(<SettingsForm profileId="colorsoft" settings={settings()} {...idle} />);

    const buttons = within(control("quote.source")).getAllByRole("button");
    expect(buttons).toHaveLength(1);
    expect(buttons[0]).toHaveTextContent("Built-in");
    expect(buttons[0]).toHaveAttribute("aria-pressed", "true");
  });

  it("shows a key the settings answer lacks at its schema default", () => {
    const answer = settings();
    delete answer.values.look;
    delete answer.values["featured.pinned"];

    render(<SettingsForm profileId="colorsoft" settings={answer} {...idle} />);

    expect(within(control("look")).getByRole("button", { name: "Diner" })).toHaveAttribute("aria-pressed", "true");
    expect(within(control("featured.pinned")).getByRole("button", { name: "Most recent book" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
  });

  it("shows the stored place's name and coordinates", () => {
    const seattle = { name: "Seattle, Washington", latitude: 47.60621, longitude: -122.33207 };
    render(
      <SettingsForm
        profileId="colorsoft"
        settings={settings({}, { "weather.location": seattle })}
        {...idle}
      />,
    );

    const place = within(control("weather.location"));
    expect(place.getByText("Seattle, Washington")).toBeInTheDocument();
    expect(place.getByText("47.60621, -122.33207")).toBeInTheDocument();
  });

  it("counts the layout's rows and the launcher's entries", () => {
    const rows = [[{ widget: "clock", share: 1 }], [{ widget: "quote", share: 2 }]];
    const entries = [{ kind: "kopanda", target: "library" }];
    render(
      <SettingsForm
        profileId="colorsoft"
        settings={settings({}, { "layout.rows": rows, "launcher.entries": entries })}
        {...idle}
      />,
    );

    expect(within(control("layout.rows")).getByRole("link")).toHaveTextContent("Layout · 2 rows");
    expect(within(control("launcher.entries")).getByRole("link")).toHaveTextContent("Launcher · 1 entry");
  });
});

describe("writing a key", () => {
  it("sends one PUT for a choice picked and shows the answer; the choice shown sends none", async () => {
    await open(settings(), {
      "PUT /api/profiles/colorsoft/settings/look": () => json(settings({}, { look: "editorial" })),
    });
    const look = within(control("look"));

    fireEvent.click(look.getByRole("button", { name: "Diner" }));
    expect(puts()).toEqual([]);

    fireEvent.click(look.getByRole("button", { name: "Editorial" }));

    await waitFor(() => expect(look.getByRole("button", { name: "Editorial" })).toHaveAttribute("aria-pressed", "true"));
    expect(puts()).toEqual([["/api/profiles/colorsoft/settings/look", { value: "editorial" }]]);
    expect(fetchMock.mock.calls.find(([, init]) => init?.method === "PUT")?.[1]?.headers).toEqual({
      "content-type": "application/json",
    });
  });

  it("drops the defaults line once the first write creates the file", async () => {
    await open(settings({ exists: false }), {
      "PUT /api/profiles/colorsoft/settings/look": () => json(settings({}, { look: "editorial" })),
    });
    expect(screen.getByText("All settings at their defaults")).toBeInTheDocument();

    fireEvent.click(within(control("look")).getByRole("button", { name: "Editorial" }));

    await waitFor(() => expect(screen.queryByText("All settings at their defaults")).not.toBeInTheDocument());
  });

  it("sends one PUT for the toggle", async () => {
    await open(settings(), {
      "PUT /api/profiles/colorsoft/settings/stats.show": () => json(settings({}, { "stats.show": false })),
    });
    const toggle = within(control("stats.show")).getByRole("checkbox", { name: "Show reading stats" });
    expect(toggle).toBeChecked();

    fireEvent.click(toggle);

    await waitFor(() => expect(toggle).not.toBeChecked());
    expect(puts()).toEqual([["/api/profiles/colorsoft/settings/stats.show", { value: false }]]);
  });

  it.each(["books/a.epub", "/"])("refuses the pin %s with the note and sends nothing", async (typed) => {
    await open(settings());
    const pin = within(control("featured.pinned"));

    fireEvent.change(pin.getByRole("textbox"), { target: { value: typed } });
    fireEvent.click(pin.getByRole("button", { name: "Pin" }));

    expect(await pin.findByText("A pin is a path on the device, starting with /.")).toBeInTheDocument();
    expect(puts()).toEqual([]);
  });

  it("pins a device path with one PUT and shows it", async () => {
    const book = "/mnt/us/books/a.epub";
    await open(settings(), {
      "PUT /api/profiles/colorsoft/settings/featured.pinned": () =>
        json(settings({}, { "featured.pinned": book })),
    });
    const pin = within(control("featured.pinned"));

    fireEvent.change(pin.getByRole("textbox"), { target: { value: book } });
    fireEvent.click(pin.getByRole("button", { name: "Pin" }));

    expect(await pin.findByText(book)).toBeInTheDocument();
    expect(puts()).toEqual([["/api/profiles/colorsoft/settings/featured.pinned", { value: book }]]);
    expect(pin.getByRole("button", { name: "Most recent book" })).toHaveAttribute("aria-pressed", "false");
    expect(pin.queryByText("A pin is a path on the device, starting with /.")).not.toBeInTheDocument();
  });

  it("unpins with Most recent book, sending false", async () => {
    const book = "/mnt/us/books/a.epub";
    await open(settings({}, { "featured.pinned": book }), {
      "PUT /api/profiles/colorsoft/settings/featured.pinned": () => json(settings()),
    });
    const pin = within(control("featured.pinned"));
    expect(pin.getByText(book)).toBeInTheDocument();

    fireEvent.click(pin.getByRole("button", { name: "Most recent book" }));

    await waitFor(() =>
      expect(pin.getByRole("button", { name: "Most recent book" })).toHaveAttribute("aria-pressed", "true"),
    );
    expect(puts()).toEqual([["/api/profiles/colorsoft/settings/featured.pinned", { value: false }]]);
    expect(pin.queryByText(book)).not.toBeInTheDocument();
  });

  it("shows a refused write beside the control, reads the file again and shows its value", async () => {
    let answer = settings();
    await open(answer, {
      [SETTINGS]: () => json(answer),
      "PUT /api/profiles/colorsoft/settings/look": () => {
        answer = settings({}, { look: "diner", text_size: "small" });
        return json({ error: '"editorial" is not allowed for look' }, 400);
      },
    });
    const look = within(control("look"));

    fireEvent.click(look.getByRole("button", { name: "Editorial" }));

    expect(await look.findByText(`Couldn't save Look: "editorial" is not allowed for look.`)).toBeInTheDocument();
    await waitFor(() =>
      expect(within(control("text_size")).getByRole("button", { name: "Small" })).toHaveAttribute("aria-pressed", "true"),
    );
    expect(gets(SETTINGS_URL)).toBe(2);
    expect(look.getByRole("button", { name: "Diner" })).toHaveAttribute("aria-pressed", "true");
    expect(look.getByRole("button", { name: "Editorial" })).toHaveAttribute("aria-pressed", "false");
  });

  it("disables the control while its write runs, so a second click waits for the first", async () => {
    const first = deferred<Response>();
    await open(settings(), {
      "PUT /api/profiles/colorsoft/settings/text_size": (body) =>
        (body as { value: string }).value === "small"
          ? first.promise
          : json(settings({}, { text_size: "large" })),
    });
    const size = within(control("text_size"));

    fireEvent.click(size.getByRole("button", { name: "Small" }));
    await waitFor(() => expect(size.getByRole("button", { name: "Large" })).toBeDisabled());
    fireEvent.click(size.getByRole("button", { name: "Large" }));
    expect(puts()).toEqual([["/api/profiles/colorsoft/settings/text_size", { value: "small" }]]);
    expect(within(control("look")).getByRole("button", { name: "Editorial" })).toBeEnabled();

    first.resolve(json(settings({}, { text_size: "small" })));
    await waitFor(() => expect(size.getByRole("button", { name: "Large" })).toBeEnabled());
    expect(size.getByRole("button", { name: "Small" })).toHaveAttribute("aria-pressed", "true");
    fireEvent.click(size.getByRole("button", { name: "Large" }));

    await waitFor(() => expect(size.getByRole("button", { name: "Large" })).toHaveAttribute("aria-pressed", "true"));
    expect(puts().map(([, body]) => body)).toEqual([{ value: "small" }, { value: "large" }]);
  });

  it("keeps a write answered after the user opened an editor", async () => {
    const answer = deferred<Response>();
    await open(settings(), { "PUT /api/profiles/colorsoft/settings/look": () => answer.promise });

    fireEvent.click(within(control("look")).getByRole("button", { name: "Editorial" }));
    await waitFor(() => expect(puts()).toHaveLength(1));
    fireEvent.click(screen.getByRole("link", { name: /Layout ·/ }));
    expect(await screen.findByRole("link", { name: "Done" })).toBeInTheDocument();
    answer.resolve(json(settings({}, { look: "editorial" })));
    await answer.promise;
    await new Promise((resolve) => setTimeout(resolve, 0));

    fireEvent.click(screen.getByRole("link", { name: "Done" }));

    const look = within(await waitFor(() => control("look")));
    expect(look.getByRole("button", { name: "Editorial" })).toHaveAttribute("aria-pressed", "true");
    expect(look.getByRole("button", { name: "Editorial" })).toBeEnabled();
    expect(gets(SETTINGS_URL)).toBe(1);
  });

  it("keeps a write in flight across an editor, and its failure line once answered", async () => {
    const answer = deferred<Response>();
    await open(settings(), { "PUT /api/profiles/colorsoft/settings/look": () => answer.promise });

    fireEvent.click(within(control("look")).getByRole("button", { name: "Editorial" }));
    await waitFor(() => expect(puts()).toHaveLength(1));
    fireEvent.click(screen.getByRole("link", { name: /Layout ·/ }));
    fireEvent.click(await screen.findByRole("link", { name: "Done" }));

    const look = within(await waitFor(() => control("look")));
    expect(look.getByRole("button", { name: "Diner" })).toBeDisabled();
    expect(look.getByRole("button", { name: "Editorial" })).toBeDisabled();

    answer.resolve(json({ error: '"editorial" is not allowed for look' }, 400));

    expect(await look.findByText(`Couldn't save Look: "editorial" is not allowed for look.`)).toBeInTheDocument();
    await waitFor(() => expect(look.getByRole("button", { name: "Editorial" })).toBeEnabled());
  });

  it("sends a second key's write only once the first is answered, so answers land in order", async () => {
    const first = deferred<Response>();
    await open(settings(), {
      "PUT /api/profiles/colorsoft/settings/look": () => first.promise,
      "PUT /api/profiles/colorsoft/settings/text_size": () =>
        json(settings({}, { look: "editorial", text_size: "small" })),
    });
    const look = within(control("look"));
    const size = within(control("text_size"));

    fireEvent.click(look.getByRole("button", { name: "Editorial" }));
    fireEvent.click(size.getByRole("button", { name: "Small" }));
    await waitFor(() => expect(puts()).toHaveLength(1));
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(puts()).toEqual([["/api/profiles/colorsoft/settings/look", { value: "editorial" }]]);
    expect(size.getByRole("button", { name: "Large" })).toBeDisabled();

    first.resolve(json(settings({}, { look: "editorial" })));

    await waitFor(() => expect(puts()).toHaveLength(2));
    expect(puts()[1]).toEqual(["/api/profiles/colorsoft/settings/text_size", { value: "small" }]);
    await waitFor(() => expect(size.getByRole("button", { name: "Small" })).toHaveAttribute("aria-pressed", "true"));
    expect(look.getByRole("button", { name: "Editorial" })).toHaveAttribute("aria-pressed", "true");
    expect(size.getByRole("button", { name: "Large" })).toBeEnabled();
  });
});

describe("the reports", () => {
  it("lists keys outside the schema with their text, kept", async () => {
    await open(
      settings({
        unknown: [
          { key: "old.flag", text: "true" },
          { key: 3, text: '{\n    ["a"] = 1,\n}' },
        ],
      }),
    );

    const section = screen.getByRole("region", { name: "Not in the schema" });
    expect(within(section).getByRole("heading", { name: "Not in the schema" })).toBeInTheDocument();
    expect(within(section).getByText("Kept as they are when the studio writes.")).toBeInTheDocument();
    expect(within(section).getByText("old.flag")).toBeInTheDocument();
    expect(within(section).getByText("true")).toBeInTheDocument();
    expect(within(section).getByText("3")).toBeInTheDocument();
    expect(within(section).getByText((_, el) => el?.textContent === '{\n    ["a"] = 1,\n}' && el.tagName === "PRE")).toBeInTheDocument();
  });

  it("has no Not in the schema section when every stored key is in it", async () => {
    await open(settings());

    expect(screen.queryByText("Not in the schema")).not.toBeInTheDocument();
  });

  it("says beside a refused stored value that it shows the default", async () => {
    await open(settings({ invalid: [{ key: "text_size" }] }));

    const note = "The stored value isn't allowed, so this shows the default.";
    expect(within(control("text_size")).getByText(note)).toBeInTheDocument();
    expect(screen.getAllByText(note)).toHaveLength(1);
  });

  it("shows a read-only file with its line and every control disabled", async () => {
    await open(settings({ state: "read_only", schema_version: 2, reason: "newer" }));

    expect(
      screen.getByText(
        "This settings file is from schema version 2, newer than this studio's 1, so it is shown and not written.",
      ),
    ).toBeInTheDocument();
    for (const key of schema.keys) expect(inert(control(key.id))).toBe(true);
  });

  it("shows an unreadable file with its reason and every control disabled", async () => {
    await open(
      settings({ state: "unreadable", schema_version: null, reason: "the file returns a string, not a table" }),
    );

    expect(
      screen.getByText("The studio can't read this settings file: the file returns a string, not a table"),
    ).toBeInTheDocument();
    for (const key of schema.keys) expect(inert(control(key.id))).toBe(true);
  });

  it("leaves every control operable for a writable file", async () => {
    await open(settings());

    // The place has nothing to operate until the place search comes.
    const operable = schema.keys.filter((key) => key.type !== "location");
    for (const key of operable) expect(inert(control(key.id))).toBe(false);
  });
});

describe("the editors", () => {
  it.each([
    ["Layout · 5 rows", "#/profiles/colorsoft/layout", "Edit layout"],
    ["Launcher · 6 entries", "#/profiles/colorsoft/launcher", "Launcher"],
  ])("opens %s at its route, and Done returns to the form", async (link, hash, heading) => {
    await open(settings());

    fireEvent.click(screen.getByRole("link", { name: link }));

    await waitFor(() => expect(location.hash).toBe(hash));
    expect(await screen.findByRole("link", { name: "Done" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: heading })).toBeInTheDocument();
    expect(document.querySelector("[data-key]")).toBeNull();

    fireEvent.click(screen.getByRole("link", { name: "Done" }));

    await waitFor(() => expect(location.hash).toBe("#/profiles/colorsoft"));
    expect(await waitFor(() => control("look"))).toBeInTheDocument();
    expect(gets(SETTINGS_URL)).toBe(1);
  });

  it.each([
    ["#/profiles/colorsoft/layout", "Edit layout"],
    ["#/profiles/colorsoft/launcher", "Launcher"],
  ])("shows the editor slot when loaded at %s", async (hash, heading) => {
    await open(settings(), {}, hash);

    expect(await screen.findByRole("link", { name: "Done" })).toHaveAttribute("href", "#/profiles/colorsoft");
    expect(screen.getByRole("heading", { name: heading })).toBeInTheDocument();
    expect(document.querySelector("[data-key]")).toBeNull();
  });

  it("shows the form for any other route under a profile", async () => {
    await open(settings(), {}, "#/profiles/colorsoft/elsewhere");

    expect(await waitFor(() => control("look"))).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Done" })).not.toBeInTheDocument();
  });
});
