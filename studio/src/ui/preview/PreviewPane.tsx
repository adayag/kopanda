import { useId, useMemo, useState } from "react";
import { schema } from "../../schema";
import type { ProfileWithPath } from "../../server/profiles.js";
import { usePreviewFrames, type Frame } from "./usePreviewFrames";

const lookKey = schema.keys.find((key) => key.id === "look");
/** The schema's looks, in its order. */
const LOOKS = lookKey?.type === "choice" ? lookKey.choices : [];

function lookLabel(look: string): string {
  return LOOKS.find((choice) => choice.value === look)?.label ?? look;
}

/**
 * The profile's home as the emulator renders it, beside the form: the profile's look, or every look,
 * day or night, rendered again after each landed write. `revision` counts the writes the screen has
 * landed. Mount it keyed by the profile.
 */
export function PreviewPane({ profile, look, revision }: { profile: ProfileWithPath; look: string; revision: number }) {
  const [allLooks, setAllLooks] = useState(false);
  const [night, setNight] = useState(false);
  const shown = useMemo(
    () => (allLooks ? LOOKS.map((choice) => choice.value) : [look]).map((value) => ({ look: value, night })),
    [allLooks, look, night],
  );
  const { frames, rerender } = usePreviewFrames(profile.id, shown, revision);

  return (
    <section className="preview" aria-label="Preview">
      <header className="preview-head">
        <p className="preview-name">{profile.name}</p>
        <p className="muted">{`${profile.device} · ${profile.width}×${profile.height}`}</p>
        <div className="preview-controls">
          <label className="toggle">
            <input type="checkbox" checked={allLooks} onChange={(e) => setAllLooks(e.target.checked)} />
            All looks
          </label>
          <label className="toggle">
            <input type="checkbox" checked={night} onChange={(e) => setNight(e.target.checked)} />
            Night
          </label>
          <button type="button" disabled={frames.some((frame) => frame.status === "rendering")} onClick={rerender}>
            Re-render
          </button>
        </div>
      </header>
      <div className="preview-frames">
        {shown.map((id, i) => (
          <PreviewFrame
            key={id.look}
            name={`${lookLabel(id.look)}${id.night ? " · night" : ""}`}
            frame={frames[i]!}
            aspectRatio={`${profile.width} / ${profile.height}`}
          />
        ))}
      </div>
    </section>
  );
}

function PreviewFrame({ name, frame, aspectRatio }: { name: string; frame: Frame; aspectRatio: string }) {
  const captionId = useId();
  return (
    <figure className="preview-frame" aria-labelledby={captionId}>
      <div className="preview-image" style={{ aspectRatio }}>
        {frame.image !== null && (
          <img src={frame.image} alt={name} className={frame.status === "rendering" ? "dimmed" : undefined} />
        )}
        {frame.stale && <span className="stale">stale</span>}
      </div>
      <figcaption id={captionId}>{name}</figcaption>
      <FrameStatus frame={frame} />
    </figure>
  );
}

function FrameStatus({ frame }: { frame: Frame }) {
  switch (frame.status) {
    case "rendering":
      return <p className="preview-status">Rendering in the emulator…</p>;
    case "waiting":
      return <p className="preview-status">Settings changed · re-rendering in 1.5 s</p>;
    case "failed":
      return (
        <div className="preview-failure">
          <p>{frame.error}</p>
          <p>{frame.image !== null ? "Showing the last good render." : "No earlier render to show."}</p>
          {frame.log.length > 0 && <pre>{frame.log.join("\n")}</pre>}
        </div>
      );
    case "idle":
      return frame.elapsed === null ? null : (
        <p className="preview-status">{`Rendered in ${frame.elapsed.toFixed(1)} s`}</p>
      );
  }
}
