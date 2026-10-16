import { useId, useRef, useState } from "react";
import { catalog } from "../../catalog";
import {
  hasIcon,
  hasLabel,
  kindLine,
  move,
  remove,
  setIcon,
  setLabel,
  trim,
  type Entry,
  type Pos,
} from "../../core/entries-edit";
import { IconPicker, IconTile } from "./icons";

/** Stores a launcher operation's result (null, a refused one, does nothing); true once written. */
export type Apply = (next: Entry[] | null, folderRemoved?: boolean) => Promise<boolean>;

/**
 * What the entry shows: a screen entry its catalog label and icon, a folder or directory entry its
 * label and the folder icon, any other its own (kopanda.koplugin/launcher_entries.lua:95-101).
 */
export function entryView(entry: Entry): { label: string; icon: string } {
  if (entry.kind === "folder" || entry.kind === "directory") return { label: entry.label, icon: "folder" };
  if (hasIcon(entry)) return { label: entry.label, icon: entry.icon };
  const screen = catalog.screens[entry.kind][entry.target];
  return { label: screen?.label ?? entry.target, icon: screen?.icon ?? entry.target };
}

/** The inline label field: Enter or blur keeps a label not empty after trimming, Escape gives null. */
function LabelField({
  id,
  initial,
  disabled,
  onDone,
}: {
  id: string;
  initial: string;
  disabled: boolean;
  onDone: (label: string | null) => void;
}) {
  const [value, setValue] = useState(initial);
  const settled = useRef(false);

  function settle(label: string | null) {
    if (settled.current) return;
    settled.current = true;
    onDone(label);
  }

  return (
    <input
      id={id}
      type="text"
      className="entry-label-field"
      aria-label="Label"
      autoFocus
      value={value}
      disabled={disabled}
      onChange={(e) => setValue(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === "Enter") {
          e.preventDefault();
          if (trim(value) !== "") settle(value);
        } else if (e.key === "Escape") {
          settle(null);
        }
      }}
      onBlur={() => settle(trim(value) === "" ? null : value)}
    />
  );
}

/**
 * One entry of the shown list at pos in entries: its icon, label and kind line, up and down (disabled
 * at the ends) and remove. A label of its own edits in place; an action or plugin entry's icon opens
 * the icon picker; a top-level folder's kind line opens its list, and removing it asks first.
 */
export function EntryRow({
  entries,
  pos,
  length,
  disabled,
  apply,
  onOpen,
}: {
  entries: readonly Entry[];
  pos: Pos;
  /** The shown list's length, for the down arrow. */
  length: number;
  disabled: boolean;
  apply: Apply;
  onOpen: () => void;
}) {
  const labelId = useId();
  const confirmId = useId();
  const [open, setOpen] = useState<"label" | "icon" | "confirm" | null>(null);
  const i = pos[pos.length - 1]!;
  const entry = pos.length === 1 ? entries[i - 1]! : (entries[pos[0] - 1] as Extract<Entry, { kind: "folder" }>).entries[i - 1]!;
  const view = entryView(entry);
  const topFolder = pos.length === 1 && entry.kind === "folder" ? entry : null;

  function removeEntry() {
    if (topFolder) {
      setOpen("confirm");
      return;
    }
    const { entries: next, folderRemoved } = remove(entries, pos);
    void apply(next, folderRemoved);
  }

  function labelDone(label: string | null) {
    setOpen(null);
    if (label !== null && trim(label) !== view.label) void apply(setLabel(entries, pos, label));
  }

  const n = topFolder?.entries.length ?? 0;
  const question = `Remove ${view.label} and its ${n} ${n === 1 ? "entry" : "entries"}?`;

  return (
    <li className="entry" aria-labelledby={labelId}>
      <div className="entry-main">
        {hasIcon(entry) ? (
          <button
            type="button"
            className="icon-button"
            aria-label={`Icon of ${view.label}`}
            aria-expanded={open === "icon"}
            disabled={disabled}
            onClick={() => setOpen(open === "icon" ? null : "icon")}
          >
            <IconTile id={view.icon} />
          </button>
        ) : (
          <IconTile id={view.icon} />
        )}
        <div className="entry-text">
          {open === "label" ? (
            <LabelField id={labelId} initial={view.label} disabled={disabled} onDone={labelDone} />
          ) : hasLabel(entry) ? (
            <button id={labelId} type="button" className="entry-label" disabled={disabled} onClick={() => setOpen("label")}>
              {view.label}
            </button>
          ) : (
            <span id={labelId} className="entry-label">
              {view.label}
            </span>
          )}
          {topFolder ? (
            <button type="button" className="entry-kind" disabled={disabled} onClick={onOpen}>
              {kindLine(entry)}
            </button>
          ) : (
            <span className="entry-kind">{kindLine(entry)}</span>
          )}
        </div>
        <div className="entry-controls">
          <button
            type="button"
            aria-label={`Move ${view.label} up`}
            disabled={disabled || i === 1}
            onClick={() => void apply(move(entries, pos, -1))}
          >
            ↑
          </button>
          <button
            type="button"
            aria-label={`Move ${view.label} down`}
            disabled={disabled || i === length}
            onClick={() => void apply(move(entries, pos, 1))}
          >
            ↓
          </button>
          <button type="button" aria-label={`Remove ${view.label}`} disabled={disabled} onClick={removeEntry}>
            ×
          </button>
        </div>
      </div>
      {open === "icon" && hasIcon(entry) && (
        <div className="entry-panel">
          <IconPicker
            current={entry.icon}
            disabled={disabled}
            onPick={(id) => {
              setOpen(null);
              if (id !== entry.icon) void apply(setIcon(entries, pos, id));
            }}
          />
          <button type="button" disabled={disabled} onClick={() => setOpen(null)}>
            Cancel
          </button>
        </div>
      )}
      {open === "confirm" && (
        <div className="entry-panel confirm" role="alertdialog" aria-labelledby={confirmId}>
          <p id={confirmId}>{question}</p>
          <button type="button" onClick={() => setOpen(null)}>
            Cancel
          </button>
          <button
            type="button"
            disabled={disabled}
            onClick={() => {
              setOpen(null);
              void apply(remove(entries, pos).entries);
            }}
          >
            Remove
          </button>
        </div>
      )}
    </li>
  );
}
