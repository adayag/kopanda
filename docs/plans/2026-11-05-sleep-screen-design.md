# Sleep screen (2026-11-05)

Decided on 2026-11-05 with the owner, after reading pxlflux/customisablesleepscreen.koplugin (`feb29ac`, AGPL-3.0:
read, don't copy). KoPanda gets its own sleep screen: the book's cover filling the screen, with a card of its reading
state in the current look. This reverses the 2026-10-13 decision that sleep screens stay KOReader's, for this one
screen. KOReader's own stay available behind one setting.

## Decisions

| Decision | Chosen | Over |
|---|---|---|
| What it shows | Cover, title, chapter, progress, time left | A stats card; a quote page; installing the reference plugin as it is |
| Layout | Full-screen cover with a card at the bottom | A framed cover on paper; a small cover beside the text |
| With no book open | The last book read | KOReader's screen outside a book |
| How it hooks in | Wrap `Screensaver:setup` and give KOReader one finished image | Wrap `Screensaver:show` and build the widget, as the reference plugin does |
| Options | One setting, per the few-settings rule | Presets, colours, icon sets, section ordering, a PIN lock |

## Facts

- The reference plugin is 11,687 lines of Lua. It wraps `Screensaver.show` and rebuilds the widget, the lock gesture
  and closing (`main.lua:699-822`, `:826`).
- `Screensaver:setup(event, event_message)` runs before `:show` on every sleep (`frontend/device/kindle/device.lua:762-763`,
  `frontend/device/generic/device.lua:467-468`, `frontend/device/sdl/device.lua:464-465`). Only poweroff and reboot pass
  an event (`frontend/ui/uimanager.lua:84`, `:109`).
- With `screensaver_type` `cover` and `self.image` set, `:show` builds an `ImageWidget` at the screen's size and owns
  the bitmap through `image_disposable` (`frontend/ui/screensaver.lua:506-515`). It also rotates a landscape screen to
  portrait and flashes the e-ink panel (`:469-499`), and shows the gesture lock (`:653-658`, `:684-689`). `:close` and `:cleanup`
  are unchanged by what the image is (`:724-781`).
- At setup a landscape screen still reports landscape sizes; `:show` swaps them later (`:481`).
- KOReader reads a book's full-size cover with `ui.bookinfo:getCoverImage(ui.document, lastfile)` (`:410`).
- A book is excluded from the sleep screen by `Screensaver.isExcluded(ui)` (`:200-208`). The finished, on-hold and
  file-manager options of KOReader's cover mode (`:386-399`) don't apply while `sleep.on` is set.
- `ImageWidget.original_in_nightmode` defaults to true, so it inverts a bitmap at night and the panel's inversion
  puts it back (`frontend/ui/widget/imagewidget.lua:77`, `:591-593`). The bitmap shows at night exactly as drawn,
  unlike everything else KoPanda paints.
- `Looks.palette` inverts the night palette for that panel inversion (`looks.lua:100-103`), so the card can't paint
  with it as it stands.
- `FeaturedBook.current` builds the record this needs, for the pinned or latest book only (`featured_book.lua:113-151`).
  `Featured.caption` already words the percent and time left (`widgets/featured.lua:105`), and `Wallpaper`'s `render`
  already scales an image to cover a box (`wallpaper.lua:109-123`).
- The open book's sidecar can lag the reader; `focused_panel.lua:76` already reads the live chapter from `ui.toc`.
- KOReader's sleep screen doesn't run on a Special Offers Kindle (`frontend/device/kindle/device.lua:527-533`). The
  Colorsoft already uses KOReader's, per handoff §4.

## Design

**`kopanda_sleep_screen.lua`, about 200 lines** (first named `sleep_screen`, which cwngsync.koplugin also has; see the end). Wraps `Screensaver.setup` once per process. The wrapper runs the original
first, so KOReader's state is whole, then with `sleep.on` set and no event it tries to build the image. On success it
frees any `self.image` the original made, clears `self.image_file`, and sets `self.image`,
`screensaver_type = "cover"` and the image background (`:443-447`, which the flash reads, `:488-492`). On anything else KOReader's result stands.

**The book.** The open book, else `G_reader_settings`' `lastfile`. `FeaturedBook` gains a function that builds its record
for a given file. With a book open, title, percent and chapter come from the reader; otherwise from the record, the
sidecar and the recorded chapter.

**The image.** One screen-sized bitmap in the screen's own type, at portrait sizes (the smaller side as width), since
`:show` is what rotates. The cover is scaled to cover it, centred and cropped, through a function `Wallpaper` shares. The
card is painted over the bottom.

**The card.** Inset from the sides and bottom, filled with the look's paper, in tokens under a new `sleep` table in
`looks/base.lua`. Title up to two lines, chapter one line, the progress bar, then `Featured.caption`'s line: the percent
with the time left, the pages left or Finished. No chapter drops that line. At night the card is painted, as everything
KoPanda paints, for the panel's inversion, between two inversions of the whole bitmap, which leave the cover as it was.

**The setting.** `sleep.on`, boolean, default true, labelled Sleep screen, in its own `sleep` group after `focused.on`, so
KoPanda's settings menu shows it as a toggle under Focused mode (`menu.lua:131`, `:281`) and the studio form shows it too. Justified: the owner has sleep-screen art
in `koreader/screensavers/` and wants to go back to it on the device.

## Failure

The wrapper's work runs in a `pcall`, and a failure is logged. These fall back to KOReader's screen, including the
owner's art when that is its mode:

- no `lastfile`, or the file is gone
- an excluded book
- no cover
- any raised error, with the partly built bitmap freed

A failed draw can't reach `:show` with a half-made image, because `self.image` is set last.

## Testing

Unit, on the parts with no running KOReader:

- Live values win over saved ones with a book open; saved ones are used with none.
- A card with no chapter and no time left.
- The card's paper by day and at night, and the cover unchanged at night.
- Each fallback leaves `Screensaver`'s state as the original set it: `sleep.on` off, an event, no `lastfile`, an
  excluded book, no cover, a draw that raises (and its bitmap freed).

Emulator, through `simulateSuspend` on the fixture library, one capture per behaviour, each sampling pixels:

- A book open: card paper at the card, not paper in the cover.
- From the home, after a book closed: the same.
- Night mode: the card's paper is the look's night paper.
- A landscape book: the image is portrait and fills the screen.
- `sleep.on` off: no card.

## Manual checks

- The card in each look by eye, by day and at night, on the emulator.
- On the Kindle: sleep from a book and from the home, wake, and check the wait before sleeping isn't noticeable.
- A sleep with the screen left in landscape, on the Kindle.

## Docs

- `HOOKS.md`: the `Screensaver` hook and each line above.
- `.tiller/design/2026-10-13-kopanda-design.md`, the UI direction and the handoff: sleep screens noted as an exception
  decided 2026-11-05.
- `AGENTS.md`: the reference plugin added to the list, AGPL-3.0, read, don't copy.

## Out of scope

- Reboot and poweroff screens.
- KOReader's "Sleeping" message box: it stays KOReader's, and the owner turns it off in KOReader's settings on the device.
- Colour choices, presets and section order, the card's position, a clock, battery or daily stats.
- A lock screen.
- A `bin/preview` mode for it, until the emulator capture proves short of what the owner needs.
- Replacing the owner's art with a sleep-screen wallpaper or a screen for books with no cover.

## Additions (2026-11-05)

After seeing the first build, the owner chose more on the card: the streak and finish-by tiles, today's reading, clean
chapter titles, time left in the chapter, an author or series line, and battery with its time left. The rest of the
reference plugin's list stays out.

**One card.** Everything sits on one card of the look's paper, since a look without tile boxes (Editorial) has nothing
behind its tile's text over a cover. Top to bottom:

```
Streak            | Finish by         only with reading data
Title
Authors · Series #2
The Storm · 12 min left in chapter
progress bar
42% · 3 h left
Today 35 pages · 40 min      62% · about 9 days left
```

**Each line drops alone** when it has nothing to show. A home sleep has no chapter time left, since that needs the
open book.

**The cover keeps half the screen.** A card whose tiles row would take its top past the middle of the screen, its
bottom margin counted, drops that row.

**Sources.**

- Streak and forecast are the existing widgets. Forecast takes the sleep screen's book through its ctx, and shows its
  first two lines only: its title and time left repeat the book lines. The tiles show when `ReadingStats.insights` is
  `ok`.
- Today's reading is `ui.statistics:getTodayBookStats()` (`plugins/statistics.koplugin/main.lua:1452`), which returns
  seconds and pages, plus the session Statistics hasn't flushed yet, `mem_read_time` and `mem_read_pages` (`:69-70`,
  `:2606-2617`, `:253-254`), read only, since the card draws before the flush on Suspend (`:2694-2697`). Dropped at
  zero or without Statistics. The streak leaves that session out until it's flushed.
- Clean titles strip "Chapter <word><separator>" from the front, leaving a bare "Chapter 5" alone, and "Chapter 5: —",
  where only punctuation would follow.
- Chapter time left is `ui.toc:getChapterPagesLeft(page, true)` (`frontend/apps/reader/modules/readertoc.lua:715`, in
  screen pages, as the footer reads it, `readerfooter.lua:345`), or the book's pages left in its last chapter, times
  `ui.statistics.avg_time` (`main.lua:3026`). A page with no chapter title has none.
- Author and series come from the book record's `authors`, `series` and `series_index` (`books.lua:146-147`).
- Battery is `QuickSettings.battery()`, with `DeviceStats.time_left` and `left_text` over KOReader's
  `settings/battery_stats.lua`, as the Stats additions plan specifies them. That read handles a file from outside, so
  it takes the full review. Charging, under an hour on record, or 90 days or more left shows the percent alone.

**Out of scope, still:** a daily goal, highlights, hidden-flow page numbers, the rest of the first list.

## Fix after the first Kindle sleep (2026-11-05)

The owner's art showed in place of the card. The Kindle's log held `KoPanda: init failed: main.lua:160: attempt to call
field 'install' (a nil value)`: cwngsync.koplugin's `main.lua:36` requires its own `sleep_screen`, cwngsync loads before
KoPanda, and `require` caches by name across plugins. The module is now `kopanda_sleep_screen`, and `SleepScreen.install`
runs last in init, since that failure had also skipped `FmNav.install` and `FocusedHooks.install`. The emulator has no
cwngsync, so `spec/unit/main_requires_spec.lua` stands in for it.
