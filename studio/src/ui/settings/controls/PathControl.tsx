import { useState } from "react";
import { validators } from "../../../core/validators";
import type { Key } from "../../../schema";
import { Field, type ControlProps } from "./Field";

/** The words a path key's control uses: a file key's (one with extensions, the wallpaper), or the featured pin's. */
function wording(entry: Extract<Key, { type: "path" }>) {
  if (entry.extensions) {
    return {
      none: "None",
      set: "Use",
      placeholder: "/mnt/us/images/…",
      refused: `A ${entry.label.toLowerCase()} is an image's path on the device, starting with /.`,
    };
  }
  return {
    none: "Most recent book",
    set: "Pin",
    placeholder: "/mnt/us/books/…",
    refused: "A pin is a path on the device, starting with /.",
  };
}

/**
 * The none choice when the value is false, else the stored path; a typed device path is stored, checked
 * by the plugin's own rule first, and the none choice stores false. The featured pin reads "Most recent
 * book" and "Pin"; a file key (the wallpaper) "None" and "Use".
 */
export function PathControl({ entry, value, disabled, write, notes }: ControlProps<Extract<Key, { type: "path" }>>) {
  const [typed, setTyped] = useState("");
  const [refused, setRefused] = useState(false);
  const words = wording(entry);

  function store() {
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
          {words.none}
        </button>
        {typeof value === "string" && <code className="choice current">{value}</code>}
      </div>
      <form
        className="pin"
        onSubmit={(e) => {
          e.preventDefault();
          store();
        }}
      >
        <input
          type="text"
          aria-label="Path on the device"
          placeholder={words.placeholder}
          value={typed}
          disabled={disabled}
          onChange={(e) => setTyped(e.target.value)}
        />
        <button type="submit" disabled={disabled}>
          {words.set}
        </button>
      </form>
      {refused && <p className="note">{words.refused}</p>}
    </Field>
  );
}
