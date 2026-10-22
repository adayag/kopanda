// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { useLayoutEffect } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { entryFor } from "../../src/core/rows-edit";
import { schema } from "../../src/schema";
import { App } from "../../src/ui/App";
import type { Settings } from "../../src/ui/api";
import { LayoutEditor, type LayoutEditorProps } from "../../src/ui/layout/LayoutEditor";

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

type Rows = { widget: string; share: number }[][];

const s = (widget: string, share = 1) => ({ widget, share });

/** The schema's default layout. */
const DEFAULT: Rows = [
  [s("date"), s("clock")],
  [s("featured")],
  [s("quote")],
  [s("launcher")],
  [s("weather"), s("stats")],
];

/** Four rows without weather, stats and the five insight widgets, so seven widgets are unused. */
const FOUR: Rows = [[s("date"), s("clock")], [s("featured")], [s("quote")], [s("launcher")]];

/** Every widget, within three columns a row. */
const EVERY: Rows = [
  [s("date"), s("clock")],
  [s("featured")],
  [s("quote"), s("heatmap"), s("calendar")],
  [s("launcher"), s("forecast"), s("hours")],
  [s("weather"), s("stats"), s("records")],
];

/** Page 2's default layout. */
const PAGE_2: Rows = [
  [s("date"), s("clock")],
  [s("heatmap")],
  [s("calendar"), s("forecast")],
  [s("hours"), s("records")],
];

/** The five insight widgets' labels, in the schema's order. */
const INSIGHTS = ["Reading heatmap", "Calendar", "Finish by", "Reading hours", "Sessions"];

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

function sent(method: string): [string, unknown][] {
  return fetchMock.mock.calls
    .filter(([, init]) => init?.method === method)
    .map(([input, init]) => [String(input), JSON.parse(String(init?.body))]);
}

const FIT_URL = "/api/profiles/colorsoft/layout-fit";
const PUT_URL = "/api/profiles/colorsoft/settings/layout.rows";
const PUT_2_URL = "/api/profiles/colorsoft/settings/layout.rows_2";
const FIT = `POST ${FIT_URL}`;
const PUT = `PUT ${PUT_URL}`;
const PUT_2 = `PUT ${PUT_2_URL}`;

/** The fit requests' bodies; the preview pane's renders are not fit requests. */
function fitBodies(): unknown[] {
  return sent("POST")
    .filter(([url]) => url === FIT_URL)
    .map(([, body]) => body);
}

/** The fit requests' rows. */
function fits(): unknown[] {
  return fitBodies().map((body) => (body as { rows: unknown }).rows);
}

/** The PUTs, every one to url, as their values. */
function puts(url = PUT_URL): unknown[] {
  return sent("PUT").map(([to, body]) => {
    expect(to).toBe(url);
    return (body as { value: unknown }).value;
  });
}

/** A PUT of key that answers the file holding the rows written. */
const writes =
  (key: string): Answer =>
  (body) =>
    json(settings({}, { [key]: (body as { value: unknown }).value }));
const written = writes("layout.rows");
const fits0: Answer = () => json({ checked: true, current: 0, proposed: 0 });

/**
 * Opens the colorsoft profile's layout editor for page 1, or page 2's at view "layout-2", with the
 * settings answer, fit answering "fits" and every PUT written unless routes say otherwise.
 */
async function open(answer: Settings, routes: Record<string, Answer> = {}, view = "layout") {
  history.replaceState(null, "", `/#/profiles/colorsoft/${view}`);
  route({
    "GET /api/profiles/colorsoft": () => json(colorsoft),
    "GET /api/profiles/colorsoft/settings": () => json(answer),
    [FIT]: fits0,
    [PUT]: written,
    [PUT_2]: writes("layout.rows_2"),
    ...routes,
  });
  render(<App />);
  await screen.findByRole("heading", { name: view === "layout" ? "Layout" : "Page 2" });
}

const withRows = (rows: Rows) => settings({}, { "layout.rows": rows });

function editor(): HTMLElement {
  return screen.getByRole("region", { name: /^(Layout|Page 2)$/ });
}

function cards(): HTMLElement[] {
  return within(screen.getByRole("list", { name: "Rows" })).getAllByRole("listitem");
}

function card(i: number): ReturnType<typeof within> {
  return within(cards()[i - 1]!);
}

/** Selects row i by its caption. */
function select(i: number): void {
  fireEvent.click(card(i).getByRole("button", { name: /^Row / }));
}

function click(name: string | RegExp, within_: ReturnType<typeof within> = within(editor())): void {
  fireEvent.click(within_.getByRole("button", { name }));
}

/** The labels of the open picker's buttons, the marked ones suffixed with " ✓". */
function picker(name: string): string[] {
  return within(screen.getByRole("group", { name })).getAllByRole("button").map(
    (b) => `${b.textContent}${b.getAttribute("aria-pressed") === "true" ? " ✓" : ""}`,
  );
}

/** The editor's buttons, by name, that are enabled. */
function enabled(): string[] {
  return within(editor())
    .getAllByRole("button")
    .filter((b) => !(b as HTMLButtonElement).disabled)
    .map((b) => b.getAttribute("aria-label") ?? b.textContent ?? "");
}

beforeEach(() => {
  history.replaceState(null, "", "/");
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("the layout editor's screen", () => {
  it("shows Home over Layout, Done, and a card per row of the default layout", async () => {
    await open(settings());

    expect(within(editor()).getByText("Home")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Done" })).toHaveAttribute("href", "#/profiles/colorsoft");
    expect(cards()).toHaveLength(5);
    expect(card(1).getByRole("button", { name: "Row 1 · two columns" })).toBeInTheDocument();
    expect(card(1).getByRole("button", { name: "Date 1/2" })).toBeInTheDocument();
    expect(card(1).getByRole("button", { name: "Clock 1/2" })).toBeInTheDocument();
    expect(card(2).getByRole("button", { name: "Featured book full" })).toBeInTheDocument();
    expect(card(5).getByRole("button", { name: "Reading stats 1/2" })).toBeInTheDocument();
    expect(card(1).getByRole("button", { name: "Move row 1 up" })).toBeDisabled();
    expect(card(1).getByRole("button", { name: "Move row 1 down" })).toBeEnabled();
    expect(card(5).getByRole("button", { name: "Move row 5 up" })).toBeEnabled();
    expect(card(5).getByRole("button", { name: "Move row 5 down" })).toBeDisabled();
    expect(fits()).toEqual([]);
  });

  it("shows a selected row's buttons: Width and Remove column only on a row of two or more", async () => {
    await open(settings());

    select(1);

    expect(card(1).getByRole("button", { name: "Row 1 · two columns · selected" })).toBeInTheDocument();
    expect(card(1).getByRole("button", { name: "Date 1/2" })).toHaveAttribute("aria-pressed", "true");
    expect(card(1).getByRole("button", { name: "Clock 1/2" })).toHaveAttribute("aria-pressed", "false");
    const buttons = ["Add column", "Change widget", "Width", "Remove column", "Remove row"];
    for (const name of buttons) expect(card(1).getByRole("button", { name })).toBeInTheDocument();
    expect(card(2).queryByRole("button", { name: "Remove row" })).not.toBeInTheDocument();

    select(2);

    expect(card(1).queryByRole("button", { name: "Remove row" })).not.toBeInTheDocument();
    expect(card(2).getByRole("button", { name: "Add column" })).toBeInTheDocument();
    expect(card(2).getByRole("button", { name: "Change widget" })).toBeInTheDocument();
    expect(card(2).getByRole("button", { name: "Remove row" })).toBeInTheDocument();
    expect(card(2).queryByRole("button", { name: "Width" })).not.toBeInTheDocument();
    expect(card(2).queryByRole("button", { name: "Remove column" })).not.toBeInTheDocument();
  });

  it("selects a column by its box on the selected card, and the first column on another card", async () => {
    await open(settings());

    fireEvent.click(card(1).getByRole("button", { name: "Clock 1/2" }));
    expect(card(1).getByRole("button", { name: "Date 1/2" })).toHaveAttribute("aria-pressed", "true");

    fireEvent.click(card(1).getByRole("button", { name: "Clock 1/2" }));
    expect(card(1).getByRole("button", { name: "Clock 1/2" })).toHaveAttribute("aria-pressed", "true");
    expect(card(1).getByRole("button", { name: "Date 1/2" })).toHaveAttribute("aria-pressed", "false");
  });

  it("disables Add column at three columns and with every widget on the home, and Add row with none unused", async () => {
    await open(withRows(EVERY));

    select(1);

    expect(card(1).getByRole("button", { name: "Add column" })).toBeDisabled();
    expect(within(editor()).getByRole("button", { name: "Add row" })).toBeDisabled();
  });

  it("disables Add column on a row of three though widgets are unused", async () => {
    await open(withRows([[s("date"), s("clock"), s("weather")], [s("featured")]]));

    select(1);

    expect(card(1).getByRole("button", { name: "Add column" })).toBeDisabled();
    expect(within(editor()).getByRole("button", { name: "Add row" })).toBeEnabled();
  });

  it("lists only unused widgets in Add row and Add column, and the column's own first, marked, in Change widget", async () => {
    await open(withRows(FOUR));

    click("Add row");
    expect(picker("Add a widget")).toEqual(["Weather", "Reading stats", ...INSIGHTS]);

    select(1);
    click("Add column", card(1));
    expect(picker("Add a widget")).toEqual(["Weather", "Reading stats", ...INSIGHTS]);

    fireEvent.click(card(1).getByRole("button", { name: "Clock 1/2" }));
    click("Change widget", card(1));
    expect(picker("Change widget")).toEqual(["Clock ✓", "Weather", "Reading stats", ...INSIGHTS]);
    expect(fits()).toEqual([]);
  });

  it("lists 1, 2 and 3 in Width, the column's share marked", async () => {
    await open(withRows([[s("date", 2), s("clock")], [s("featured")]]));

    select(1);
    click("Width", card(1));

    expect(picker("Width")).toEqual(["1", "2 ✓", "3"]);
  });

  it("returns to the form on Done", async () => {
    await open(settings());

    fireEvent.click(screen.getByRole("link", { name: "Done" }));

    await waitFor(() => expect(location.hash).toBe("#/profiles/colorsoft"));
    expect(await screen.findByRole("link", { name: "Layout · 5 rows" })).toBeInTheDocument();
  });
});

describe("a change", () => {
  it.each<[string, Rows, () => void, Rows]>([
    ["move up", FOUR, () => click("Move row 2 up"), [[s("featured")], [s("date"), s("clock")], [s("quote")], [s("launcher")]]],
    ["move down", FOUR, () => click("Move row 3 down"), [[s("date"), s("clock")], [s("featured")], [s("launcher")], [s("quote")]]],
    [
      "add column",
      FOUR,
      () => {
        select(2);
        click("Add column", card(2));
        click("Weather", within(screen.getByRole("group", { name: "Add a widget" })));
      },
      [[s("date"), s("clock")], [s("featured"), s("weather")], [s("quote")], [s("launcher")]],
    ],
    [
      "change widget",
      FOUR,
      () => {
        select(1);
        fireEvent.click(card(1).getByRole("button", { name: "Clock 1/2" }));
        click("Change widget", card(1));
        click("Reading stats", within(screen.getByRole("group", { name: "Change widget" })));
      },
      [[s("date"), s("stats")], [s("featured")], [s("quote")], [s("launcher")]],
    ],
    [
      "width 2",
      FOUR,
      () => {
        select(1);
        fireEvent.click(card(1).getByRole("button", { name: "Clock 1/2" }));
        click("Width", card(1));
        click("2", within(screen.getByRole("group", { name: "Width" })));
      },
      [[s("date"), s("clock", 2)], [s("featured")], [s("quote")], [s("launcher")]],
    ],
    [
      "remove column",
      FOUR,
      () => {
        select(1);
        click("Remove column", card(1));
      },
      [[s("clock")], [s("featured")], [s("quote")], [s("launcher")]],
    ],
    [
      "remove row",
      FOUR,
      () => {
        select(3);
        click("Remove row", card(3));
      },
      [[s("date"), s("clock")], [s("featured")], [s("launcher")]],
    ],
    [
      "add row",
      FOUR,
      () => {
        click("Add row");
        click("Weather", within(screen.getByRole("group", { name: "Add a widget" })));
      },
      [[s("date"), s("clock")], [s("featured")], [s("quote")], [s("launcher")], [s("weather")]],
    ],
    ["reset", FOUR, () => click("Reset to the look's default"), DEFAULT],
    ["reset of the default", DEFAULT, () => click("Reset to the look's default"), DEFAULT],
  ])("%s checks fit once, then writes layout.rows once and shows it", async (_name, start, act, expected) => {
    await open(withRows(start));

    act();

    await waitFor(() => expect(puts()).toEqual([expected]));
    expect(fitBodies()).toEqual([{ rows: expected, key: "layout.rows" }]);
    await waitFor(() => expect(cards()).toHaveLength(expected.length));
    expect(screen.queryByText("Checking fit…")).not.toBeInTheDocument();
  });

  it("shows Checking fit… and disables every control while the fit request waits", async () => {
    const fit = deferred<Response>();
    await open(withRows(FOUR), { [FIT]: () => fit.promise });

    click("Move row 2 up");

    expect(await screen.findByText("Checking fit…")).toBeInTheDocument();
    expect(enabled()).toEqual([]);
    expect(screen.getByRole("link", { name: "Done" })).toHaveAttribute("href");
    expect(puts()).toEqual([]);

    fit.resolve(json({ checked: true, current: 0, proposed: 0 }));

    await waitFor(() => expect(puts()).toHaveLength(1));
    await waitFor(() => expect(screen.queryByText("Checking fit…")).not.toBeInTheDocument());
    await waitFor(() => expect(enabled()).toContain("Move row 1 down"));
  });

  it("keeps every control disabled while the write is in flight", async () => {
    const put = deferred<Response>();
    await open(withRows(FOUR), { [PUT]: () => put.promise });

    click("Move row 2 up");

    await waitFor(() => expect(puts()).toHaveLength(1));
    expect(enabled()).toEqual([]);

    put.resolve(json(withRows([[s("featured")], [s("date"), s("clock")], [s("quote")], [s("launcher")]])));

    await waitFor(() => expect(enabled()).toContain("Move row 1 down"));
    expect(card(1).getByRole("button", { name: "Featured book full" })).toBeInTheDocument();
  });

  it("refuses a change that leaves out more rows than the current layout, with no PUT", async () => {
    await open(withRows(FOUR), { [FIT]: () => json({ checked: true, current: 0, proposed: 1 }) });

    click("Move row 2 up");

    expect(await screen.findByText("That won't fit on the home.")).toBeInTheDocument();
    expect(fits()).toHaveLength(1);
    expect(puts()).toEqual([]);
    expect(card(1).getByRole("button", { name: "Date 1/2" })).toBeInTheDocument();
    expect(enabled()).toContain("Move row 2 up");
  });

  it("writes a change that shrinks a layout already too tall", async () => {
    await open(withRows(FOUR), { [FIT]: () => json({ checked: true, current: 2, proposed: 1 }) });

    click("Move row 2 up");

    await waitFor(() => expect(puts()).toHaveLength(1));
    expect(screen.queryByText("That won't fit on the home.")).not.toBeInTheDocument();
  });

  it("writes when fit couldn't be checked and says so until a later check succeeds", async () => {
    let answer: unknown = { checked: false, reason: "no emulator: set KOPANDA_EMULATOR" };
    await open(withRows(FOUR), { [FIT]: () => json(answer) });

    click("Move row 2 up");

    expect(await screen.findByText("Fit not checked: no emulator: set KOPANDA_EMULATOR")).toBeInTheDocument();
    await waitFor(() => expect(puts()).toHaveLength(1));

    answer = { checked: true, current: 0, proposed: 0 };
    await waitFor(() => expect(enabled()).toContain("Move row 1 down"));
    click("Move row 1 down");

    await waitFor(() => expect(puts()).toHaveLength(2));
    expect(screen.queryByText(/Fit not checked/)).not.toBeInTheDocument();
  });

  it("writes and says fit wasn't checked when the fit request itself fails", async () => {
    await open(withRows(FOUR), { [FIT]: () => json({ error: "no profile" }, 404) });

    click("Move row 2 up");

    expect(await screen.findByText("Fit not checked: no profile")).toBeInTheDocument();
    await waitFor(() => expect(puts()).toHaveLength(1));
  });

  it("shows a refused operation's note with no fit request and no PUT", async () => {
    await open(withRows([[s("featured")]]));

    select(1);
    click("Remove row", card(1));

    expect(await screen.findByText("The home needs at least one row.")).toBeInTheDocument();
    expect(fits()).toEqual([]);
    expect(sent("PUT")).toEqual([]);
  });

  it("clears a note at the next change", async () => {
    await open(withRows([[s("featured")]]));

    select(1);
    click("Remove row", card(1));
    expect(await screen.findByText("The home needs at least one row.")).toBeInTheDocument();
    click("Reset to the look's default");

    await waitFor(() => expect(puts()).toHaveLength(1));
    expect(screen.queryByText("The home needs at least one row.")).not.toBeInTheDocument();
  });

  it("shows a failed write's line, and the file's rows with the selection where it was", async () => {
    await open(withRows(FOUR), {
      [PUT]: () => json({ error: "layout.rows: not allowed" }, 400),
    });

    select(2);
    click("Move row 2 up", card(2));

    expect(await screen.findByText("Couldn't save Layout: layout.rows: not allowed.")).toBeInTheDocument();
    await waitFor(() => expect(enabled()).toContain("Move row 2 up"));
    expect(card(1).getByRole("button", { name: "Date 1/2" })).toBeInTheDocument();
    expect(card(2).getByRole("button", { name: "Row 2 · one column · selected" })).toBeInTheDocument();
  });

  it("ignores a fit answer that arrives after Done, and writes nothing", async () => {
    const fit = deferred<Response>();
    await open(withRows(FOUR), { [FIT]: () => fit.promise });

    click("Move row 2 up");
    await screen.findByText("Checking fit…");
    fireEvent.click(screen.getByRole("link", { name: "Done" }));
    await waitFor(() => expect(location.hash).toBe("#/profiles/colorsoft"));
    fit.resolve(json({ checked: true, current: 0, proposed: 0 }));
    await fit.promise;
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(puts()).toEqual([]);
  });

  it("ignores a fit answer after Done for a change made before the editor's effects ran", async () => {
    // A click can land between the editor's commit and its passive effects (a loaded test run, a fast
    // user); a parent's layout effect forces that ordering here.
    const fit = deferred<Response>();
    route({ [FIT]: () => fit.promise });
    const onWrite = vi.fn<LayoutEditorProps["onWrite"]>(async () => true);
    function ClickOnCommit() {
      useLayoutEffect(() => {
        screen.getByRole("button", { name: "Move row 2 up" }).click();
      }, []);
      return (
        <LayoutEditor
          entry={entryFor("layout.rows")}
          profileId="colorsoft"
          settings={withRows(FOUR)}
          pending={false}
          error={undefined}
          onWrite={onWrite}
        />
      );
    }

    const { unmount } = render(<ClickOnCommit />);
    expect(fits()).toHaveLength(1);
    unmount();
    fit.resolve(json({ checked: true, current: 0, proposed: 0 }));
    await fit.promise;
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(onWrite).not.toHaveBeenCalled();
  });

  it("edits the default when the stored layout is refused, and the first write replaces it", async () => {
    await open(settings({ invalid: [{ key: "layout.rows" }] }));

    expect(screen.getByText("The stored value isn't allowed, so this shows the default.")).toBeInTheDocument();
    expect(cards()).toHaveLength(5);
    click("Move row 2 up");

    await waitFor(() => expect(puts()).toEqual([[DEFAULT[1], DEFAULT[0], ...DEFAULT.slice(2)]]));
  });
});

describe("page 2", () => {
  const withPage2 = (rows: Rows) => settings({}, { "layout.rows_2": rows });

  it("opens at /layout-2 with Page 2 over Home and a card per row of page 2's default", async () => {
    await open(settings(), {}, "layout-2");

    expect(within(editor()).getByText("Home")).toBeInTheDocument();
    expect(cards()).toHaveLength(4);
    expect(card(1).getByRole("button", { name: "Date 1/2" })).toBeInTheDocument();
    expect(card(2).getByRole("button", { name: "Reading heatmap full" })).toBeInTheDocument();
    expect(card(3).getByRole("button", { name: "Calendar 1/2" })).toBeInTheDocument();
    expect(card(3).getByRole("button", { name: "Finish by 1/2" })).toBeInTheDocument();
    expect(card(4).getByRole("button", { name: "Reading hours 1/2" })).toBeInTheDocument();
    expect(card(4).getByRole("button", { name: "Sessions 1/2" })).toBeInTheDocument();
  });

  it("shows page 2's stored rows, not layout.rows's", async () => {
    await open(settings({}, { "layout.rows": FOUR, "layout.rows_2": [[s("records")]] }), {}, "layout-2");

    expect(cards()).toHaveLength(1);
    expect(card(1).getByRole("button", { name: "Sessions full" })).toBeInTheDocument();
  });

  it("checks fit for layout.rows_2, then writes layout.rows_2 and shows it", async () => {
    await open(settings(), {}, "layout-2");

    click("Move row 2 up");

    const expected = [PAGE_2[1], PAGE_2[0], ...PAGE_2.slice(2)];
    await waitFor(() => expect(puts(PUT_2_URL)).toEqual([expected]));
    expect(fitBodies()).toEqual([{ rows: expected, key: "layout.rows_2" }]);
    await waitFor(() => expect(card(1).getByRole("button", { name: "Reading heatmap full" })).toBeInTheDocument());
  });

  it("resets to page 2's default", async () => {
    await open(withPage2([[s("records")]]), {}, "layout-2");

    click("Reset to the look's default");

    await waitFor(() => expect(puts(PUT_2_URL)).toEqual([PAGE_2]));
    await waitFor(() => expect(cards()).toHaveLength(4));
  });

  it("shows a failed write of layout.rows_2 by its label", async () => {
    await open(settings(), { [PUT_2]: () => json({ error: "layout.rows_2: not allowed" }, 400) }, "layout-2");

    click("Move row 2 up");

    expect(await screen.findByText("Couldn't save Page 2: layout.rows_2: not allowed.")).toBeInTheDocument();
  });

  it("notes a refused stored value of layout.rows_2, not of layout.rows", async () => {
    await open(settings({ invalid: [{ key: "layout.rows" }] }), {}, "layout-2");
    expect(screen.queryByText("The stored value isn't allowed, so this shows the default.")).not.toBeInTheDocument();
  });
});

describe("the selection", () => {
  it("follows a moved row", async () => {
    await open(withRows(FOUR));

    select(2);
    click("Move row 2 up", card(2));

    await waitFor(() => expect(card(1).getByRole("button", { name: "Featured book full" })).toBeInTheDocument());
    await waitFor(() => expect(card(1).getByRole("button", { name: "Row 1 · one column · selected" })).toBeInTheDocument());
    expect(card(2).queryByRole("button", { name: "Remove row" })).not.toBeInTheDocument();
  });

  it("clears on a removed row", async () => {
    await open(withRows(FOUR));

    select(3);
    click("Remove row", card(3));

    await waitFor(() => expect(cards()).toHaveLength(3));
    expect(within(editor()).queryByRole("button", { name: "Remove row" })).not.toBeInTheDocument();
    expect(within(editor()).queryByRole("button", { name: /selected/ })).not.toBeInTheDocument();
  });

  it("stays put when a change is refused for fit", async () => {
    await open(withRows(FOUR), { [FIT]: () => json({ checked: true, current: 0, proposed: 1 }) });

    select(2);
    click("Move row 2 up", card(2));

    expect(await screen.findByText("That won't fit on the home.")).toBeInTheDocument();
    expect(card(2).getByRole("button", { name: "Row 2 · one column · selected" })).toBeInTheDocument();
  });
});

describe("a file the studio won't write", () => {
  it.each([
    [
      settings({ state: "read_only", schema_version: 2 }),
      "This settings file is from schema version 2, newer than this studio's 1, so it is shown and not written.",
    ],
    [
      settings({ state: "unreadable", schema_version: null, reason: "the file returns a string, not a table" }),
      "The studio can't read this settings file: the file returns a string, not a table",
    ],
  ])("opens with every control disabled and its line", async (answer, line) => {
    await open(answer);

    expect(screen.getByText(line)).toBeInTheDocument();
    expect(cards()).toHaveLength(5);
    expect(enabled()).toEqual([]);
    expect(screen.getByRole("link", { name: "Done" })).toHaveAttribute("href", "#/profiles/colorsoft");
  });
});
