import type { Key } from "../../../schema";
import { Field, type ControlProps } from "./Field";

/** A toggle labelled with the key; a change writes the new value. */
export function BooleanControl({ entry, value, disabled, write, notes }: ControlProps<Extract<Key, { type: "boolean" }>>) {
  return (
    <Field entry={entry} notes={notes} labelled={false}>
      <label className="toggle">
        <input type="checkbox" checked={value === true} disabled={disabled} onChange={(e) => void write(e.target.checked)} />
        <span className="setting-label">{entry.label}</span>
      </label>
    </Field>
  );
}
