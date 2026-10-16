// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { catalog } from "../../src/catalog";
import { schema } from "../../src/schema";
import { App } from "../../src/ui/App";
import type { Settings } from "../../src/ui/api";

// The launcher editor (C13), on the real catalog, with fetch stubbed and recording requests.

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

function settings(entries: unknown, changes: Partial<Settings> = {}): Settings {
  return {
    path: colorsoft.settings_path,
    exists: true,
    state: "writable",
    schema_version: 1,
    values: { ...defaults, "launcher.entries": entries },
    invalid: [],
    unknown: [],
    ...changes,
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

const fetchMock = vi.fn<typeof fetch>();
const PUT = "PUT /api/profiles/colorsoft/settings/launcher.entries";

/** Opens the launcher editor on answer; each PUT is answered with the value it sent unless put says otherwise. */
async function open(answer: Settings, put?: (body: { value: unknown }) => Response) {
  history.replaceState(null, "", "/#/profiles/colorsoft/launcher");
  fetchMock.mockImplementation(async (input, init) => {
    const name = `${init?.method ?? "GET"} ${String(input)}`;
    if (name === "GET /api/profiles/colorsoft") return json(colorsoft);
    if (name === "GET /api/profiles/colorsoft/settings") return json(answer);
    if (name === PUT) {
      const body = JSON.parse(String(init?.body)) as { value: unknown };
      return put ? put(body) : json(settings(body.value));
    }
    throw new Error(`unexpected fetch ${name}`);
  });
  render(<App />);
  await screen.findByRole("heading", { name: "Launcher" });
}

/** The values PUT to launcher.entries, in order. */
function puts(): unknown[] {
  return fetchMock.mock.calls
    .filter(([, init]) => init?.method === "PUT")
    .map(([, init]) => (JSON.parse(String(init?.body)) as { value: unknown }).value);
}

/** Lets any write a click started reach fetch. */
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

const entriesList = () => screen.getByRole("list", { name: "Entries" });
const rows = () => within(entriesList()).queryAllByRole("listitem");
const row = (label: string) => within(entriesList()).getByRole("listitem", { name: label });
const button = (name: string) => screen.getByRole("button", { name });
const adding = () => within(screen.getByRole("region", { name: "Add an entry" }));

const L = { kind: "kopanda", target: "library" };
const S = { kind: "kopanda", target: "series" };
const A = { kind: "kopanda", target: "authors" };
const H = { kind: "koreader", target: "history" };
const W = { kind: "koreader", target: "wifi" };
const ST = { kind: "kopanda", target: "settings" };
const HISTORY = { kind: "action", action: "history", label: "History", icon: "action" };
const act = (id: string) => ({ kind: "action", action: id, label: id.toUpperCase(), icon: "action" });
const TOOLS = { kind: "folder", label: "Tools", entries: [act("a"), act("b"), act("c")] };

beforeEach(() => {
  history.replaceState(null, "", "/");
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("the list", () => {
  it("shows the default six with their catalog labels, icons and kind lines, arrows disabled at the ends", async () => {
    await open(settings(schema.keys.find((k) => k.type === "launcher")!.default));

    expect(screen.getByText("6 of 6 on the home screen")).toBeInTheDocument();
    const labels = ["Library", "Series", "Authors", "History", "Wi-Fi", "Settings"];
    expect(rows()).toEqual(labels.map(row));
    expect(rows().map((r) => within(r).getByText(/ · /).textContent)).toEqual([
      "KoPanda · library",
      "KoPanda · series",
      "KoPanda · authors",
      "KOReader · history",
      "KOReader · wifi",
      "KoPanda · settings",
    ]);
    const icons = ["library", "series", "authors", "history", "wifi", "settings"];
    labels.forEach((label, i) => {
      const img = row(label).querySelector("img")!;
      const prefix = "data:image/svg+xml,";
      expect(img.getAttribute("src")!.startsWith(prefix)).toBe(true);
      expect(decodeURIComponent(img.getAttribute("src")!.slice(prefix.length))).toBe(
        catalog.icons.find((icon) => icon.id === icons[i])!.svg,
      );
      expect(img.closest(".icon-tile")).not.toBeNull();
    });
    expect(button("Move Library up")).toBeDisabled();
    expect(button("Move Library down")).toBeEnabled();
    expect(button("Move Settings up")).toBeEnabled();
    expect(button("Move Settings down")).toBeDisabled();
    expect(screen.getByText("The seventh entry and beyond go into a folder.")).toBeInTheDocument();
  });

  it("shows an icon id the catalog lacks as the id", async () => {
    await open(settings([{ ...HISTORY, icon: "calibre" }]));

    expect(within(row("History")).getByText("calibre")).toBeInTheDocument();
    expect(row("History").querySelector("img")).toBeNull();
  });

  it("lists an entry whose action the catalog lacks by its ids, and moves it", async () => {
    const sui = { kind: "action", action: "simpleui_open", label: "SUI", icon: "action" };
    await open(settings([sui, L]));

    expect(within(row("SUI")).getByText("Action · simpleui_open")).toBeInTheDocument();
    fireEvent.click(button("Move SUI down"));

    await waitFor(() => expect(puts()).toEqual([[L, sui]]));
  });

  it("shows an empty launcher, whose Add works", async () => {
    await open(settings([]));

    expect(screen.getByText("0 of 6 on the home screen")).toBeInTheDocument();
    expect(rows()).toEqual([]);
    fireEvent.click(adding().getByRole("button", { name: "KoPanda screen" }));
    fireEvent.click(adding().getByRole("button", { name: "Library" }));

    await waitFor(() => expect(puts()).toEqual([[L]]));
  });

  it("edits the default when the stored launcher is refused, saying so", async () => {
    await open(settings(defaults["launcher.entries"], { invalid: [{ key: "launcher.entries" }] }));

    expect(screen.getByText("The stored value isn't allowed, so this shows the default.")).toBeInTheDocument();
    fireEvent.click(button("Remove Settings"));

    await waitFor(() => expect(puts()).toEqual([[L, S, A, H, W]]));
  });
});

describe("each change is one PUT", () => {
  it("moves", async () => {
    await open(settings([L, S, A]));
    fireEvent.click(button("Move Series down"));

    await waitFor(() => expect(puts()).toEqual([[L, A, S]]));
    await waitFor(() => expect(rows()).toEqual([row("Library"), row("Authors"), row("Series")]));
  });

  it("removes", async () => {
    await open(settings([L, S, A]));
    fireEvent.click(button("Remove Series"));

    await waitFor(() => expect(puts()).toEqual([[L, A]]));
    await waitFor(() => expect(rows()).toHaveLength(2));
  });

  it("edits a directory entry's label in place; Escape cancels", async () => {
    const books = { kind: "directory", path: "/mnt/us/books", label: "books" };
    await open(settings([L, books]));

    fireEvent.click(within(row("books")).getByRole("button", { name: "books" }));
    fireEvent.keyDown(screen.getByRole("textbox", { name: "Label" }), { key: "Escape" });
    expect(screen.queryByRole("textbox", { name: "Label" })).not.toBeInTheDocument();
    fireEvent.click(within(row("books")).getByRole("button", { name: "books" }));
    const field = screen.getByRole("textbox", { name: "Label" });
    fireEvent.change(field, { target: { value: "   " } });
    fireEvent.keyDown(field, { key: "Enter" });
    await settle();
    expect(puts()).toEqual([]);
    fireEvent.change(field, { target: { value: " My books " } });
    fireEvent.keyDown(field, { key: "Enter" });

    await waitFor(() => expect(puts()).toEqual([[L, { ...books, label: "My books" }]]));
    expect(await screen.findByRole("listitem", { name: "My books" })).toBeInTheDocument();
  });

  it("saves a label on blur, trimmed; a blank one saves nothing", async () => {
    const books = { kind: "directory", path: "/mnt/us/books", label: "books" };
    await open(settings([L, books]));

    fireEvent.click(within(row("books")).getByRole("button", { name: "books" }));
    fireEvent.change(screen.getByRole("textbox", { name: "Label" }), { target: { value: " My books " } });
    fireEvent.blur(screen.getByRole("textbox", { name: "Label" }));
    await waitFor(() => expect(puts()).toEqual([[L, { ...books, label: "My books" }]]));
    fireEvent.click(within(await screen.findByRole("listitem", { name: "My books" })).getByRole("button", { name: "My books" }));
    fireEvent.change(screen.getByRole("textbox", { name: "Label" }), { target: { value: "   " } });
    fireEvent.blur(screen.getByRole("textbox", { name: "Label" }));

    await settle();
    expect(puts()).toHaveLength(1);
    expect(screen.queryByRole("textbox", { name: "Label" })).not.toBeInTheDocument();
  });

  it("picks an action entry's icon from every catalog icon, the current one marked", async () => {
    await open(settings([L, HISTORY]));

    fireEvent.click(button("Icon of History"));
    const picker = within(screen.getByRole("group", { name: "Icon" }));
    expect(picker.getAllByRole("button", { pressed: false }).length + 1).toBe(catalog.icons.length);
    expect(picker.getByRole("button", { pressed: true })).toHaveAccessibleName("Action or plugin entry");
    fireEvent.click(picker.getByRole("button", { name: "Sun (weather, refresh weather)" }));

    await waitFor(() => expect(puts()).toEqual([[L, { ...HISTORY, icon: "sun" }]]));
    expect(within(row("Library")).queryByRole("button", { name: /Icon of/ })).toBeNull();
  });

  it("asks before removing a folder; Cancel sends nothing, Remove one PUT", async () => {
    await open(settings([L, TOOLS]));

    fireEvent.click(button("Remove Tools"));
    expect(screen.getByText("Remove Tools and its 3 entries?")).toBeInTheDocument();
    fireEvent.click(button("Cancel"));
    await settle();
    expect(puts()).toEqual([]);
    expect(screen.queryByText("Remove Tools and its 3 entries?")).not.toBeInTheDocument();
    fireEvent.click(button("Remove Tools"));
    fireEvent.click(button("Remove"));

    await waitFor(() => expect(puts()).toEqual([[L]]));
  });

  it("shows a failed PUT's line", async () => {
    await open(settings([L, S]), () => json({ error: "the disk is full" }, 500));
    fireEvent.click(button("Remove Series"));

    expect(await screen.findByText("Couldn't save Launcher: the disk is full.")).toBeInTheDocument();
    await waitFor(() => expect(button("Remove Series")).toBeEnabled());
  });

  it.each([
    ["read_only", "This settings file is from schema version 2, newer than this studio's 1, so it is shown and not written."],
    ["unreadable", "The studio can't read this settings file: line 1, column 1: bad"],
  ] as const)("disables every control for a %s file, with its line", async (state, line) => {
    await open(settings([L, TOOLS], { state, schema_version: state === "read_only" ? 2 : null, reason: "line 1, column 1: bad" }));

    expect(screen.getByText(line)).toBeInTheDocument();
    const buttons = screen.getAllByRole("button");
    expect(buttons.length).toBeGreaterThan(10);
    for (const b of buttons) expect(b).toBeDisabled();
  });
});

describe("a row's open panel belongs to its entry", () => {
  it("closes a folder's remove question when the folder moves, so nothing else is removed", async () => {
    await open(settings([L, S, TOOLS]));

    fireEvent.click(button("Remove Tools"));
    fireEvent.click(button("Move Tools up"));

    await waitFor(() => expect(puts()).toEqual([[L, TOOLS, S]]));
    await waitFor(() => expect(rows()).toEqual([row("Library"), row("Tools"), row("Series")]));
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(screen.queryByText("Remove Series and its 0 entries?")).not.toBeInTheDocument();
  });

  it("closes the icon picker when its entry moves", async () => {
    await open(settings([L, HISTORY, act("x")]));

    fireEvent.click(button("Icon of History"));
    fireEvent.click(button("Move History down"));

    await waitFor(() => expect(rows()).toEqual([row("Library"), row("X"), row("History")]));
    expect(screen.queryByRole("group", { name: "Icon" })).not.toBeInTheDocument();
  });
});

describe("a folder's list", () => {
  it("opens with Folder · N over its label; its adds go into it; Done returns", async () => {
    await open(settings([L, TOOLS]));

    fireEvent.click(button("Folder · 3 entries ›"));
    expect(screen.getByText("Folder · 3")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Tools" })).toBeInTheDocument();
    expect(rows().map((r) => within(r).getByText(/^Action ·/).textContent)).toEqual(["Action · a", "Action · b", "Action · c"]);
    expect(screen.queryByText("The seventh entry and beyond go into a folder.")).not.toBeInTheDocument();
    fireEvent.click(adding().getByRole("button", { name: "Action" }));
    fireEvent.click(adding().getByRole("button", { name: "History" }));
    fireEvent.click(adding().getByRole("button", { name: "Add" }));

    await waitFor(() => expect(puts()).toEqual([[L, { ...TOOLS, entries: [...TOOLS.entries, HISTORY] }]]));
    expect(await screen.findByText("Folder · 4")).toBeInTheDocument();
    fireEvent.click(button("Done"));
    expect(screen.getByRole("heading", { name: "Launcher" })).toBeInTheDocument();
    expect(screen.getByText("2 of 6 on the home screen")).toBeInTheDocument();
  });

  it("returns to the top level when its only entry is removed, not to the folder after it", async () => {
    const games = { kind: "folder", label: "Games", entries: [act("b"), act("c")] };
    await open(settings([L, { kind: "folder", label: "Tools", entries: [act("a")] }, games]));

    fireEvent.click(button("Folder · 1 entry ›"));
    fireEvent.click(button("Remove A"));

    await waitFor(() => expect(puts()).toEqual([[L, games]]));
    expect(await screen.findByRole("heading", { name: "Launcher" })).toBeInTheDocument();
    expect(screen.getByText("2 of 6 on the home screen")).toBeInTheDocument();
  });
});

describe("adding", () => {
  it.each([
    ["KoPanda screen", "Series", S],
    ["KOReader screen", "Favorites", { kind: "koreader", target: "favorites" }],
  ])("adds a %s, %s, from the schema's targets", async (kind, label, entry) => {
    await open(settings([L]));

    fireEvent.click(adding().getByRole("button", { name: kind }));
    const targets = kind === "KoPanda screen" ? ["Library", "Series", "Authors", "Settings"] : ["History", "Favorites", "Collections", "Wi-Fi"];
    expect(adding().getAllByRole("button").map((b) => b.textContent)).toEqual([...targets, "Cancel"]);
    expect(adding().getByRole("button", { name: label }).querySelector(".icon-tile img")).not.toBeNull();
    fireEvent.click(adding().getByRole("button", { name: label }));

    await waitFor(() => expect(puts()).toEqual([[L, entry]]));
  });

  it("adds a folder on disk from a typed path, refusing / and a relative path", async () => {
    await open(settings([L]));

    fireEvent.click(adding().getByRole("button", { name: "Folder on disk" }));
    const path = adding().getByRole("textbox", { name: "Path on the device" });
    fireEvent.change(path, { target: { value: "/" } });
    fireEvent.click(adding().getByRole("button", { name: "Next" }));
    expect(adding().getByText("Choose a folder inside the root.")).toBeInTheDocument();
    fireEvent.change(path, { target: { value: "books" } });
    fireEvent.click(adding().getByRole("button", { name: "Next" }));
    expect(adding().getByText("Type a folder path on the device, starting with /.")).toBeInTheDocument();
    fireEvent.change(path, { target: { value: "/mnt/us/books/" } });
    fireEvent.click(adding().getByRole("button", { name: "Next" }));
    expect(adding().getByRole("textbox", { name: "Label" })).toHaveValue("books");
    expect(adding().queryByRole("group", { name: "Icon" })).not.toBeInTheDocument();
    fireEvent.click(adding().getByRole("button", { name: "Add" }));

    await waitFor(() => expect(puts()).toEqual([[L, { kind: "directory", path: "/mnt/us/books", label: "books" }]]));
  });

  it("adds an action from the catalog's four sections, its title the label and action the icon", async () => {
    await open(settings([L]));

    fireEvent.click(adding().getByRole("button", { name: "Action" }));
    expect(adding().getAllByRole("heading", { level: 3 }).map((h) => h.textContent)).toEqual(
      catalog.actions.map((section) => section.title),
    );
    fireEvent.click(adding().getByRole("button", { name: "History" }));
    expect(adding().getByRole("textbox", { name: "Label" })).toHaveValue("History");
    const icons = within(adding().getByRole("group", { name: "Icon" }));
    expect(icons.getByRole("button", { pressed: true })).toHaveAccessibleName("Action or plugin entry");
    fireEvent.click(adding().getByRole("button", { name: "Add" }));

    await waitFor(() => expect(puts()).toEqual([[L, HISTORY]]));
  });

  it("adds a plugin's action, with a label and icon of the owner's choosing", async () => {
    const first = catalog.plugins[0]!;
    await open(settings([L]));

    fireEvent.click(adding().getByRole("button", { name: "Plugin" }));
    expect(adding().getAllByRole("button").map((b) => b.textContent)).toEqual([
      ...catalog.plugins.map((p) => p.label),
      "Cancel",
    ]);
    fireEvent.click(adding().getByRole("button", { name: first.label }));
    fireEvent.click(adding().getByRole("button", { name: "History" }));
    fireEvent.change(adding().getByRole("textbox", { name: "Label" }), { target: { value: " Read log " } });
    fireEvent.click(within(adding().getByRole("group", { name: "Icon" })).getByRole("button", { name: "Moon (night weather, sleep, night mode)" }));
    fireEvent.click(adding().getByRole("button", { name: "Add" }));

    await waitFor(() =>
      expect(puts()).toEqual([
        [L, { kind: "plugin", plugin: first.name, action: "history", label: "Read log", icon: "moon" }],
      ]),
    );
  });

  it("makes More in slot six when the seventh goes onto a top level without a folder (D3)", async () => {
    await open(settings([L, S, A, H, W, ST]));

    fireEvent.click(adding().getByRole("button", { name: "KoPanda screen" }));
    fireEvent.click(adding().getByRole("button", { name: "Series" }));

    await waitFor(() => expect(puts()).toEqual([[L, S, A, H, W, { kind: "folder", label: "More", entries: [ST, S] }]]));
  });

  it("puts the seventh into the first folder when there is one (D3)", async () => {
    await open(settings([L, S, A, H, TOOLS, ST]));

    fireEvent.click(adding().getByRole("button", { name: "KOReader screen" }));
    fireEvent.click(adding().getByRole("button", { name: "Wi-Fi" }));

    await waitFor(() => expect(puts()).toEqual([[L, S, A, H, { ...TOOLS, entries: [...TOOLS.entries, W] }, ST]]));
  });

  it("keeps Add disabled for a label empty after trimming", async () => {
    await open(settings([L]));

    fireEvent.click(adding().getByRole("button", { name: "Action" }));
    fireEvent.click(adding().getByRole("button", { name: "History" }));
    const label = adding().getByRole("textbox", { name: "Label" });
    fireEvent.change(label, { target: { value: "" } });
    expect(adding().getByRole("button", { name: "Add" })).toBeDisabled();
    fireEvent.change(label, { target: { value: " \t " } });
    expect(adding().getByRole("button", { name: "Add" })).toBeDisabled();
    fireEvent.submit(label);
    await settle();
    expect(puts()).toEqual([]);
  });

  it.each([
    ["KoPanda screen", []],
    ["KOReader screen", []],
    ["Folder on disk", []],
    ["Folder on disk", ["Next"]],
    ["Action", []],
    ["Action", ["History"]],
    ["Plugin", []],
    ["Plugin", [catalog.plugins[0]!.label]],
    ["Plugin", [catalog.plugins[0]!.label, "History"]],
  ])("adds nothing on Cancel after %s then %j", async (kind, steps) => {
    await open(settings([L]));

    fireEvent.click(adding().getByRole("button", { name: kind }));
    if (kind === "Folder on disk") {
      fireEvent.change(adding().getByRole("textbox", { name: "Path on the device" }), { target: { value: "/mnt/us" } });
    }
    for (const step of steps) fireEvent.click(adding().getByRole("button", { name: step }));
    fireEvent.click(adding().getByRole("button", { name: "Cancel" }));

    expect(adding().getByRole("button", { name: "Plugin" })).toBeInTheDocument();
    await settle();
    expect(puts()).toEqual([]);
  });
});
