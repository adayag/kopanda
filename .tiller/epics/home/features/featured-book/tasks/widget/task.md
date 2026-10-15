# Featured widget in both looks, first-run state and tap

## Approach

The widget that puts `book-data`'s record and `cover`'s box on the home, by `home-layout`'s contract
(`home-layout/feature.md` "The row engine"; `home-layout/tasks/row-engine/task.md` §3). Paths into KOReader
are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **Layout.** In `schema.lua`, add `"featured"` to `layout.rows`' `widgets` list. Insert
   `{ { widget = "featured", share = 1 } }` as the default's second row, as the feature gives it.
2. **`kopanda.koplugin/widgets/featured.lua`**, `{ id = "featured", settings_prefix = "featured",
   height, build, tap, after_show }`, registered in `widgets.lua` and required from `main.lua`.
   - **`height(width, ctx)`** is the cover box height plus `shadow.cover.y` scaled, from
     `FeaturedCover.box`.
   - **`build(width, ctx)`** calls `FeaturedBook.current()` once per build and keeps the record on the
     built widget for `tap`. It returns a `HorizontalGroup` of the cover box, the gap and the text column,
     exactly `width` wide.
   - **Text column, Editorial** (Main:37-52), a `VerticalGroup` top block and a bottom block, with the
     free height between them:
     6 px between items (Main:38):
     - `featured_label` "Continue reading", label style, `muted`;
     - `featured_title` (display 28, line height 0.1 extra, i.e. CSS 1.1; `ink`; a `TextBoxWidget` two
       lines high with `height_overflow_show_ellipsis`, `frontend/ui/widget/textboxwidget.lua:48`, `:54`,
       `:151`);
     - `featured_authors` (text 15, `text`, one line, ellipsis);
     - 14 px below the authors (6 + 8, Main:42), `featured_chapter` (text 14, `text`).

     Bottom: the bar, 8 px, then a row with the percent left-aligned and the time left right-aligned
     (`featured_caption`, text 13, `text`).
   - **Text column, Diner** (HomeRetro:32-43), padded 6 px top and bottom:
     - the chip "Now reading": a `FrameContainer` with `chip.fill_color`, `chip.outline_color` at the
       `featured.chip_outline` width (2), padding 3/10, text in `featured_label` (display 11, uppercase,
       tracking 0.1, `ink`, the role `chip.text_color` names, since a type part names a palette role);
     - 12 px (`title_gap`: 6 gap + 6 margin, HomeRetro:33, :35);
     - the title (display 28, line height 1.05, `ink`, two lines);
     - 6 px, then "authors · chapter" (`featured_authors`, text 15, `muted`, one line, ellipsis), dropping a missing
       part and its separator.

     Bottom: the bar, 8 px, then "62% · 2 h 10 min left" (`featured_caption`, `strong` 13, `ink`).
   - **Caption** from the record:
     - percent: `math.floor(percent × 100) .. "%"`, or "100%" when complete;
     - then, first that applies:
       - "Finished" (complete);
       - the time left: minutes rounded, "N min left" under an hour, "H h left" or "H h M min left";
       - "N pages left" / "1 page left" from `pages − round(percent × pages)`;
       - nothing.

     A pure `Featured.caption(record)` returns the parts, for the spec.
   - **Progress bar** from `progress`:
     - a track of `height` in `track_color`, with an outline of `outline_width` in `outline_color` when
       set;
     - a fill to `floor(inner_w × shown_percent / 100)` in `fill_color`;
     - where `fill_grey == "hatch_135"` and the variant is grey, the fill is a `FrameContainer` with
       `background` paper, `stripe_color` ink and `stripe_width` 5 scaled (the board's 7 px period;
       `hatchRect` measures `sw` along x, so across the stripe it is `sw / √2`)
       (`frontend/ui/widget/container/framecontainer.lua:48-50`, `:127-132`;
       `base/ffi/blitbuffer.lua:2209-2235`).
   - **First run** (record nil), the column centred vertically with 10 px gaps (EmptyStates:34-38):
     - the label or chip;
     - `featured_empty_title` "Nothing open yet." (display 24, line height 1.15);
     - `featured_empty_body` "Open a book from the Library and it will wait for you here." (text 15, line
       height 1.4, `text` in Editorial and `muted` in Diner);
     - 16 px above it (its 6 px margin, EmptyStates:38), the button "Open the Library" in
       `featured_button`. Editorial: `strong` 11, uppercase, tracking
       0.12, a 1 px `ink` outline, padding 9/14. Diner: `strong` 11, uppercase, a `mustard` fill, an
       `outline` at `stroke.outline` and the `shadow.tile` hard shadow.

     The button's screen rectangle is kept on the built widget.
   - **`tap(ctx)`**, wrapped in `pcall` by the caller as every tap is:
     - With a record whose file exists, it calls
       `require("apps/filemanager/filemanager").instance:openFile(file)`
       (`frontend/apps/filemanager/filemanager.lua:1616-1639`).
     - With a record whose file is gone, `ctx.home:refresh()`.
     - With no record and the tap inside the button, `Home.close()` then `fm:onHome()`
       (`filemanager.lua:865-870`).
     - With no record and the tap elsewhere, it returns false, so the home's interim rule applies.
       `home-layout`'s row engine consumes every tap in a slot whose widget has `tap`
       (`home-layout/tasks/row-engine/task.md` §5). This task changes `home.lua` so a `tap` returning
       `false` falls through to the next step, with a `home_layout_spec.lua` case.
   - **`after_show(ctx)`** calls `FeaturedCover.after_show(ctx.home, file, specs)` when there is a
     record. `home.lua` calls `after_show` on each built slot's widget that has one, from the same
     `nextTick` after the settled signal where the weather fetch runs (`home-layout/tasks/weather/task.md`
     §2). Add that loop if `home-layout` built only the weather call.
3. **Tokens.** Fill `featured_label`, `featured_title`, `featured_authors`, `featured_chapter`,
   `featured_caption`, `featured_empty_title`, `featured_empty_body` and `featured_button` in both looks,
   plus the `featured` block's `gap` (24/20), `column_padding_y` (0/6), `chip_outline` (false/2),
   `chip_padding { x, y }` (false/10, 3), `title_gap` (6/12, the chip's 6 plus the title's own 6 on
   HomeRetro:35) and the button entries. Every value carries its board line in a comment.
4. **HOOKS.md:** `FileManager:openFile`, `FileManager:onHome` and `FrameContainer`'s `stripe_color` and
   `stripe_width`.

## Surfaces

`kopanda.koplugin/schema.lua`, `widgets/featured.lua` (new), `widgets.lua`, `main.lua` (require),
`home.lua` (the `after_show` loop, and the tap fall-through if needed), `looks/editorial.lua`,
`looks/diner.lua`, `HOOKS.md`; specs `spec/unit/featured_widget_spec.lua` (new),
`spec/unit/schema_spec.lua` (the default's four rows), `spec/unit/settings_spec.lua` (a layout naming
`featured`), `spec/unit/looks_spec.lua`, `spec/unit/home_layout_spec.lua` (the fall-through case, if
added).

## Tests

Written first and run failing. `FeaturedBook.current` and `FeaturedCover` are stubbed per case, and so is
`FileManager.instance` (recording `openFile` and `onHome`).

- `featured_widget_spec.lua` (C6):
  - For each look at widths 1236 and 1264:
    - the built width equals the column width, and the height equals `height(width, ctx)`;
    - each text part's face file, size (through `Layout.font_size`) and fgcolor (`Looks.color` of its role
      in the variant) match the tokens;
    - a 120-character title wraps to at most two lines and ends in "…".
  - `Featured.caption` for: 0.62 with 7800 s (`62%`, `2 h 10 min left`); 2700 s; 3600 s; no rate with
    pages 220 at 0.62 (`84 pages left`); one page left; neither; complete.
  - The bar fill width at 0, 0.62 and 1. Under the grey variant, Diner's fill is a `FrameContainer` with
    `stripe_width` set; Editorial's is a plain fill.
  - Record nil: the four first-run strings in order. A tap inside the button calls `Home.close` then
    `onHome`. A tap outside it returns false.
  - Record with an existing file: a tap calls `openFile(file)` once. Record with a removed file: a tap
    calls `ctx.home.refresh` and not `openFile`.
  - A Diner record with no chapter reads the authors alone, with no trailing " · ".
- `schema_spec.lua` (C1, layout part): `widgets` ends with `featured`, and the default is the four rows.
- `settings_spec.lua` (C2): a layout with a `featured` slot is accepted.
- `looks_spec.lua` (C7): the new parts and block entries are declared in both looks with face and palette
  roles.

## Edge cases

- The text column is narrow in a half-width slot (about 60 % of half the screen). The authors and caption
  truncate with `TextWidget`'s `max_width`. The title keeps two lines. The spec builds at 600 px to prove
  nothing overflows.
- `openFile` on a file KOReader can't open shows KOReader's own error. The home has already closed with
  the file manager, so nothing here handles it.
- A tap during the cover check: `openFile` closes the home, and the check stops on its next run
  (`Home.shown` changed) or is unscheduled by the close path.
