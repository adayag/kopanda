import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

/**
 * The repo's bin/preview. src/server/preview.ts and dist/server/preview.js both sit three levels
 * below the repo's root.
 */
export const DEFAULT_PREVIEW = path.resolve(import.meta.dirname, "../../..", "bin/preview");

/** How long a render may take before its process group is killed. */
const DEFAULT_TIMEOUT_MS = 150000;
/** How long a timed-out render's group has after SIGTERM before SIGKILL. */
const KILL_GRACE_MS = 5000;
/** How many of stderr's lines after the first a failure keeps. */
const LOG_LINES = 40;

export interface PreviewRequest {
  /** The script to run; the repo's bin/preview by default. */
  command?: string;
  width: number;
  height: number;
  dpi: number;
  color: boolean;
  look: string;
  night: boolean;
  /** The profile's settings file, when it has one; the script renders every key at its default without it. */
  settingsPath?: string;
  timeoutMs?: number;
}

/** A render that gave no image: the status to answer, what went wrong, and the log lines after it. */
export class PreviewError extends Error {
  readonly status: number;
  readonly error: string;
  readonly log: string[];

  constructor(status: number, error: string, log: string[] = []) {
    super(error);
    this.name = "PreviewError";
    this.status = status;
    this.error = error;
    this.log = log;
  }
}

function nonEmptyLines(text: string): string[] {
  return text.split("\n").filter((line) => line.trim() !== "");
}

/** stderr's first non-empty line, else `fallback`, and the last 40 non-empty lines after it. */
function failure(status: number, stderr: string, fallback: string): PreviewError {
  const [first, ...rest] = nonEmptyLines(stderr);
  return new PreviewError(status, first ?? fallback, rest.slice(-LOG_LINES));
}

/** Runs the command to its end, killing its process group past `timeoutMs`. */
function run(command: string, args: string[], timeoutMs: number): Promise<{ stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    let timedOut = false;
    const child = spawn(command, args, { detached: true, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8").on("data", (chunk: string) => (stdout += chunk));
    child.stderr.setEncoding("utf8").on("data", (chunk: string) => (stderr += chunk));

    const killGroup = (signal: NodeJS.Signals) => {
      if (child.pid === undefined) return;
      try {
        process.kill(-child.pid, signal);
      } catch {
        // The group has already gone.
      }
    };
    const timer = setTimeout(() => {
      timedOut = true;
      killGroup("SIGTERM");
      setTimeout(() => killGroup("SIGKILL"), KILL_GRACE_MS).unref();
    }, timeoutMs);

    child.on("error", (err) => {
      clearTimeout(timer);
      reject(new PreviewError(502, `bin/preview could not run: ${err.message}`));
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (timedOut) {
        reject(new PreviewError(502, `No render within ${timeoutMs / 1000} s`));
      } else if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        const fallback = code === null ? "bin/preview was stopped" : `bin/preview exited ${code}`;
        reject(failure(code === 2 ? 503 : 502, stderr, fallback));
      }
    });
  });
}

/**
 * Renders one frame with bin/preview into a temporary directory and answers the PNG's bytes, or
 * rejects with a PreviewError. The temporary directory is removed in every case.
 */
export async function renderPreview(request: PreviewRequest): Promise<Buffer> {
  const { width, height, dpi, color, look, night, settingsPath } = request;
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "kopanda-preview-"));
  const png = path.join(dir, "preview.png");
  const args = [String(width), String(height), String(dpi), color ? "color" : "grey", look, night ? "night" : "day", png];
  if (settingsPath !== undefined) args.push(settingsPath);
  try {
    const { stdout, stderr } = await run(request.command ?? DEFAULT_PREVIEW, args, request.timeoutMs ?? DEFAULT_TIMEOUT_MS);
    try {
      JSON.parse(stdout);
    } catch (err) {
      const log = nonEmptyLines(stderr).slice(-LOG_LINES);
      throw new PreviewError(502, `bin/preview's answer is not JSON: ${(err as Error).message}`, log);
    }
    try {
      return await fs.readFile(png);
    } catch (err) {
      throw new PreviewError(502, `bin/preview wrote no PNG: ${(err as Error).message}`);
    }
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}

export interface PreviewQueue {
  /**
   * Runs `job` once every job before it has ended. A job whose `signal` aborts while it waits is
   * dropped and rejects with an abort error; one that has started runs to its end.
   */
  run<T>(job: () => Promise<T>, signal?: AbortSignal): Promise<T>;
}

/** A queue running one job at a time, in arrival order. */
export function createPreviewQueue(): PreviewQueue {
  const waiting: (() => void)[] = [];
  let running = false;

  const next = () => {
    const start = waiting.shift();
    if (start) start();
    else running = false;
  };

  return {
    run<T>(job: () => Promise<T>, signal?: AbortSignal): Promise<T> {
      return new Promise<T>((resolve, reject) => {
        const abort = () => reject(new Error("The render was dropped while it waited", { cause: signal?.reason }));
        if (signal?.aborted) {
          abort();
          return;
        }
        const onAbort = () => {
          const index = waiting.indexOf(start);
          if (index === -1) return;
          waiting.splice(index, 1);
          abort();
        };
        const start = () => {
          signal?.removeEventListener("abort", onAbort);
          running = true;
          Promise.resolve().then(job).then(resolve, reject).finally(next);
        };
        signal?.addEventListener("abort", onAbort, { once: true });
        if (running) waiting.push(start);
        else start();
      });
    },
  };
}
