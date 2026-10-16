import { z } from "zod";
import catalogJson from "./catalog.json" with { type: "json" };

// The shape of studio/src/catalog.json as bin/catalog-json prints it: what the launcher editor
// offers from the pinned KOReader build and the plugin's own tables. Objects are strict, so a field
// the dump gains fails the parse until this file declares it.

const Action = z.strictObject({ id: z.string(), title: z.string() });

// One of the action tree's file-browser sections, its actions in tree order.
const Section = z.strictObject({ title: z.string(), actions: z.array(Action) });

const Plugin = z.strictObject({ name: z.string(), label: z.string() });

// An icon registry entry, svg the text of its file under kopanda.koplugin/icons/.
const Icon = z.strictObject({ id: z.string(), label: z.string(), svg: z.string() });

const Screen = z.strictObject({ label: z.string(), icon: z.string() });

export const Catalog = z.strictObject({
  actions: z.array(Section),
  plugins: z.array(Plugin),
  icons: z.array(Icon),
  // By target, the KoPanda and KOReader screen tables of kopanda.koplugin/launcher_entries.lua.
  screens: z.strictObject({
    kopanda: z.record(z.string(), Screen),
    koreader: z.record(z.string(), Screen),
  }),
});
export type Catalog = z.infer<typeof Catalog>;

/** The checked-in studio/src/catalog.json; `npm run catalog` regenerates it. */
export const catalog: Catalog = Catalog.parse(catalogJson);
