import type { Key } from "../../../schema";
import { Field, type ControlProps } from "./Field";

type Place = Extract<Key, { type: "location" }>["default"];

/** The stored place's name and coordinates. */
export function LocationControl({ entry, value, notes }: ControlProps<Extract<Key, { type: "location" }>>) {
  const place = value as Place;
  return (
    <Field entry={entry} notes={notes}>
      <p className="place">
        <span>{place.name}</span>
        <span className="muted">
          {place.latitude}, {place.longitude}
        </span>
      </p>
    </Field>
  );
}
