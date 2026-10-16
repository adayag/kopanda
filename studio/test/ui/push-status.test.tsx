// @vitest-environment jsdom
import { fireEvent, render, screen } from "@testing-library/react";
import { StrictMode } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PushStatus } from "../../src/ui/PushStatus";

const HASH_A = `0123456789ab${"c".repeat(52)}`;
const HASH_B = `fedcba987654${"d".repeat(52)}`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function manifest(hash: string) {
  return { format: 1, profile: "colorsoft", hash, files: [] };
}

const loopback = { ok: true, host: "127.0.0.1", port: 4490, addresses: [] };
const lan = { ok: true, host: "0.0.0.0", port: 4490, addresses: ["192.168.1.20", "10.0.0.5"] };

const fetchMock = vi.fn<typeof fetch>();

/** Answers each request by its URL from `routes`; an unrouted URL fails the test. */
function route(routes: Record<string, () => Response>): void {
  fetchMock.mockImplementation(async (input) => {
    const answer = routes[String(input)];
    if (!answer) throw new Error(`unexpected fetch ${String(input)}`);
    return answer();
  });
}

function requests(url: string): number {
  return fetchMock.mock.calls.filter(([input]) => String(input) === url).length;
}

beforeEach(() => {
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("the profile's push status", () => {
  it("shows one line per LAN address when the LAN is on", async () => {
    route({ "/api/health": () => json(lan), "/api/push/colorsoft/manifest": () => json(manifest(HASH_A)) });

    render(<PushStatus id="colorsoft" />);

    expect(await screen.findByText("192.168.1.20:4490")).toBeInTheDocument();
    expect(screen.getByText("10.0.0.5:4490")).toBeInTheDocument();
    expect(screen.getAllByText(/^Pull from the Kindle at/)).toHaveLength(2);
    expect(screen.queryByText(/LAN off/)).not.toBeInTheDocument();
  });

  it("shows the LAN off line when the studio is on loopback", async () => {
    route({ "/api/health": () => json(loopback), "/api/push/colorsoft/manifest": () => json(manifest(HASH_A)) });

    render(<PushStatus id="colorsoft" />);

    expect(
      await screen.findByText(
        "LAN off · start the studio with KOPANDA_STUDIO_HOST=0.0.0.0 to pull from the Kindle",
      ),
    ).toBeInTheDocument();
    expect(screen.queryByText(/^Pull from the Kindle at/)).not.toBeInTheDocument();
  });

  it("shows the first 12 hex of the bundle hash", async () => {
    route({ "/api/health": () => json(loopback), "/api/push/colorsoft/manifest": () => json(manifest(HASH_A)) });

    render(<PushStatus id="colorsoft" />);

    expect(await screen.findByText("0123456789ab")).toBeInTheDocument();
    expect(screen.getByText(/^Bundle/)).toHaveTextContent("Bundle 0123456789ab");
  });

  it("fetches the manifest again on Refresh and shows the new hash", async () => {
    let hash = HASH_A;
    route({ "/api/health": () => json(loopback), "/api/push/colorsoft/manifest": () => json(manifest(hash)) });
    render(<PushStatus id="colorsoft" />);
    await screen.findByText("0123456789ab");

    hash = HASH_B;
    fireEvent.click(screen.getByRole("button", { name: "Refresh" }));

    expect(await screen.findByText("fedcba987654")).toBeInTheDocument();
    expect(screen.queryByText("0123456789ab")).not.toBeInTheDocument();
    expect(requests("/api/push/colorsoft/manifest")).toBe(2);
    expect(requests("/api/health")).toBe(1);
  });

  it("shows a failed manifest fetch's error in place of the hash", async () => {
    route({
      "/api/health": () => json(loopback),
      "/api/push/colorsoft/manifest": () => json({ error: "cannot bundle plugin/a b.lua" }, 500),
    });

    render(<PushStatus id="colorsoft" />);

    expect(await screen.findByText("cannot bundle plugin/a b.lua")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Refresh" })).toBeInTheDocument();
  });

  it("asks for the profile's manifest by its encoded id", async () => {
    route({ "/api/health": () => json(loopback), "/api/push/a%20b/manifest": () => json(manifest(HASH_A)) });

    render(<PushStatus id="a b" />);

    expect(await screen.findByText("0123456789ab")).toBeInTheDocument();
  });

  it("shows no abort error when StrictMode cancels its first requests", async () => {
    route({ "/api/health": () => json(lan), "/api/push/colorsoft/manifest": () => json(manifest(HASH_A)) });

    render(
      <StrictMode>
        <PushStatus id="colorsoft" />
      </StrictMode>,
    );

    expect(await screen.findByText("0123456789ab")).toBeInTheDocument();
    expect(await screen.findByText("192.168.1.20:4490")).toBeInTheDocument();
    expect(screen.queryByText(/abort/i)).not.toBeInTheDocument();
  });
});
