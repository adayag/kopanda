import type { RequestHandler } from "express";

/** `127.0.0.0/8`, `::1`, and `127.0.0.0/8` mapped into IPv6, as a dual-stack socket reports an IPv4 peer. */
const LOOPBACK = /^(?:::ffff:)?127\.\d{1,3}\.\d{1,3}\.\d{1,3}$|^::1$/i;

/** True for a loopback address. */
export function isLoopback(address: string | undefined): boolean {
  return address !== undefined && LOOPBACK.test(address);
}

/** The GETs another machine may make: the health check, the push profiles, a profile's manifest and its files. */
const LAN_GETS = [
  /^\/api\/health$/,
  /^\/api\/push\/profiles$/,
  /^\/api\/push\/[a-z0-9-]+\/manifest$/,
  /^\/api\/push\/[a-z0-9-]+\/files\/[0-9a-f]{64}\/.+$/,
];

/**
 * Answers 403 to a request from another machine unless it is one of the GETs the device needs. Mounted before
 * everything else in the app, so the UI's static files are loopback-only too.
 */
export const lanGuard: RequestHandler = (req, res, next) => {
  if (isLoopback(req.socket.remoteAddress) || (req.method === "GET" && LAN_GETS.some((route) => route.test(req.path)))) {
    next();
    return;
  }
  res.status(403).json({ error: "only the push routes are served to other machines" });
};
