import type { Key } from "../../../schema";
import { Field, type ControlProps } from "./Field";

/** A button per choice, the current one pressed; picking another writes its value. */
export function ChoiceControl({ entry, value, disabled, write, notes }: ControlProps<Extract<Key, { type: "choice" }>>) {
  return (
    <Field entry={entry} notes={notes}>
      <div className="choices">
        {entry.choices.map((choice) => (
          <button
            key={choice.value}
            type="button"
            className="choice"
            aria-pressed={choice.value === value}
            disabled={disabled}
            onClick={() => {
              if (choice.value !== value) void write(choice.value);
            }}
          >
            {choice.label}
          </button>
        ))}
      </div>
    </Field>
  );
}
