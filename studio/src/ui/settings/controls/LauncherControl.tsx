import type { Key } from "../../../schema";
import { count, EditorLink } from "./EditorLink";
import type { ControlProps } from "./Field";

/** "Launcher · N entries", opening the launcher editor. */
export function LauncherControl({ entry, value, disabled, profileHref, notes }: ControlProps<Extract<Key, { type: "launcher" }>>) {
  const text = `${entry.label} · ${count(value, "entry", "entries")}`;
  return <EditorLink entry={entry} href={`${profileHref}/launcher`} text={text} disabled={disabled} notes={notes} />;
}
