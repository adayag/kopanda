import express from "express";
import { HttpError } from "../http-error.js";
import { searchPlaces, SearchError, trim } from "../geocoding.js";

export interface GeocodeOptions {
  /** How the server reaches Open-Meteo; the global fetch by default. */
  fetch?: typeof fetch;
  /** How long a search may take; searchPlaces' 10 s by default. */
  timeoutMs?: number;
}

/**
 * The place search: `GET /?q=<query>` answers `{ candidates }` from Open-Meteo, 400 for a query
 * that is empty once trimmed and 502 for a search that fails. The server binds to loopback only,
 * so this is no open proxy.
 */
export function geocodeRouter(options: GeocodeOptions = {}): express.Router {
  const router = express.Router();

  router.get("/", async (req, res) => {
    const { q } = req.query;
    if (typeof q !== "string" || trim(q) === "") throw new HttpError(400, "the query is empty");
    try {
      res.json({ candidates: await searchPlaces(q, options.fetch, options.timeoutMs) });
    } catch (err) {
      if (err instanceof SearchError) throw new HttpError(502, err.message, { cause: err });
      throw err;
    }
  });

  return router;
}
