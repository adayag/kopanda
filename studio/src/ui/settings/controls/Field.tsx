import { useId, type ReactNode } from "react";
import type { Key } from "../../../schema";

/** What the form hands each key's control. */
export interface ControlProps<K extends Key> {
  entry: K;
  /** The key's value from the settings answer, or its schema default when the answer lacks it. */
  value: unknown;
  /** True while the file can't be written or this key's write runs. */
  disabled: boolean;
  /** Writes value for this key; resolves true once written, false when refused. */
  write: (value: unknown) => Promise<boolean>;
  /** The hash of the profile's form, which the editor routes extend. */
  profileHref: string;
  /** The form's lines about this key: a refused stored value, a failed write. */
  notes: ReactNode;
}

/**
 * One key's row, marked with its id: its label unless the control carries it, the control, then the
 * form's notes.
 */
export function Field({
  entry,
  notes,
  labelled = true,
  children,
}: {
  entry: Key;
  notes: ReactNode;
  labelled?: boolean;
  children: ReactNode;
}) {
  const labelId = useId();
  return (
    <div
      className="setting"
      data-key={entry.id}
      role={labelled ? "group" : undefined}
      aria-labelledby={labelled ? labelId : undefined}
    >
      {labelled && (
        <span id={labelId} className="setting-label">
          {entry.label}
        </span>
      )}
      {children}
      {notes}
    </div>
  );
}
