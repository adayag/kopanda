import { useEffect, useState, useSyncExternalStore } from "react";
import { fetchPreview, PreviewError } from "../api";

/** How long after the last landed write the shown frames render. */
export const PAUSE_MS = 1500;

/** One frame of the preview: a look, day or night. */
export interface FrameId {
  look: string;
  night: boolean;
}

export type FrameStatus = "idle" | "waiting" | "rendering" | "failed";

/** What the pane shows of one frame. */
export interface Frame {
  /** The blob URL of the last good render, null before one. */
  image: string | null;
  /** Whether the image predates the last landed write. */
  stale: boolean;
  status: FrameStatus;
  /** The last render's failure, null once a render succeeds. */
  error: string | null;
  log: string[];
  /** Seconds from the last good render's request to its image. */
  elapsed: number | null;
}

const EMPTY: Frame = { image: null, stale: false, status: "idle", error: null, log: [], elapsed: null };

interface FrameRecord {
  image: string | null;
  /** The revision the image's request started at. */
  imageRevision: number;
  error: string | null;
  log: string[];
  elapsed: number | null;
  /** The revision the last request started at; -1 before one. */
  requested: number;
  /** The render in flight. */
  controller: AbortController | null;
  /** Render again when the one in flight ends: the pause ended while it ran on older settings. */
  again: boolean;
}

function keyOf({ look, night }: FrameId): string {
  return `${look}:${night ? "night" : "day"}`;
}

/**
 * The frames of one profile's preview, outside React: each frame's last good image, what it is
 * rendering and the pause after a landed write. Renders run when a write lands, when the pause ends,
 * when a frame is shown, and on `rerender`; a failure renders again only on one of those, never by
 * itself.
 */
class FrameStore {
  private readonly records = new Map<string, FrameRecord>();
  private readonly listeners = new Set<() => void>();
  private shown: readonly FrameId[] = [];
  private revision = 0;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private snapshot: ReadonlyMap<string, Frame> = new Map();

  constructor(private readonly id: string) {}

  readonly subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  readonly getSnapshot = (): ReadonlyMap<string, Frame> => this.snapshot;

  /**
   * Takes the screen's count of landed writes and the frames it shows. A new write restarts the pause
   * and renders each shown frame that has no image and no request since; a frame newly shown renders
   * when it is stale, has never been asked for since the last write, or failed.
   */
  sync(revision: number, shown: readonly FrameId[]): void {
    const wrote = revision > this.revision;
    if (wrote) {
      this.revision = revision;
      if (this.timer !== null) clearTimeout(this.timer);
      this.timer = setTimeout(() => this.pauseEnded(), PAUSE_MS);
    }
    const before = new Set(this.shown.map(keyOf));
    this.shown = shown;
    for (const frame of shown) {
      const record = this.record(frame);
      if (record.controller !== null) continue;
      const newlyShown = !before.has(keyOf(frame));
      if (this.unrequested(record) || (newlyShown && (this.stale(record) || record.error !== null))) {
        this.render(frame);
      }
    }
    this.publish();
  }

  /** Renders every shown frame that isn't rendering now. */
  readonly rerender = (): void => {
    for (const frame of this.shown) {
      if (this.record(frame).controller === null) this.render(frame);
    }
    this.publish();
  };

  /** Aborts every render, clears the pause and revokes every image: the frames start empty after. */
  stop(): void {
    if (this.timer !== null) clearTimeout(this.timer);
    this.timer = null;
    for (const record of this.records.values()) {
      record.controller?.abort();
      if (record.image !== null) URL.revokeObjectURL(record.image);
    }
    this.records.clear();
    this.shown = [];
    this.revision = 0;
    this.publish();
  }

  private pauseEnded(): void {
    this.timer = null;
    for (const frame of this.shown) {
      const record = this.record(frame);
      if (record.controller !== null) record.again = record.requested < this.revision;
      else if (this.stale(record) || this.unrequested(record)) this.render(frame);
    }
    this.publish();
  }

  private render(frame: FrameId): void {
    const record = this.record(frame);
    const controller = new AbortController();
    const revision = this.revision;
    record.controller = controller;
    record.requested = revision;
    record.again = false;
    const started = performance.now();
    void fetchPreview(this.id, frame, controller.signal)
      .then(
        (blob) => {
          if (controller.signal.aborted) return;
          if (record.image !== null) URL.revokeObjectURL(record.image);
          record.image = URL.createObjectURL(blob);
          record.imageRevision = revision;
          record.error = null;
          record.log = [];
          record.elapsed = (performance.now() - started) / 1000;
        },
        (err: unknown) => {
          if (controller.signal.aborted) return;
          record.error = err instanceof PreviewError ? err.error : err instanceof Error ? err.message : String(err);
          record.log = err instanceof PreviewError ? err.log : [];
        },
      )
      .then(() => {
        if (controller.signal.aborted) return;
        record.controller = null;
        this.ended(frame, record);
        this.publish();
      });
  }

  /** A render that ended waits for a pause still running; else it renders again if it ran on older settings. */
  private ended(frame: FrameId, record: FrameRecord): void {
    const again = record.again;
    record.again = false;
    if (this.timer !== null || !this.shown.some((shown) => keyOf(shown) === keyOf(frame))) return;
    if (again || this.unrequested(record)) this.render(frame);
  }

  private stale(record: FrameRecord): boolean {
    return record.image !== null && record.imageRevision < this.revision;
  }

  private unrequested(record: FrameRecord): boolean {
    return record.image === null && record.requested < this.revision;
  }

  private record(frame: FrameId): FrameRecord {
    const key = keyOf(frame);
    let record = this.records.get(key);
    if (record === undefined) {
      record = {
        image: null,
        imageRevision: 0,
        error: null,
        log: [],
        elapsed: null,
        requested: -1,
        controller: null,
        again: false,
      };
      this.records.set(key, record);
    }
    return record;
  }

  private view(record: FrameRecord): Frame {
    const stale = this.stale(record);
    const status: FrameStatus =
      record.controller !== null
        ? "rendering"
        : stale && this.timer !== null
          ? "waiting"
          : record.error !== null
            ? "failed"
            : "idle";
    const { image, error, log, elapsed } = record;
    return { image, stale, status, error, log, elapsed };
  }

  private publish(): void {
    this.snapshot = new Map([...this.records].map(([key, record]) => [key, this.view(record)]));
    for (const listener of this.listeners) listener();
  }
}

/**
 * The shown frames of the profile's preview, in order, and `rerender`. `revision` counts the writes the
 * profile screen has landed; `shown` must keep its identity while its frames don't change. Mount it
 * keyed by the profile: every render is aborted and every image revoked on unmount.
 */
export function usePreviewFrames(
  id: string,
  shown: readonly FrameId[],
  revision: number,
): { frames: Frame[]; rerender: () => void } {
  const [store] = useState(() => new FrameStore(id));
  const snapshot = useSyncExternalStore(store.subscribe, store.getSnapshot);

  useEffect(() => () => store.stop(), [store]);

  useEffect(() => {
    store.sync(revision, shown);
  }, [store, revision, shown]);

  return { frames: shown.map((frame) => snapshot.get(keyOf(frame)) ?? EMPTY), rerender: store.rerender };
}
