import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import seed from "./default-profiles.json" with { type: "json" };

const ID_PATTERN = /^[a-z0-9-]+$/;

/** One profile directory's `profile.json`. Its id is the directory's name. */
const profileFileSchema = z.object({
  name: z.string().min(1),
  device: z.string().min(1),
  width: z.number().int().positive(),
  height: z.number().int().positive(),
  dpi: z.number().int().positive(),
  color: z.boolean(),
});

export type ProfileFile = z.infer<typeof profileFileSchema>;

export interface Profile extends ProfileFile {
  id: string;
  /** Whether `settings/kopanda/settings.lua` exists; without it every key is at its default. */
  has_settings: boolean;
}

export interface InvalidProfile {
  id: string;
  error: string;
}

export interface ProfileWithPath extends Profile {
  /** The absolute path of the settings file the plugin reads under this profile as KO_HOME. */
  settings_path: string;
}

export interface ProfileListing {
  /** The profiles directory, absolute. */
  dir: string;
  /** Sorted by id. */
  profiles: (Profile | InvalidProfile)[];
}

const seedProfiles: Record<string, ProfileFile> = seed;

function settingsPath(dir: string, id: string): string {
  return path.join(dir, id, "settings", "kopanda", "settings.lua");
}

function errorCode(err: unknown): unknown {
  return typeof err === "object" && err !== null ? (err as { code?: unknown }).code : undefined;
}

async function isFile(file: string): Promise<boolean> {
  try {
    return (await fs.stat(file)).isFile();
  } catch {
    return false;
  }
}

/**
 * Creates the profiles directory holding the seed profiles when it does not exist. An existing
 * directory, empty or not, is left alone; a file at the path is an error naming it.
 */
export async function ensureProfilesDir(dir: string): Promise<void> {
  let stat;
  try {
    stat = await fs.stat(dir);
  } catch (err) {
    if (errorCode(err) !== "ENOENT") throw err;
  }
  if (stat) {
    if (stat.isDirectory()) return;
    throw new Error(`The profiles directory ${dir} exists and is not a directory`);
  }
  for (const [id, profile] of Object.entries(seedProfiles)) {
    await fs.mkdir(path.join(dir, id), { recursive: true });
    await fs.writeFile(path.join(dir, id, "profile.json"), `${JSON.stringify(profile, null, 2)}\n`);
  }
}

/** Reads one entry of the profiles directory; undefined when it holds no `profile.json`. */
async function readProfile(dir: string, id: string): Promise<Profile | InvalidProfile | undefined> {
  let text: string;
  try {
    text = await fs.readFile(path.join(dir, id, "profile.json"), "utf8");
  } catch (err) {
    const code = errorCode(err);
    if (code === "ENOENT" || code === "ENOTDIR") return undefined;
    return { id, error: `profile.json cannot be read: ${(err as Error).message}` };
  }
  if (!ID_PATTERN.test(id)) {
    return { id, error: `the directory name must match ${ID_PATTERN.source}` };
  }
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch (err) {
    return { id, error: `profile.json is not valid JSON: ${(err as Error).message}` };
  }
  const parsed = profileFileSchema.safeParse(json);
  if (!parsed.success) {
    const reasons = parsed.error.issues.map((issue) =>
      issue.path.length > 0 ? `${issue.path.join(".")}: ${issue.message}` : issue.message,
    );
    return { id, error: `profile.json: ${reasons.join("; ")}` };
  }
  return { id, ...parsed.data, has_settings: await isFile(settingsPath(dir, id)) };
}

/** Lists the profiles directory as it is on disk now. Hidden entries are ignored. */
export async function listProfiles(dir: string): Promise<ProfileListing> {
  const absolute = path.resolve(dir);
  const names = (await fs.readdir(absolute)).filter((name) => !name.startsWith("."));
  const read = await Promise.all(names.map((name) => readProfile(absolute, name)));
  const profiles = read
    .filter((profile) => profile !== undefined)
    .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return { dir: absolute, profiles };
}

/**
 * The listed profile with this id, plus its settings path; an invalid one as its error; undefined
 * when no listed profile has the id. The id is only compared with listed ids, never used as a path.
 */
export async function getProfile(
  dir: string,
  id: string,
): Promise<ProfileWithPath | InvalidProfile | undefined> {
  const listing = await listProfiles(dir);
  const profile = listing.profiles.find((candidate) => candidate.id === id);
  if (profile === undefined || "error" in profile) return profile;
  return { ...profile, settings_path: settingsPath(listing.dir, profile.id) };
}
