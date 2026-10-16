import { useState } from "react";
import { validators } from "../../../core/validators";
import type { Key } from "../../../schema";
import { Field, type ControlProps } from "./Field";

/**
 * "Most recent book" when the value is false, else the pinned path; a typed device path pins, checked
 * by the plugin's own rule first, and Most recent book unpins.
 */
export function PathControl({ entry, value, disabled, write, notes }: ControlProps<Extract<Key, { type: "path" }>>) {
  const [typed, setTyped] = useState("");
  const [refused, setRefused] = useState(false);

  function pin() {
    if (!validators.path(entry, typed)) {
      setRefused(true);
      return;
    }
    setRefused(false);
    if (typed === value) return;
    void write(typed).then((written) => {
      if (written) setTyped("");
    });
  }

  return (
    <Field entry={entry} notes={notes}>
      <div className="choices">
        <button
          type="button"
          className="choice"
          aria-pressed={value === false}
          disabled={disabled}
          onClick={() => {
            if (value !== false) void write(false);
          }}
        >
          Most recent book
        </button>
        {typeof value === "string" && <code className="choice current">{value}</code>}
      </div>
      <form
        className="pin"
        onSubmit={(e) => {
          e.preventDefault();
          pin();
        }}
      >
        <input
          type="text"
          aria-label="Path on the device"
          placeholder="/mnt/us/books/…"
          value={typed}
          disabled={disabled}
          onChange={(e) => setTyped(e.target.value)}
        />
        <button type="submit" disabled={disabled}>
          Pin
        </button>
      </form>
      {refused && <p className="note">A pin is a path on the device, starting with /.</p>}
    </Field>
  );
}
