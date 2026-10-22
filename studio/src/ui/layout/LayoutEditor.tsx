import { useId, useLayoutEffect, useRef, useState } from "react";
import {
  addColumn,
  addRow,
  caption,
  changeWidget,
  label,
  maxColumns,
  move,
  removeColumn,
  removeRow,
  reset,
  setShare,
  shareText,
  unused,
  type Edit,
  type Rows,
  type RowsEntry,
} from "../../core/rows-edit";
import { schema, type Key } from "../../schema";
import { checkFit, type FitAnswer, type Settings } from "../api";
import { profileHref } from "../ProfileList";
import { FileState } from "../settings/SettingsForm";

/** The selected row and column, counting from 1; the editor's own, never stored. */
interface Selection {
  row: number;
  column: number;
}

/** The open picker: Add row's at the foot, or one of the selected card's. */
type Picker = "add_row" | "add_column" | "change_widget" | "width";

/** One option of a picker: its label, whether it is marked as current, and the edit it makes. */
interface Option {
  label: string;
  marked?: boolean;
  edit: Edit | null;
}

/** A picker as a small inline menu; an option with no edit (the column's own widget) hands null. */
function PickerMenu({
  heading,
  options,
  disabled,
  onPick,
}: {
  heading: string;
  options: Option[];
  disabled: boolean;
  onPick: (edit: Edit | null) => void;
}) {
  return (
    <div className="picker" role="group" aria-label={heading}>
      <span className="picker-heading">{heading}</span>
      <div className="choices">
        {options.map((option) => (
          <button
            key={option.label}
            type="button"
            className="choice"
            aria-pressed={option.marked ? true : undefined}
            disabled={disabled}
            onClick={() => onPick(option.edit)}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}

export interface LayoutEditorProps {
  /** The rows key the editor edits: layout.rows, or layout.rows_2 for page 2. */
  entry: RowsEntry;
  profileId: string;
  /** The profile's settings file as the API last answered it; its value of the key is what the editor shows. */
  settings: Settings;
  /** True while a write of the key is in flight. */
  pending: boolean;
  /** The failure line of the last write of the key. */
  error: string | undefined;
  /** Writes one key; resolves true once written, false when refused. */
  onWrite: (entry: Key, value: unknown) => Promise<boolean>;
}

/**
 * The layout editor (the device's edit layout, kopanda.koplugin/edit_layout.lua): a card per row with
 * its arrows, caption and a box per column; the selected card's buttons; Add row and Reset at the foot.
 * Each change is a row operation, checked against the home's fit, then written as one PUT of the
 * key; the rows shown are always the settings answer's.
 */
export function LayoutEditor({ entry, profileId, settings, pending, error, onWrite }: LayoutEditorProps) {
  const rows = (settings.values[entry.id] ?? entry.default) as Rows;
  const [selected, setSelected] = useState<Selection | null>(null);
  const [picker, setPicker] = useState<Picker | null>(null);
  const [checking, setChecking] = useState(false);
  const [note, setNote] = useState<string | null>(null);
  const [unchecked, setUnchecked] = useState<string | null>(null);
  // Aborted when the editor closes, so a fit answer arriving after Done writes nothing. Set in a layout
  // effect, which runs at commit, so a click that lands before the passive effects still has its signal.
  const closed = useRef<AbortController | null>(null);
  const titleId = useId();

  useLayoutEffect(() => {
    const controller = new AbortController();
    closed.current = controller;
    return () => controller.abort();
  }, []);

  const busy = checking || pending || settings.state !== "writable";
  // A selection the rows shown no longer hold is none.
  const selection =
    selected !== null && selected.column <= (rows[selected.row - 1]?.length ?? 0) ? selected : null;
  const spare = unused(rows, entry);

  /**
   * Applies an operation's answer: its note when refused; "That won't fit on the home." when the
   * proposed rows leave out more home rows than the current ones; otherwise one write, after which the
   * selection becomes next. Any failure to check fit allows the write, saying so.
   */
  async function apply(edit: Edit, next: Selection | null): Promise<void> {
    setPicker(null);
    if ("refused" in edit) {
      setNote(edit.refused);
      return;
    }
    const signal = closed.current?.signal;
    setNote(null);
    setChecking(true);
    let fit: FitAnswer;
    try {
      fit = await checkFit(profileId, edit.rows, entry.id, signal);
    } catch (err) {
      fit = { checked: false, reason: err instanceof Error ? err.message : String(err) };
    }
    if (signal?.aborted) return;
    setChecking(false);
    if (fit.checked) {
      setUnchecked(null);
      if (fit.proposed > fit.current) {
        setNote("That won't fit on the home.");
        return;
      }
    } else {
      setUnchecked(fit.reason);
    }
    if ((await onWrite(entry, edit.rows)) && !signal?.aborted) setSelected(next);
  }

  function run(edit: Edit, next: Selection | null): void {
    void apply(edit, next);
  }

  /** Row i moved by delta, the selection following the rows it moves. */
  function moveRow(i: number, delta: number): void {
    let next = selection;
    if (next !== null && (next.row === i || next.row === i + delta)) {
      next = { row: next.row === i ? i + delta : i, column: next.column };
    }
    run(move(rows, i, delta), next);
  }

  function select(row: number, column = 1): void {
    setSelected({ row, column });
    setPicker(null);
  }

  function toggle(which: Picker): void {
    setPicker((open) => (open === which ? null : which));
  }

  /** What picking an option does: its edit, the selection then becoming next; no edit closes the menu. */
  function pick(edit: Edit | null, next: Selection | null): void {
    if (edit === null) setPicker(null);
    else run(edit, next);
  }

  /** The unused widgets as options, each with edit's answer for its id. */
  function unusedOptions(edit: (widget: string) => Edit): Option[] {
    return spare.map((widget) => ({ label: label(widget), edit: edit(widget) }));
  }

  function cardButtons(i: number, j: number) {
    const row = rows[i - 1]!;
    const slot = row[j - 1]!;
    const sel = { row: i, column: j };
    return (
      <>
        <div className="card-buttons">
          <button
            type="button"
            disabled={busy || row.length >= maxColumns || spare.length === 0}
            onClick={() => toggle("add_column")}
          >
            Add column
          </button>
          <button type="button" disabled={busy} onClick={() => toggle("change_widget")}>
            Change widget
          </button>
          {row.length >= 2 && (
            <>
              <button type="button" disabled={busy} onClick={() => toggle("width")}>
                Width
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={() => run(removeColumn(rows, i, j), { row: i, column: Math.min(j, row.length - 1) })}
              >
                Remove column
              </button>
            </>
          )}
          <button type="button" className="muted" disabled={busy} onClick={() => run(removeRow(rows, i), null)}>
            Remove row
          </button>
        </div>
        {picker === "add_column" && (
          <PickerMenu
            heading="Add a widget"
            options={unusedOptions((w) => addColumn(rows, i, w))}
            disabled={busy}
            onPick={(edit) => pick(edit, sel)}
          />
        )}
        {picker === "change_widget" && (
          <PickerMenu
            heading="Change widget"
            options={[
              { label: label(slot.widget), marked: true, edit: null },
              ...unusedOptions((w) => changeWidget(rows, i, j, w)),
            ]}
            disabled={busy}
            onPick={(edit) => pick(edit, sel)}
          />
        )}
        {picker === "width" && (
          <PickerMenu
            heading="Width"
            options={[1, 2, 3].map((share) => ({
              label: String(share),
              marked: slot.share === share,
              edit: setShare(rows, i, j, share),
            }))}
            disabled={busy}
            onPick={(edit) => pick(edit, sel)}
          />
        )}
      </>
    );
  }

  return (
    <section className="layout-editor" aria-labelledby={titleId}>
      <header className="editor-head">
        <div>
          <span className="editor-aside">Home</span>
          <h2 id={titleId}>{entry.label}</h2>
        </div>
        <a className="editor-link" href={profileHref(profileId)}>
          Done
        </a>
      </header>
      <FileState settings={settings} version={schema.version} />
      {settings.invalid.some(({ key }) => key === entry.id) && (
        <p className="note">The stored value isn't allowed, so this shows the default.</p>
      )}
      {unchecked !== null && <p className="note">Fit not checked: {unchecked}</p>}
      {checking && (
        <p role="status" className="note">
          Checking fit…
        </p>
      )}
      {note !== null && (
        <p role="alert" className="error">
          {note}
        </p>
      )}
      {error !== undefined && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
      <ol className="layout-rows" aria-label="Rows">
        {rows.map((row, index) => {
          const i = index + 1;
          const isSelected = selection?.row === i;
          return (
            <li key={i} className="layout-card" data-selected={isSelected || undefined}>
              <div className="arrows">
                <button
                  type="button"
                  aria-label={`Move row ${i} up`}
                  disabled={busy || i === 1}
                  onClick={() => moveRow(i, -1)}
                >
                  ↑
                </button>
                <button
                  type="button"
                  aria-label={`Move row ${i} down`}
                  disabled={busy || i === rows.length}
                  onClick={() => moveRow(i, 1)}
                >
                  ↓
                </button>
              </div>
              <div className="card-body">
                <button type="button" className="caption" disabled={busy} onClick={() => select(i)}>
                  {caption(rows, i, isSelected)}
                </button>
                <div className="boxes">
                  {row.map((slot, k) => {
                    const j = k + 1;
                    return (
                      <button
                        key={slot.widget}
                        type="button"
                        className="box"
                        style={{ flexGrow: slot.share }}
                        aria-pressed={isSelected ? selection.column === j : undefined}
                        disabled={busy}
                        onClick={() => select(i, isSelected ? j : 1)}
                      >
                        <span>{label(slot.widget)}</span> <span className="share">{shareText(row, j)}</span>
                      </button>
                    );
                  })}
                </div>
                {isSelected && cardButtons(i, selection.column)}
              </div>
            </li>
          );
        })}
      </ol>
      <footer className="layout-foot">
        <button type="button" disabled={busy || spare.length === 0} onClick={() => toggle("add_row")}>
          Add row
        </button>
        <button type="button" className="bare" disabled={busy} onClick={() => run(reset(entry), null)}>
          Reset to the look's default
        </button>
      </footer>
      {picker === "add_row" && (
        <PickerMenu
          heading="Add a widget"
          options={unusedOptions((w) => addRow(rows, w))}
          disabled={busy}
          onPick={(edit) => pick(edit, selection)}
        />
      )}
    </section>
  );
}
