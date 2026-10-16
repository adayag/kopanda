import type { Key } from "../../../schema";
import { count, EditorLink } from "./EditorLink";
import type { ControlProps } from "./Field";

/** "Layout · N rows", opening the layout editor. */
export function RowsControl({ entry, value, disabled, profileHref, notes }: ControlProps<Extract<Key, { type: "rows" }>>) {
  const text = `${entry.label} · ${count(value, "row", "rows")}`;
  return <EditorLink entry={entry} href={`${profileHref}/layout`} text={text} disabled={disabled} notes={notes} />;
}
