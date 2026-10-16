import { spawn } from "node:child_process";
import path from "node:path";

/**
 * The repo's bin/layout-fit. src/server/layout-fit.ts and dist/server/layout-fit.js both sit
 * three levels below the repo's root.
 */
export const DEFAULT_LAYOUT_FIT = path.resolve(import.meta.dirname, "../../..", "bin/layout-fit");

export interface FitRequest {
  /** The script to run; the repo's bin/layout-fit by default. */
  command?: string;
  width: number;
  height: number;
  dpi: number;
  /** The profile's settings file; the script reads every key at its default when it is absent. */
  settingsPath: string;
  /** The current row lists and the proposed ones, as stored; the script validates them. */
  current: unknown;
  proposed: unknown;
  timeoutMs?: number;
}

export type FitResult =
  | { checked: true; current: number; proposed: number }
  | { checked: false; reason: string };

/** The answer's two counts, or undefined when stdout isn't bin/layout-fit's JSON for two lists. */
function counts(stdout: string): [number, number] | undefined {
  let answer: unknown;
  try {
    answer = JSON.parse(stdout);
  } catch {
    return undefined;
  }
  const overflow = (answer as { overflow?: unknown } | null)?.overflow;
  if (!Array.isArray(overflow) || overflow.length !== 2) return undefined;
  const [current, proposed] = overflow as unknown[];
  if (!Number.isInteger(current) || !Number.isInteger(proposed)) return undefined;
  return [current as number, proposed as number];
}

/**
 * The line of stderr that says why the script failed: its own last message (KOReader's
 * library-loading chatter comes first), else the last non-empty line.
 */
function failureLine(stderr: string): string {
  const lines = stderr.split("\n").filter((line) => line.trim() !== "");
  return lines.filter((line) => line.startsWith("bin/layout-fit:")).at(-1) ?? lines.at(-1) ?? "";
}

/**
 * Runs bin/layout-fit once for the profile's screen and settings file with the current and the
 * proposed row lists, and answers how many rows of each the home leaves out. Any failure to
 * check answers unchecked with its reason. The process runs in its own group, so a timeout kills
 * the script's luajit with it.
 */
export function checkFit(request: FitRequest): Promise<FitResult> {
  const { width, height, dpi, settingsPath, current, proposed } = request;
  const command = request.command ?? DEFAULT_LAYOUT_FIT;
  const timeoutMs = request.timeoutMs ?? 30000;
  return new Promise((resolve) => {
    let settled = false;
    const finish = (result: FitResult) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(result);
    };

    const child = spawn(command, [String(width), String(height), String(dpi), settingsPath], {
      detached: true,
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8").on("data", (chunk: string) => (stdout += chunk));
    child.stderr.setEncoding("utf8").on("data", (chunk: string) => (stderr += chunk));

    const timer = setTimeout(() => {
      if (child.pid !== undefined) {
        try {
          process.kill(-child.pid, "SIGTERM");
        } catch {
          // The group has already gone.
        }
      }
      finish({ checked: false, reason: `bin/layout-fit gave no answer within ${timeoutMs} ms` });
    }, timeoutMs);

    child.on("error", (err) => {
      finish({ checked: false, reason: `bin/layout-fit could not run: ${err.message}` });
    });
    child.on("close", (code, signal) => {
      if (code === 2) {
        finish({ checked: false, reason: `no emulator: ${stderr.split("\n")[0] ?? ""}` });
      } else if (code !== 0) {
        const how = code === null ? `was stopped by ${signal}` : `exited ${code}`;
        finish({ checked: false, reason: `bin/layout-fit ${how}: ${failureLine(stderr)}` });
      } else {
        const answer = counts(stdout);
        if (answer) {
          finish({ checked: true, current: answer[0], proposed: answer[1] });
        } else {
          finish({
            checked: false,
            reason: `bin/layout-fit answered something unreadable: ${stdout.trim().slice(0, 200)}`,
          });
        }
      }
    });

    // A script that exits before reading stdin closes the pipe; the exit says why, not the write.
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify([current, proposed]));
  });
}
