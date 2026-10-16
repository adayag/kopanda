import { useId, useState } from "react";
import { catalog } from "../../catalog";
import { trim, type Entry } from "../../core/entries-edit";
import { schema, type Key } from "../../schema";
import { IconPicker, IconTile } from "./icons";

const launcher = schema.keys.find((key): key is Extract<Key, { type: "launcher" }> => key.type === "launcher")!;

// The kinds, in the order the device's add screen offers them, with its labels
// (kopanda.koplugin/entry_picker.lua's KINDS).
const KINDS = [
  { kind: "kopanda", label: "KoPanda screen" },
  { kind: "koreader", label: "KOReader screen" },
  { kind: "directory", label: "Folder on disk" },
  { kind: "action", label: "Action" },
  { kind: "plugin", label: "Plugin" },
] as const;

type Picked =
  | { kind: "directory"; path: string }
  | { kind: "action"; action: string }
  | { kind: "plugin"; plugin: string; action: string };

type Step =
  | { step: "kinds" }
  | { step: "screen"; kind: "kopanda" | "koreader" }
  | { step: "path"; typed: string; note: string | null }
  | { step: "plugin" }
  | { step: "action"; plugin?: string }
  | { step: "finish"; picked: Picked; label: string; icon: string };

const KINDS_STEP: Step = { step: "kinds" };

/**
 * The typed path's note when it can't be a folder on disk, else the path with any trailing / removed
 * (kopanda.koplugin/entry_picker.lua's directory picker; the device's chooser gives no relative path).
 */
function checkPath(typed: string): { note: string } | { path: string } {
  if (!typed.startsWith("/")) return { note: "Type a folder path on the device, starting with /." };
  const path = typed.replace(/\/+$/, "");
  if (path === "") return { note: "Choose a folder inside the root." };
  return { path };
}

/** The picking step's title, as the device heads its sheet: the kind, or the plugin picked. */
function stepTitle(state: Exclude<Step, { step: "kinds" | "finish" }>): string {
  if (state.step === "screen") return state.kind === "kopanda" ? "KoPanda screen" : "KOReader screen";
  if (state.step === "path") return "Folder on disk";
  if (state.step === "plugin") return "Plugin";
  return catalog.plugins.find((p) => p.name === state.plugin)?.label ?? "Action";
}

function entryOf(picked: Picked, label: string, icon: string): Entry {
  const trimmed = trim(label);
  if (picked.kind === "directory") return { kind: "directory", path: picked.path, label: trimmed };
  if (picked.kind === "action") return { kind: "action", action: picked.action, label: trimmed, icon };
  return { kind: "plugin", plugin: picked.plugin, action: picked.action, label: trimmed, icon };
}

/**
 * "Add an entry": the five kinds, then each kind's steps (the device's entry picker,
 * kopanda.koplugin/entry_picker.lua), ending in onAdd with the entry. Cancel at any step adds nothing.
 */
export function AddEntry({
  inFolder,
  disabled,
  onAdd,
}: {
  inFolder: boolean;
  disabled: boolean;
  onAdd: (entry: Entry) => Promise<boolean>;
}) {
  const captionId = useId();
  const [state, setState] = useState<Step>(KINDS_STEP);

  function add(entry: Entry) {
    void onAdd(entry).then((written) => {
      if (written) setState(KINDS_STEP);
    });
  }

  const cancel = (
    <button type="button" className="choice" onClick={() => setState(KINDS_STEP)}>
      Cancel
    </button>
  );

  function body() {
    switch (state.step) {
      case "kinds":
        return (
          <>
            <div className="choices">
              {KINDS.map(({ kind, label }) => (
                <button
                  key={kind}
                  type="button"
                  className="choice"
                  disabled={disabled}
                  onClick={() =>
                    setState(
                      kind === "directory"
                        ? { step: "path", typed: "", note: null }
                        : kind === "action"
                          ? { step: "action" }
                          : kind === "plugin"
                            ? { step: "plugin" }
                            : { step: "screen", kind },
                    )
                  }
                >
                  {label}
                </button>
              ))}
            </div>
            {!inFolder && <p className="note">The seventh entry and beyond go into a folder.</p>}
          </>
        );
      case "screen": {
        const kind = state.kind;
        return (
          <div className="choices">
            {launcher.targets[kind].map((target) => {
              const screen = catalog.screens[kind][target];
              return (
                <button key={target} type="button" className="choice pick" disabled={disabled} onClick={() => add({ kind, target })}>
                  <IconTile id={screen?.icon ?? target} />
                  {screen?.label ?? target}
                </button>
              );
            })}
            {cancel}
          </div>
        );
      }
      case "path": {
        return (
          <form
            className="pin"
            onSubmit={(e) => {
              e.preventDefault();
              const checked = checkPath(state.typed);
              if ("note" in checked) setState({ ...state, note: checked.note });
              else
                setState({
                  step: "finish",
                  picked: { kind: "directory", path: checked.path },
                  label: /[^/]+$/.exec(checked.path)![0],
                  icon: "folder",
                });
            }}
          >
            <input
              type="text"
              aria-label="Path on the device"
              placeholder="/mnt/us/books"
              value={state.typed}
              disabled={disabled}
              onChange={(e) => setState({ ...state, typed: e.target.value })}
            />
            <button type="submit" disabled={disabled}>
              Next
            </button>
            {cancel}
            {state.note !== null && <p className="note">{state.note}</p>}
          </form>
        );
      }
      case "plugin":
        return (
          <div className="choices">
            {catalog.plugins.map((plugin) => (
              <button
                key={plugin.name}
                type="button"
                className="choice"
                disabled={disabled}
                onClick={() => setState({ step: "action", plugin: plugin.name })}
              >
                {plugin.label}
              </button>
            ))}
            {cancel}
          </div>
        );
      case "action": {
        const plugin = state.plugin;
        return (
          <>
            {catalog.actions.map((section) => (
              <section key={section.title} className="action-section">
                <h3>{section.title}</h3>
                <div className="choices">
                  {section.actions.map((action) => (
                    <button
                      key={action.id}
                      type="button"
                      className="choice"
                      disabled={disabled}
                      onClick={() =>
                        setState({
                          step: "finish",
                          picked:
                            plugin === undefined
                              ? { kind: "action", action: action.id }
                              : { kind: "plugin", plugin, action: action.id },
                          label: action.title,
                          icon: "action",
                        })
                      }
                    >
                      {action.title}
                    </button>
                  ))}
                </div>
              </section>
            ))}
            {cancel}
          </>
        );
      }
      case "finish": {
        const empty = trim(state.label) === "";
        return (
          <form
            className="finish"
            onSubmit={(e) => {
              e.preventDefault();
              if (!empty) add(entryOf(state.picked, state.label, state.icon));
            }}
          >
            <label className="field">
              <span className="caption">Label</span>
              <input
                type="text"
                aria-label="Label"
                value={state.label}
                disabled={disabled}
                onChange={(e) => setState({ ...state, label: e.target.value })}
              />
            </label>
            {state.picked.kind !== "directory" && (
              <>
                <p className="caption">Icon</p>
                <IconPicker current={state.icon} disabled={disabled} onPick={(icon) => setState({ ...state, icon })} />
              </>
            )}
            <div className="choices">
              <button type="submit" className="choice" disabled={disabled || empty}>
                Add
              </button>
              {cancel}
            </div>
          </form>
        );
      }
    }
  }

  return (
    <section className="add-entry" aria-labelledby={captionId}>
      <p id={captionId} className="caption">
        Add an entry
      </p>
      {state.step !== "kinds" && state.step !== "finish" && <p className="step-title">{stepTitle(state)}</p>}
      {body()}
    </section>
  );
}
