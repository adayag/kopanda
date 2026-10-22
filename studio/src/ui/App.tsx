import { useSyncExternalStore } from "react";
import { ProfileList } from "./ProfileList";
import { ProfileScreen, type ProfileView } from "./ProfileScreen";

function subscribe(onChange: () => void): () => void {
  window.addEventListener("hashchange", onChange);
  return () => window.removeEventListener("hashchange", onChange);
}

function currentHash(): string {
  return location.hash;
}

function decode(segment: string): string {
  try {
    return decodeURIComponent(segment);
  } catch {
    return segment;
  }
}

/**
 * The profile `#/profiles/<id>` names, its id decoded, and the view after it: `/layout`, `/layout-2`
 * and `/launcher` the editors, anything else the form. Null for any other hash.
 */
function profileRoute(hash: string): { id: string; view: ProfileView } | null {
  const match = /^#\/profiles\/([^/]+)(?:\/(.*))?$/.exec(hash);
  if (match === null) return null;
  const rest = match[2];
  const view = rest === "layout" || rest === "layout-2" || rest === "launcher" ? rest : "form";
  return { id: decode(match[1]!), view };
}

export function App() {
  const route = profileRoute(useSyncExternalStore(subscribe, currentHash));
  return (
    <main className="app">
      <header className="brand">KoPanda studio</header>
      {route === null ? <ProfileList /> : <ProfileScreen key={route.id} id={route.id} view={route.view} />}
    </main>
  );
}
