import { useSyncExternalStore } from "react";
import { ProfileList } from "./ProfileList";
import { ProfileScreen } from "./ProfileScreen";

function subscribe(onChange: () => void): () => void {
  window.addEventListener("hashchange", onChange);
  return () => window.removeEventListener("hashchange", onChange);
}

function currentHash(): string {
  return location.hash;
}

/** The profile id that `#/profiles/<id>` names, decoded; null for any other hash. */
function profileId(hash: string): string | null {
  const segment = /^#\/profiles\/(.+)$/.exec(hash)?.[1];
  if (segment === undefined) return null;
  try {
    return decodeURIComponent(segment);
  } catch {
    return segment;
  }
}

export function App() {
  const id = profileId(useSyncExternalStore(subscribe, currentHash));
  return (
    <main className="app">
      <header className="brand">KoPanda studio</header>
      {id === null ? <ProfileList /> : <ProfileScreen key={id} id={id} />}
    </main>
  );
}
