import { useState } from "react";
import type { Key } from "../../../schema";
import { trim, type Candidate } from "../../../server/geocoding";
import { searchPlaces } from "../../api";
import { Field, type ControlProps } from "./Field";

type Place = Extract<Key, { type: "location" }>["default"];

/** Where the place search stands: nothing shown, waiting, a list to choose from, or a note. */
type Search =
  | { state: "idle" }
  | { state: "searching" }
  | { state: "found"; candidates: Candidate[] }
  | { state: "none"; query: string }
  | { state: "failed" };

/**
 * The stored place's name and coordinates, and the device's place search (location_search.lua):
 * a typed city or ZIP code, the places the server finds for it, and a pick that writes one.
 */
export function LocationControl({ entry, value, disabled, write, notes }: ControlProps<Extract<Key, { type: "location" }>>) {
  const place = value as Place;
  const [typed, setTyped] = useState("");
  const [search, setSearch] = useState<Search>({ state: "idle" });
  const searching = search.state === "searching";

  function run() {
    const query = trim(typed);
    if (query === "") return;
    setSearch({ state: "searching" });
    searchPlaces(query).then(
      (candidates) =>
        setSearch(candidates.length === 0 ? { state: "none", query } : { state: "found", candidates }),
      () => setSearch({ state: "failed" }),
    );
  }

  function pick({ name, latitude, longitude }: Candidate) {
    const done = () => {
      setSearch({ state: "idle" });
      setTyped("");
    };
    if (name === place.name && latitude === place.latitude && longitude === place.longitude) {
      done();
      return;
    }
    void write({ name, latitude, longitude }).then((written) => {
      if (written) done();
    });
  }

  return (
    <Field entry={entry} notes={notes}>
      <p className="place">
        <span>{place.name}</span>
        <span className="muted">
          {place.latitude}, {place.longitude}
        </span>
      </p>
      <form
        className="pin"
        onSubmit={(e) => {
          e.preventDefault();
          run();
        }}
      >
        <input
          type="text"
          aria-label="Place to search for"
          placeholder="City or ZIP code"
          value={typed}
          disabled={disabled || searching}
          onChange={(e) => setTyped(e.target.value)}
        />
        <button type="submit" disabled={disabled || searching}>
          Search
        </button>
      </form>
      {searching && <p className="note">Searching…</p>}
      {search.state === "found" && (
        <>
          <p className="note">Choose a place</p>
          <div className="choices">
            {search.candidates.map((candidate, i) => (
              <button key={i} type="button" className="choice" disabled={disabled} onClick={() => pick(candidate)}>
                {candidate.shown}
              </button>
            ))}
          </div>
        </>
      )}
      {search.state === "none" && <p className="note">No place found for “{search.query}”.</p>}
      {search.state === "failed" && <p className="note">Couldn't search for places.</p>}
    </Field>
  );
}
