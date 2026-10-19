# Comment plan (2026-10-19)

> **For Claude:** two parts. Part A is one Sonnet builder on a worktree off `main` and one Sonnet reviewer;
> part B is a lead edit to `AGENTS.md`. Neither changes behaviour; the gates are luacheck, `hooks_doc_spec`
> and the citation count.

**Goal:** every comment in the plugin and its specs says something the code can't, in one place, in words
that stay true; and the rule that keeps it so is written down for every agent that writes code here.

**Where the comments are now:** `kopanda.koplugin/` has 2,954 comment lines (15% of 19,325) in 924 blocks,
239 of them four lines or longer. `spec/unit/` has 2,046. They are of three kinds:

| Kind | Plugin | Specs | Verdict |
|---|---|---|---|
| KOReader `file:line` citations | 290 | 141 | keep: the upgrade map |
| Tiller and board vocabulary: decision IDs (`D15's sub-line`, `D10's count`), fact IDs (`Open fact F1`, `outcome a`), board HTML (`SeriesC.dc.html:28-40`) | 190 | 187 | strip the IDs, keep the sentence |
| Plain prose | 2,600 | 1,900 | keep one-sentence headers; cut narratives |

---

## Part A: the pass

**Files:** every `kopanda.koplugin/*.lua`, `kopanda.koplugin/widgets/*.lua`, `kopanda.koplugin/looks/*.lua`,
`spec/*.lua`, `spec/unit/*_spec.lua`, `spec/emulator/*.lua`. Not `HOOKS.md` (done), not `.tiller/`.

### The three rules, applied to every comment

1. **Keep every KOReader citation.** A `frontend/...lua:123` or `base/ffi/...lua:45-60` stays, with the
   sentence that says what the plugin reads or patches there. The count of distinct `[a-z_/]+\.lua:[0-9]+(-[0-9]+)?`
   strings is the same before and after (`grep -ohE ... | sort -u | wc -l`, per directory).
2. **Strip Tiller and board references.** `D14`, `F1`, `C5`, `(D3)`, `D15's`, `outcome a`, `Open fact`,
   `settled at the Colorsoft`, `*.dc.html:NN`, `HomeRetro.dc.html`, `.tiller/...` paths: delete the token
   and keep the sentence it was in, rewritten so it stands alone ("D15's sub-line: the author, then…" becomes
   "The sub-line: the author, then…"). A comment that is only a reference ("(D14)") goes entirely. The
   sentence must still say what the code does; if removing the ID leaves nothing, the comment goes.
3. **A block over three lines becomes the one to three sentences a reader of that code needs.** What the
   thing is, what it reads or patches in KOReader (with the citation), and the one non-obvious why. The
   rest goes: how an alternative lost, what was measured on which device, what another look does, what the
   board drew. Module headers may run to five lines when the module patches KOReader.

### What a good comment looks like here

A module header, `looks.lua`:

```lua
-- The looks: their token tables by id, the active one from the look setting, and the palette
-- variant to draw with. Adding a look is its id here, its token file looks/<id>.lua and its
-- choice of the look setting in schema.lua.
```

A function header, `shelf_rows.lua`:

```lua
-- The sub-line: the author, " and others" when another first author is in the series, then
-- "next: <title>" while under way with a next unread, else the series' book count.
local function sub_line(entry)
```

A citation, `looks.lua`:

```lua
-- KOReader's night mode inverts everything painted (base/ffi/framebuffer.lua:476-488), so night
-- paints the night palette inverted and the panel shows it as designed.
```

### What goes

From `title_bar.lua`'s header, the second paragraph in full:

```lua
-- The down mark after each picker's label is the text " ▾" (U+25BE). Open fact F1, settled at the
-- Colorsoft: "▾" set by Typeset.line in Editorial's strong part and in Diner's display part paints
-- a down-pointing triangle 12 px wide in both looks. It differs from U+E000 (which KOReader's
-- fallback fonts turn out to cover with a glyph of their own) and from the missing-glyph box an
-- unassigned code point paints (U+0378, a 14 px outlined box), so it renders (outcome a) and no
-- icon is needed.
```

becomes one line where the mark is defined: `-- " ▾" (U+25BE): a glyph the fallback fonts have, so no icon.`

### Steps

1. Count first, per directory: comment lines (`grep -c '^\s*--'` summed), distinct citations, and the
   Tiller-vocabulary lines (`grep -cE '\b[DFC][0-9]{1,2}\b|dc\.html|outcome [a-z]\)|[Oo]pen fact'`). Put the
   three numbers in the commit message.
2. Plugin first, one file at a time, worst first: `shelf_rows`, `authors_screen`, `book_sheet`,
   `series_screen`, `shelf_order`, then the rest alphabetically. Then `spec/`, then `spec/unit/`, then
   `spec/emulator/`.
3. After each directory: `bash -c 'bin/check --lint; echo EXIT $?'`, the citation count unchanged, the
   Tiller-vocabulary count zero. `bash -c 'bin/check spec/unit/hooks_doc_spec.lua spec/unit/main_requires_spec.lua; echo EXIT $?'`
   after the plugin (`hooks_doc_spec` reads the plugin for underscore accesses HOOKS.md must name).
4. Three commits: `plugin: comments say what the code can't`, `tests: comments say what the code can't`
   (spec/, spec/unit, spec/emulator), each with the before/after counts.
5. Reviewer (Sonnet, read-only): for twenty comments sampled across the diff, old against new, is anything
   lost that a reader of that function would need; is any rewritten sentence now false; is every citation's
   sentence still true to what the plugin does there. Verdict and a fix list.

Expected: plugin comments 2,954 to about 1,800; spec comments 2,046 to about 1,300. Time: about two hours
of agent time plus a half-hour review.

## Part B: the rule, into `AGENTS.md`

Add under "### Code", after the YAGNI line:

```markdown
- Comments say what the code can't. A module opens with one to three sentences: what it is, and which
  KOReader internals it reads or patches, each with its `file:line` (HOOKS.md carries the long form).
  A function gets a comment only when its name and signature don't say what it does: one sentence,
  what and why, never how. Cite KOReader by `file:line`. Never cite Tiller decisions, facts, board
  HTML or design docs in code: the spec is the record of why, the commit message is the record of
  what lost, the code is the record of what is. No comment restates the line under it. A look file's
  comment names where a value comes from only when the value isn't the base's.
```

And in "### Before committing", after the self-review line:

```markdown
- Comments in the diff pass the rule above: a reviewer may strike any that cite a decision ID or run
  past three lines without a citation to justify them.
```

The lead makes this edit directly (`docs:` commit, `.tiller/`-free), before part A's builder starts, so the
builder's brief can point at it.
