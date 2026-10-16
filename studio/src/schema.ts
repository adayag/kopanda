import { z } from "zod";
import schemaJson from "./schema.json" with { type: "json" };

// The shape of kopanda.koplugin/schema.lua as bin/schema-json prints it. Objects are strict, so a
// field or key type schema.lua gains fails the parse until this file declares it. Values are typed
// by shape only; the plugin's validators (kopanda.koplugin/settings.lua) hold their ranges and rules.

const common = { id: z.string(), label: z.string(), group: z.string() };

const Slot = z.strictObject({ widget: z.string(), share: z.number() });

const Target = z.strictObject({ kind: z.enum(["kopanda", "koreader"]), target: z.string() });
const Plugin = z.strictObject({
  kind: z.literal("plugin"),
  plugin: z.string(),
  action: z.string(),
  label: z.string(),
  icon: z.string(),
});
const Action = z.strictObject({
  kind: z.literal("action"),
  action: z.string(),
  label: z.string(),
  icon: z.string(),
});
const Directory = z.strictObject({ kind: z.literal("directory"), path: z.string(), label: z.string() });
const FolderEntry = z.union([Target, Plugin, Action, Directory]);
const Folder = z.strictObject({
  kind: z.literal("folder"),
  label: z.string(),
  entries: z.array(FolderEntry),
});
// The launcher entry kinds and their fields, kopanda.koplugin/settings.lua:84-91.
const LauncherEntry = z.union([FolderEntry, Folder]);

const Key = z.discriminatedUnion("type", [
  z.strictObject({
    ...common,
    type: z.literal("choice"),
    choices: z.array(z.strictObject({ value: z.string(), label: z.string() })),
    default: z.string(),
  }),
  z.strictObject({
    ...common,
    type: z.literal("rows"),
    widgets: z.array(z.string()),
    max_columns: z.number(),
    default: z.array(z.array(Slot)),
  }),
  z.strictObject({
    ...common,
    type: z.literal("location"),
    default: z.strictObject({ name: z.string(), latitude: z.number(), longitude: z.number() }),
  }),
  z.strictObject({ ...common, type: z.literal("boolean"), default: z.boolean() }),
  z.strictObject({
    ...common,
    type: z.literal("path"),
    default: z.union([z.literal(false), z.string()]),
  }),
  z.strictObject({
    ...common,
    type: z.literal("launcher"),
    max_entries: z.number(),
    targets: z.strictObject({ kopanda: z.array(z.string()), koreader: z.array(z.string()) }),
    default: z.array(LauncherEntry),
  }),
]);

export const Schema = z.strictObject({ version: z.number(), keys: z.array(Key) });
export type Schema = z.infer<typeof Schema>;
export type Key = z.infer<typeof Key>;

/** The checked-in studio/src/schema.json; `npm run schema` regenerates it. */
export const schema: Schema = Schema.parse(schemaJson);
