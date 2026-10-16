import os from "node:os";
import path from "node:path";

export interface Config {
  port: number;
  /** The directory holding the device profiles. */
  profilesDir: string;
}

const DEFAULTS = {
  KOPANDA_STUDIO_PORT: "4490",
  KOPANDA_STUDIO_PROFILES_DIR: "~/.kopanda/profiles",
} as const;

type Variable = keyof typeof DEFAULTS;

/** Every environment variable loadConfig reads. */
export const CONFIG_VARIABLES = Object.keys(DEFAULTS) as Variable[];

type EnvLike = Record<string, string | undefined>;

function expandHome(value: string): string {
  if (value === "~") return os.homedir();
  if (value.startsWith("~/")) return path.join(os.homedir(), value.slice(2));
  return value;
}

function read(env: EnvLike, key: Variable): string {
  const value = env[key];
  return value === undefined || value === "" ? DEFAULTS[key] : value;
}

export function loadConfig(env: EnvLike = process.env): Config {
  const portText = read(env, "KOPANDA_STUDIO_PORT");
  const port = /^\d+$/.test(portText) ? Number(portText) : NaN;
  if (!(port >= 1 && port <= 65535)) {
    throw new Error(`KOPANDA_STUDIO_PORT must be a port number, got "${portText}"`);
  }
  return {
    port,
    profilesDir: expandHome(read(env, "KOPANDA_STUDIO_PROFILES_DIR")),
  };
}
