import { catalog } from "../../catalog";

const icons = new Map(catalog.icons.map((icon) => [icon.id, icon]));

/**
 * The catalog icon with this id on a light tile, since the plugin's icons are inked black
 * (kopanda.koplugin/icons.lua:1-8); an id the catalog lacks shows as the id. The SVG goes through an
 * <img> from a data URL, so nothing in the file runs in the page.
 */
export function IconTile({ id }: { id: string }) {
  const icon = icons.get(id);
  return (
    <span className="icon-tile">
      {icon ? <img src={`data:image/svg+xml,${encodeURIComponent(icon.svg)}`} alt="" /> : <code>{id}</code>}
    </span>
  );
}

/** Every catalog icon on its tile with its label, the current one marked; a click picks one. */
export function IconPicker({
  current,
  disabled,
  onPick,
}: {
  current: string;
  disabled: boolean;
  onPick: (id: string) => void;
}) {
  return (
    <div role="group" aria-label="Icon" className="icon-picker">
      {catalog.icons.map((icon) => (
        <button
          key={icon.id}
          type="button"
          className="icon-choice"
          aria-pressed={icon.id === current}
          disabled={disabled}
          onClick={() => onPick(icon.id)}
        >
          <IconTile id={icon.id} />
          <span>{icon.label}</span>
        </button>
      ))}
    </div>
  );
}
