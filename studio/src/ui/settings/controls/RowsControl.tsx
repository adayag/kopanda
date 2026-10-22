import type { Key } from "../../../schema";
import { count, EditorLink } from "./EditorLink";
import type { ControlProps } from "./Field";

/** Each rows key's layout editor, after the profile's href. */
const VIEWS: Record<string, string> = { "layout.rows": "layout", "layout.rows_2": "layout-2" };

/** "Layout · N rows" or "Page 2 · N rows", opening that key's layout editor. */
export function RowsControl({ entry, value, disabled, profileHref, notes }: ControlProps<Extract<Key, { type: "rows" }>>) {
  const text = `${entry.label} · ${count(value, "row", "rows")}`;
  const href = `${profileHref}/${VIEWS[entry.id]}`;
  return <EditorLink entry={entry} href={href} text={text} disabled={disabled} notes={notes} />;
}
