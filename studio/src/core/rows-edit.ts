// A port of the plugin's row operations (kopanda.koplugin/rows_edit.lua) over a layout.rows value,
// with the labels, shares and captions the layout editor shows. Pure: every operation copies the
// rows it is given and answers new rows, or the note it refuses with (null for none); none changes
// its input. Row and column indices count from 1, as the plugin's do, so
// spec/fixtures/studio/rows_edit_cases.lua holds both sides to the same cases.
import { schema } from "../schema.js";

export interface Slot {
  widget: string;
  share: number;
}
export type Row = Slot[];
export type Rows = Row[];

/** An operation's answer: the new rows, or its refusal with the note to show, null for none. */
export type Edit = { rows: Rows } | { refused: string | null };

const found = schema.keys.find((key) => key.id === "layout.rows");
if (found?.type !== "rows") throw new Error("the schema has no layout.rows of type rows");
/** The schema's layout.rows entry. */
export const entry = found;

/** The most columns a row holds. */
export const maxColumns = entry.max_columns;

// A widget is on the home at most once (kopanda.koplugin/settings.lua's rows validator).
const ONCE = "Each widget can be on the home once.";

const LABELS: Record<string, string> = {
  date: "Date",
  clock: "Clock",
  weather: "Weather",
  quote: "Quote",
  stats: "Reading stats",
  featured: "Featured book",
  launcher: "Launcher",
};

const COLUMNS = ["one column", "two columns", "three columns"];

function copy(rows: Rows): Rows {
  return rows.map((row) => row.map((slot) => ({ ...slot })));
}

function onHome(rows: Rows, widget: string): boolean {
  return rows.some((row) => row.some((slot) => slot.widget === widget));
}

/** Row i moved delta places; refused with no note past either end. */
export function move(rows: Rows, i: number, delta: number): Edit {
  const to = i + delta;
  if (to < 1 || to > rows.length) return { refused: null };
  const next = copy(rows);
  next.splice(to - 1, 0, ...next.splice(i - 1, 1));
  return { rows: next };
}

/** A new last row of widget alone. */
export function addRow(rows: Rows, widget: string): Edit {
  if (onHome(rows, widget)) return { refused: ONCE };
  return { rows: [...copy(rows), [{ widget, share: 1 }]] };
}

/** A new last column of row i, of widget at share 1; refused at the schema's max_columns. */
export function addColumn(rows: Rows, i: number, widget: string): Edit {
  if (rows[i - 1]!.length >= maxColumns) return { refused: "A row holds at most three columns." };
  if (onHome(rows, widget)) return { refused: ONCE };
  const next = copy(rows);
  next[i - 1]!.push({ widget, share: 1 });
  return { rows: next };
}

/** Column j of row i shows widget, at its share. */
export function changeWidget(rows: Rows, i: number, j: number, widget: string): Edit {
  if (onHome(rows, widget)) return { refused: ONCE };
  const next = copy(rows);
  next[i - 1]![j - 1]!.widget = widget;
  return { rows: next };
}

/** Column j of row i takes share, a whole number from 1 to 3, of its row's width. */
export function setShare(rows: Rows, i: number, j: number, share: number): Edit {
  if (!Number.isInteger(share) || share < 1 || share > 3) return { refused: "A column's width is 1, 2 or 3." };
  const next = copy(rows);
  next[i - 1]![j - 1]!.share = share;
  return { rows: next };
}

/** Row i without column j; refused for a row's only column. */
export function removeColumn(rows: Rows, i: number, j: number): Edit {
  if (rows[i - 1]!.length < 2) return { refused: "A row keeps at least one column." };
  const next = copy(rows);
  next[i - 1]!.splice(j - 1, 1);
  return { rows: next };
}

/** The rows without row i; refused for the only row, since the home needs one. */
export function removeRow(rows: Rows, i: number): Edit {
  if (rows.length < 2) return { refused: "The home needs at least one row." };
  const next = copy(rows);
  next.splice(i - 1, 1);
  return { rows: next };
}

/** A copy of the schema's default; the looks hold no layout of their own, so it is both looks'. */
export function reset(): Edit {
  return { rows: copy(entry.default) };
}

/** The schema's widgets not on the home, in schema order. */
export function unused(rows: Rows): string[] {
  return entry.widgets.filter((widget) => !onHome(rows, widget));
}

/** A widget's label, or its id for one with none. */
export function label(id: string): string {
  return Object.hasOwn(LABELS, id) ? LABELS[id]! : id;
}

function gcd(a: number, b: number): number {
  while (b !== 0) [a, b] = [b, a % b];
  return a;
}

/** Column j's share of row: "full" alone in its row, else its share over the row's total, reduced. */
export function shareText(row: Row, j: number): string {
  if (row.length === 1) return "full";
  const total = row.reduce((sum, slot) => sum + slot.share, 0);
  const share = row[j - 1]!.share;
  const d = gcd(share, total);
  return `${share / d}/${total / d}`;
}

/** Row i's caption: its number and its columns, then " · selected" when selected. */
export function caption(rows: Rows, i: number, selected: boolean): string {
  const text = `Row ${i} · ${COLUMNS[rows[i - 1]!.length - 1]}`;
  return selected ? `${text} · selected` : text;
}
