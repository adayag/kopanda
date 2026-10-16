import { useCallback, useEffect, useRef, useState } from "react";
import type { Health } from "../server/app.js";
import { fetchHealth, fetchManifest } from "./api";

type Answer<T> = { status: "loading" } | { status: "loaded"; value: T } | { status: "failed"; message: string };

function failed(err: unknown): { status: "failed"; message: string } {
  return { status: "failed", message: err instanceof Error ? err.message : String(err) };
}

/**
 * Where the Kindle pulls this profile from: the studio's LAN addresses (or that the LAN is off) and
 * the profile's bundle hash as the manifest route answers it now, with Refresh asking again.
 */
export function PushStatus({ id }: { id: string }) {
  const [health, setHealth] = useState<Answer<Health>>({ status: "loading" });
  const [hash, setHash] = useState<Answer<string>>({ status: "loading" });
  /** The manifest request in flight, cancelled when another replaces it or the screen goes. */
  const manifestRequest = useRef<AbortController | undefined>(undefined);

  /** Asks for the manifest, cancelling the request before it; only the last request's answer is shown. */
  const requestManifest = useCallback(() => {
    manifestRequest.current?.abort();
    const controller = new AbortController();
    manifestRequest.current = controller;
    fetchManifest(id, controller.signal).then(
      (manifest) => {
        if (!controller.signal.aborted) setHash({ status: "loaded", value: manifest.hash });
      },
      (err: unknown) => {
        if (!controller.signal.aborted) setHash(failed(err));
      },
    );
  }, [id]);

  useEffect(() => {
    const controller = new AbortController();
    fetchHealth(controller.signal).then(
      (value) => {
        if (!controller.signal.aborted) setHealth({ status: "loaded", value });
      },
      (err: unknown) => {
        if (!controller.signal.aborted) setHealth(failed(err));
      },
    );
    requestManifest();
    return () => {
      controller.abort();
      manifestRequest.current?.abort();
    };
  }, [requestManifest]);

  function refresh(): void {
    setHash({ status: "loading" });
    requestManifest();
  }

  return (
    <section className="push" aria-label="Push">
      {health.status === "loaded" &&
        (health.value.addresses.length > 0 ? (
          health.value.addresses.map((address) => (
            <p key={address}>
              Pull from the Kindle at <code>{`${address}:${health.value.port}`}</code>
            </p>
          ))
        ) : (
          <p className="note">LAN off · start the studio with KOPANDA_STUDIO_HOST=0.0.0.0 to pull from the Kindle</p>
        ))}
      {health.status === "failed" && <p className="error">{health.message}</p>}
      <p>
        Bundle{" "}
        {hash.status === "loaded" && <code>{hash.value.slice(0, 12)}</code>}
        {hash.status === "loading" && <span className="muted">…</span>}
        {hash.status === "failed" && <span className="error">{hash.message}</span>}{" "}
        <button type="button" onClick={refresh}>
          Refresh
        </button>
      </p>
    </section>
  );
}
