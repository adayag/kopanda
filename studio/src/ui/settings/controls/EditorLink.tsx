import type { ReactNode } from "react";
import type { Key } from "../../../schema";
import { Field } from "./Field";

/** A row naming the key and its count, opening its editor; inert while the file can't be written. */
export function EditorLink({
  entry,
  href,
  text,
  disabled,
  notes,
}: {
  entry: Key;
  href: string;
  text: string;
  disabled: boolean;
  notes: ReactNode;
}) {
  return (
    <Field entry={entry} notes={notes} labelled={false}>
      {disabled ? (
        <a className="editor-link" aria-disabled="true">
          {text}
        </a>
      ) : (
        <a className="editor-link" href={href}>
          {text}
        </a>
      )}
    </Field>
  );
}

/** The length of a list value with its noun, "1 row" or "5 rows". */
export function count(value: unknown, one: string, many: string): string {
  const n = Array.isArray(value) ? value.length : 0;
  return `${n} ${n === 1 ? one : many}`;
}
