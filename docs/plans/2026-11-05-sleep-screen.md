# Sleep Screen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task by task.

**Goal:** Sleeping the device shows the book's full-screen cover with a card of its reading state in the current look,
behind one setting, falling back to KOReader's own sleep screen on anything unexpected.

**Architecture:** A new `sleep_screen.lua` wraps `Screensaver.setup` once per process. After KOReader's setup runs, it
draws the cover and card into one screen-sized bitmap and hands it over as a `cover` image, so `Screensaver:show` keeps
rotation, flashing, the gesture lock and closing. Design: `docs/plans/2026-11-05-sleep-screen-design.md`.

**Tech Stack:** Lua on KOReader's LuaJIT, Busted unit specs under `plugin_harness`, emulator capture specs.

**Working rules:**

- Work on `main`. No Tiller. No commit until the owner approves the summary at the end.
- TDD: each test runs and fails before its code. Read `bin/check` output through a filter that drops library chatter.
- KOReader is pinned at `e1fe1ac`, in `~/Projects/kodev/koreader/`. Cite it by `file:line` and never vendor it.
- The reference plugin is AGPL-3.0: nothing is copied from it.
- `main.lua` requires every module at load (see its header).

---

### Task 1: The `sleep.on` setting

**Files:**
- Modify: `kopanda.koplugin/schema.lua` (after `focused.on`)
- Modify: `spec/fixtures/studio/validator_cases.lua`
- Modify: `spec/unit/menu_spec.lua`
- Generated: `studio/src/schema.json`

**Step 1: Write the failing tests.** In `validator_cases.lua`, after the `focused.on` block:

```lua
    -- sleep.on
    { key = "sleep.on", value = true, valid = true, why = "true" },
    { key = "sleep.on", value = false, valid = true, why = "false" },
    { key = "sleep.on", value = 0, valid = false, why = "a number" },
    { key = "sleep.on", value = "false", valid = false, why = "a string" },
```

In `menu_spec.lua`, beside the `focused.on` tests, using its `row` helper:

```lua
it("shows the sleep screen as a toggle under Focused mode, on by default", function()
    local items = SchemaMenu.items()
    local focused, sleep
    for i, item in ipairs(items) do
        if item == row(items, "focused.on") then focused = i end
        if item == row(items, "sleep.on") then sleep = i end
    end
    assert.equals(focused + 1, sleep)
    assert.is_true(Settings.get("sleep.on"))
    row(items, "sleep.on").callback()
    assert.is_false(Settings.get("sleep.on"))
end)
```

**Step 2: Run them.** `bin/check spec/unit/menu_spec.lua spec/unit/studio_validator_spec.lua` (find the validator's spec
with `grep -ln validator_cases spec/unit/*`). Expected: FAIL, no `sleep.on` key.

**Step 3: Add the key** to `schema.lua`, after `focused.on`:

```lua
        {
            -- The book's cover and reading state on the sleep screen, in place of KOReader's own.
            id = "sleep.on",
            type = "boolean",
            default = true,
            label = "Sleep screen",
            group = "sleep",
        },
```

**Step 4: Regenerate the studio's schema.** `npm --prefix studio run schema`

**Step 5: Run.** `bin/check spec/unit/menu_spec.lua spec/unit/studio_schema_spec.lua` plus the validator spec. Expected:
PASS. If `settings_written` fails, follow `AGENTS.md`'s `KOPANDA_UPDATE_GOLDENS` line.

---

### Task 2: `FeaturedBook.for_file`

**Files:**
- Modify: `kopanda.koplugin/featured_book.lua:113-160`
- Test: `spec/unit/featured_book_spec.lua`

**Step 1: Write the failing tests**, in the spec's existing style, using its `book` and history helpers:

```lua
describe("for_file", function()
    it("reads the file it is given, not the pinned one", function()
        local pinned, other = book("pinned.epub"), book("other.epub")
        Settings.set("featured.pinned", pinned)
        assert.equals(other, FeaturedBook.for_file(other).file)
    end)

    it("takes live percent and chapter over the saved ones", function()
        local file = book("live.epub")
        local got = FeaturedBook.for_file(file, { percent = 0.5, chapter = "Letter 4" })
        assert.equals(0.5, got.percent)
        assert.equals("Letter 4", got.chapter)
    end)

    it("works out the time left from the live percent", function()
        -- Set up a sidecar and a seconds_per_page stub as the time-left test above does: 100 pages at 60 s.
        local file = sidecar_book_with_rate(100, 60)
        assert.equals(1800, FeaturedBook.for_file(file, { percent = 0.7 }).seconds_left)
    end)

    it("reads the saved chapter when no live one is given", function()
        local file = book("saved.epub")
        State.set("featured_chapter", "Saved")
        State.set("featured_chapter_file", file)
        assert.equals("Saved", FeaturedBook.for_file(file).chapter)
    end)

    it("reads no chapter for a live book with none", function()
        local file = book("nochapter.epub")
        State.set("featured_chapter", "Saved")
        State.set("featured_chapter_file", file)
        assert.is_nil(FeaturedBook.for_file(file, { percent = 0.5 }).chapter)
    end)
end)
```

`sidecar_book_with_rate` stands for the setup the spec's existing time-left test uses; reuse it rather than adding a
second one.

**Step 2: Run.** `bin/check spec/unit/featured_book_spec.lua`. Expected: FAIL, `for_file` is nil.

**Step 3: Implement.** Split `current` so the body becomes `for_file`, and the rest of the module is unchanged:

```lua
-- The record of file, as current() describes it, or nil when it can't be read. live ({ percent, chapter }), the open
-- book's own values, stands in for the saved ones, which can lag it; a live book's chapter is its own or none. Never raises.
function FeaturedBook.for_file(file, live)
    local ok, result = pcall(function()
        -- One sidecar open for the record and the progress both, none while it is unchanged.
        local book, progress = Books.with_progress(file)
        if not book then
            book = named(file)
            progress = Books.progress(book)
        end
        local percent = live and live.percent or progress.percent
        local has_percent = percent ~= nil
        percent = percent or 0
        -- (the seconds_left block, unchanged)
        return {
            -- (the fields, unchanged, but for the chapter)
            chapter = live and text(live.chapter) or (not live and try("the recorded chapter", recorded_chapter, file)) or nil,
        }
    end)
    if not ok then
        logger.err("KoPanda: could not read the book:", result)
        return nil
    end
    return result
end

function FeaturedBook.current()
    local file = featured_file()
    return file and FeaturedBook.for_file(file) or nil
end
```

`featured_file()` used to run inside the `pcall`, but it catches its own history read; check `Settings.get` can't raise
there before moving it, and keep `current` inside a `pcall` if it can. Keep the "Never raises" comment true.

**Step 4: Run.** `bin/check spec/unit/featured_book_spec.lua spec/unit/featured_widget_spec.lua`. Expected: PASS.

---

### Task 3: Shared pieces: the cover fill, the text box and the look tokens

**Files:**
- Modify: `kopanda.koplugin/wallpaper.lua:106-123`
- Modify: `kopanda.koplugin/widgets/featured.lua:130-150`
- Modify: `kopanda.koplugin/looks/base.lua`
- Test: `spec/unit/wallpaper_spec.lua`

**Step 1: Write the failing test** in `wallpaper_spec.lua`:

```lua
it("fills a box with an image, cropped at the centre", function()
    local image = Blitbuffer.new(100, 300, Blitbuffer.TYPE_BB8)
    image:fill(Blitbuffer.COLOR_WHITE)
    image:paintRect(0, 100, 100, 100, Blitbuffer.COLOR_BLACK) -- the middle third
    local bb = Wallpaper.fill_box(image, 200, 200, Blitbuffer.TYPE_BB8)
    assert.equals(200, bb:getWidth())
    assert.equals(200, bb:getHeight())
    assert.equals(0, bb:getPixel(100, 100):getColor8().a) -- only the black middle third is left
    bb:free()
end)
```

**Step 2: Run.** `bin/check spec/unit/wallpaper_spec.lua`. Expected: FAIL.

**Step 3: Implement.** Move the scaling out of `render` so both callers share it:

```lua
-- image scaled to cover a w by h box, centred and cropped, in a new buffer of bbtype. image is consumed: scaleBlitBuffer
-- frees it (frontend/ui/renderimage.lua:303-328).
function Wallpaper.fill_box(image, w, h, bbtype)
    local iw, ih = image:getWidth(), image:getHeight()
    local scale = math.max(w / iw, h / ih)
    local sw, sh = math.max(w, math.ceil(iw * scale)), math.max(h, math.ceil(ih * scale))
    local scaled = RenderImage:scaleBlitBuffer(image, sw, sh)
    local bb = Blitbuffer.new(w, h, bbtype)
    bb:blitFrom(scaled, 0, 0, math.floor((sw - w) / 2), math.floor((sh - h) / 2), w, h)
    scaled:free()
    return bb
end
```

`render` keeps its `renderImageFile` read and error, then returns `Wallpaper.fill_box(image, w, h, bbtype)`.

Export the title box in `featured.lua`: rename `local function text_box` to `function Featured.text_box`, updating its
callers in that file. Check `local Featured` is declared above it (it is, at line 26).

Add to `looks/base.lua`, before `featured`:

```lua
    -- The sleep screen's card over the cover: its inset from the screen's edges, padding, gap between lines, fill,
    -- outline and corners.
    sleep = {
        margin = 30,
        padding = { x = 24, y = 20 },
        gap = 8,
        fill_color = "paper",
        outline_color = "outline",
        outline_width = 2,
        radius = 12,
    },
```

**Step 4: Run.** `bin/check spec/unit/wallpaper_spec.lua spec/unit/looks_spec.lua spec/unit/featured_widget_spec.lua`.
Expected: PASS.

---

### Task 4: The image

**Files:**
- Create: `kopanda.koplugin/sleep_screen.lua`
- Modify: `kopanda.koplugin/main.lua` (the `require` list)
- Test: `spec/unit/sleep_screen_spec.lua`

**Step 1: Write the failing tests.** Create `spec/unit/sleep_screen_spec.lua`:

```lua
-- The sleep screen: the cover and card drawn into one screen-sized bitmap, and the Screensaver.setup wrapper that hands
-- it to KOReader, or leaves KOReader's own screen on anything unexpected.
describe("SleepScreen", function()
    local harness = require("plugin_harness")
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local SleepScreen, Looks, Paint
    local W, H = 600, 800

    local function ctx(look_id, variant)
        return { look = Looks.get(look_id or "diner"), variant = variant or "day", text_size = "medium",
            now = 0, screen = Screen }
    end

    -- A flat cover the card's paper can't be mistaken for.
    local function cover()
        local bb = Blitbuffer.new(300, 400, Blitbuffer.TYPE_BBRGB32)
        bb:paintRectRGB32(0, 0, 300, 400, Blitbuffer.colorFromString("#102030"))
        return bb
    end

    local BOOK = { title = "Frankenstein", chapter = "Letter 4", percent = 0.42, status = "reading",
        seconds_left = 3600 }

    -- The screen's bitmap pixel as #rrggbb.
    local function hex(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return string.format("#%02x%02x%02x", c:getR(), c:getG(), c:getB())
    end

    -- A point just inside the card's bottom edge, clear of its text and outline.
    local function in_card(look)
        local scale = Paint.scaler(ctx())
        return math.floor(W / 2), H - scale(look.sleep.margin) - scale(look.sleep.outline_width) - 2
    end

    setup(function()
        harness.load()
        SleepScreen, Looks, Paint = require("sleep_screen"), require("looks"), require("paint")
    end)

    describe("image", function()
        it("is the screen's size, with the cover above the card", function()
            local bb = SleepScreen.image(BOOK, cover(), W, H, ctx())
            assert.equals(W, bb:getWidth())
            assert.equals(H, bb:getHeight())
            assert.equals("#102030", hex(bb, 10, 10))
            bb:free()
        end)

        it("paints the card in the look's paper", function()
            local look = Looks.get("diner")
            local x, y = in_card(look)
            local bb = SleepScreen.image(BOOK, cover(), W, H, ctx("diner"))
            assert.equals(look.palettes.day.paper, hex(bb, x, y))
            bb:free()
        end)

        it("shows the night palette as designed, the cover unchanged, at night", function()
            local look = Looks.get("diner")
            local x, y = in_card(look)
            Screen.night_mode = true
            local bb = SleepScreen.image(BOOK, cover(), W, H, ctx("diner", "night"))
            Screen.night_mode = false
            assert.equals(look.palettes.night.paper, hex(bb, x, y))
            assert.equals("#102030", hex(bb, 10, 10))
            bb:free()
        end)

        it("paints with no chapter and no time left", function()
            local bb = SleepScreen.image({ title = "Frankenstein", percent = 0, status = "reading" },
                cover(), W, H, ctx())
            assert.equals(W, bb:getWidth())
            bb:free()
        end)

        it("frees its bitmap and raises when the card can't be drawn", function()
            local freed = 0
            local new = Blitbuffer.new
            local stubbed = stub(Blitbuffer, "new", function(...)
                local bb = new(...)
                local free = bb.free
                bb.free = function(self) freed = freed + 1; free(self) end
                return bb
            end)
            assert.has_error(function()
                SleepScreen.image({ percent = 0, status = "reading" }, cover(), W, H, ctx())
            end)
            stubbed:revert()
            assert.equals(1, freed)
        end)
    end)
end)
```

Blitbuffer methods live on metatypes, so the `free` stub above may not take. If it doesn't, assert the failure path
another way: stub `Featured.text_box` to raise, and spy `Blitbuffer.BB.free` or the module's use of it. Don't drop the
test.

**Step 2: Run.** `bin/check spec/unit/sleep_screen_spec.lua`. Expected: FAIL, no module `sleep_screen`.

**Step 3: Implement** `kopanda.koplugin/sleep_screen.lua`:

```lua
-- The sleep screen: the book's cover filling the screen with a card of its reading state, drawn into one bitmap and
-- handed to KOReader as a cover, so Screensaver:show keeps rotation, flashing, the lock and closing. Wraps
-- Screensaver.setup (frontend/ui/screensaver.lua:346), which runs before :show on every sleep; anything unexpected
-- leaves KOReader's own screen. State: whether the wrapper is installed.
local Featured = require("widgets/featured")
local Looks = require("looks")
local Paint = require("paint")
local Typeset = require("typeset")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Wallpaper = require("wallpaper")

local SleepScreen = {}

local JOIN = " · "

-- The card's lines for book, inner_w wide, as a left-aligned group.
local function lines(book, inner_w, ctx)
    local look, scale = ctx.look, Paint.scaler(ctx)
    local gap = VerticalSpan:new{ width = scale(look.sleep.gap) }
    local group = VerticalGroup:new{ align = "left" }
    group[1] = Featured.text_box("featured_title", book.title, inner_w, 2, ctx)
    if book.chapter then
        group[#group + 1] = gap
        group[#group + 1] = Typeset.line(look.type.featured_chapter, book.chapter, inner_w, ctx)
    end
    group[#group + 1] = gap
    group[#group + 1] = Featured.bar(Featured.shown_percent(book), inner_w, scale(look.progress.height),
        look.progress.outline_width, ctx)
    group[#group + 1] = gap
    group[#group + 1] = Typeset.line(look.type.featured_caption, table.concat(Featured.caption(book), JOIN), inner_w, ctx)
    return group
end

-- Paints book's card along the bottom of a w by h bitmap, in ctx's look.
local function paint_card(bb, book, w, h, ctx)
    local tokens, scale, color = ctx.look.sleep, Paint.scaler(ctx), Looks.colorer(ctx)
    local margin = scale(tokens.margin)
    local pad_x, pad_y = scale(tokens.padding.x), scale(tokens.padding.y)
    local card_w = w - 2 * margin
    local group = lines(book, card_w - 2 * pad_x, ctx)
    local card_h = group:getSize().h + 2 * pad_y
    local x, y, radius = margin, h - margin - card_h, scale(tokens.radius)
    Paint.fill(bb, x, y, card_w, card_h, color(tokens.fill_color), radius)
    Paint.border(bb, x, y, card_w, card_h, scale(tokens.outline_width), color(tokens.outline_color), radius)
    group:paintTo(bb, x + pad_x, y + pad_y)
    group:free()
end

-- The sleep screen for book ({ title, chapter, percent, status, seconds_left }), a new bitmap w by h. cover, a bitmap, is
-- consumed. KOReader's ImageWidget inverts a bitmap at night so it shows as it was drawn
-- (frontend/ui/widget/imagewidget.lua:77, :591-593), while KoPanda paints for the panel's inversion, so at night the
-- card is painted between two inversions of the whole bitmap, which leave the cover as it was.
function SleepScreen.image(book, cover, w, h, ctx)
    local bb = Wallpaper.fill_box(cover, w, h, ctx.screen.bb:getType())
    local ok, err = pcall(function()
        local night = ctx.screen.night_mode
        if night then
            bb:invertRect(0, 0, w, h)
        end
        paint_card(bb, book, w, h, ctx)
        if night then
            bb:invertRect(0, 0, w, h)
        end
    end)
    if not ok then
        bb:free()
        error(err, 0)
    end
    return bb
end

return SleepScreen
```

Add `require("sleep_screen")` to `main.lua`'s list, in alphabetical order, as a `local SleepScreen` beside `Swatch`.

`sleep_screen` requires `widgets/featured`, which reaches `launcher_entries`: if a require loop shows up, require
`widgets/featured` inside `lines`, with a comment, as `launcher_entries.lua` does.

**Step 4: Run.** `bin/check spec/unit/sleep_screen_spec.lua`. Expected: PASS. `bin/check --lint` for the line lengths.

---

### Task 5: The hook

**Files:**
- Modify: `kopanda.koplugin/sleep_screen.lua`
- Modify: `kopanda.koplugin/main.lua:150-156`
- Modify: `spec/plugin_harness.lua`
- Test: `spec/unit/sleep_screen_spec.lua`

**Step 1: Restore the original in the harness**, or each `load` wraps the last wrapper. In `plugin_harness.lua`, beside
`M.dispatcher_execute`:

```lua
-- Screensaver.setup as KOReader defines it, before sleep_screen.lua wraps it.
M.screensaver_setup = require("ui/screensaver").setup
```

and in `M.load`, beside the dispatcher line:

```lua
    require("ui/screensaver").setup = M.screensaver_setup
```

**Step 2: Write the failing tests**, a second `describe` in the same spec:

```lua
describe("setup", function()
    local Screensaver = require("ui/screensaver")
    local fm, Settings, logger
    local book = harness.library .. "/frankenstein.epub"
    local saved_type

    before_each(function()
        harness.load()
        Settings, logger = require("settings"), require("logger")
        fm = harness.show_fm()
        saved_type = G_reader_settings:readSetting("screensaver_type")
        G_reader_settings:saveSetting("screensaver_type", "disable")
        G_reader_settings:saveSetting("lastfile", book)
    end)

    after_each(function()
        Screensaver:cleanup()
        G_reader_settings:saveSetting("screensaver_type", saved_type)
        G_reader_settings:delSetting("lastfile")
        fm:onClose()
    end)

    local function kept_koreaders()
        assert.is_nil(Screensaver.image)
        assert.equals("disable", Screensaver.screensaver_type)
    end

    it("hands KOReader a screen-sized cover for the last book", function()
        Screensaver:setup()
        assert.equals("cover", Screensaver.screensaver_type)
        assert.is_nil(Screensaver.image_file)
        assert.equals(math.min(Screen:getWidth(), Screen:getHeight()), Screensaver.image:getWidth())
        assert.equals(math.max(Screen:getWidth(), Screen:getHeight()), Screensaver.image:getHeight())
    end)

    it("replaces the image KOReader's own cover mode made", function()
        G_reader_settings:saveSetting("screensaver_type", "cover")
        Screensaver:setup()
        assert.equals(Screen:getWidth(), Screensaver.image:getWidth())
    end)

    it("leaves KOReader's screen with sleep.on off", function()
        Settings.set("sleep.on", false)
        Screensaver:setup()
        kept_koreaders()
    end)

    it("leaves KOReader's screen for poweroff and reboot", function()
        Screensaver:setup("poweroff", "Powered off")
        kept_koreaders()
    end)

    it("leaves KOReader's screen with no last book", function()
        G_reader_settings:delSetting("lastfile")
        Screensaver:setup()
        kept_koreaders()
    end)

    it("leaves KOReader's screen when the last book has gone", function()
        G_reader_settings:saveSetting("lastfile", harness.library .. "/gone.epub")
        Screensaver:setup()
        kept_koreaders()
    end)

    it("leaves KOReader's screen for an excluded book", function()
        local stubbed = stub(Screensaver, "isExcluded", function() return true end)
        Screensaver:setup()
        stubbed:revert()
        kept_koreaders()
    end)

    it("leaves KOReader's screen for a book with no cover", function()
        local stubbed = stub(fm.bookinfo, "getCoverImage", function() return nil end)
        Screensaver:setup()
        stubbed:revert()
        kept_koreaders()
    end)

    it("logs a failed draw and leaves KOReader's screen", function()
        local image, err = stub(SleepScreen, "image", function() error("no") end), spy.on(logger, "err")
        Screensaver:setup()
        image:revert()
        assert.spy(err).was_called()
        err:revert()
        kept_koreaders()
    end)

    it("reads the open book's page and chapter live", function()
        fm:onClose()
        local reader = harness.open_reader("frankenstein.epub")
        local got
        local image = stub(SleepScreen, "image", function(b, cover) got = b; cover:free(); error("stop") end)
        reader:handleEvent(require("ui/event"):new("GotoPage", 10))
        Screensaver:setup()
        image:revert()
        assert.equals(10 / reader.document:getPageCount(), got.percent)
        assert.equals(reader.toc:getTocTitleByPage(10), got.chapter)
        reader:onClose()
        fm = harness.show_fm()
    end)
end)
```

`SleepScreen.image`'s test stubs call `error`, and `build` must still reach it through the module table, so it's stubbable.

**Step 3: Run.** `bin/check spec/unit/sleep_screen_spec.lua`. Expected: FAIL, the cover test finds type `random_image`.
Other cases may pass already; that's fine, as they guard the wrapper.

**Step 4: Implement.** Add to `sleep_screen.lua`, with the extra requires at the top (`FeaturedBook`, `Screensaver`,
`Settings`, `logger`, `lfs`, and `Device.screen` as `Screen`):

```lua
local installed = false

-- The open book's own percent and chapter, since its sidecar can lag it; nil outside a book.
local function live(ui)
    if not ui.document then
        return nil
    end
    local page = ui:getCurrentPage()
    return { percent = page / ui.document:getPageCount(), chapter = ui.toc:getTocTitleByPage(page) }
end

-- The bitmap for the open or last book, or nil to leave KOReader's screen. Raises what a read or the draw raises.
local function build(ui)
    if not (ui and Settings.get("sleep.on")) or Screensaver.isExcluded(ui) then
        return nil
    end
    local file = ui.document and ui.document.file or G_reader_settings:readSetting("lastfile")
    if not (file and lfs.attributes(file, "mode") == "file") then
        return nil
    end
    local book = FeaturedBook.for_file(file, live(ui))
    -- As Screensaver:setup reads a cover (frontend/ui/screensaver.lua:410).
    local cover = book and ui.bookinfo:getCoverImage(ui.document, file)
    if not cover then
        return nil
    end
    -- Portrait, since Screensaver:show rotates after setup (frontend/ui/screensaver.lua:469-481).
    local w, h = Screen:getWidth(), Screen:getHeight()
    return SleepScreen.image(book, cover, math.min(w, h), math.max(w, h), {
        look = Looks.active(),
        variant = Looks.variant(),
        text_size = Settings.get("text_size"),
        now = os.time(),
        screen = Screen,
    })
end

-- Wraps Screensaver.setup, once per process. KOReader's setup runs first, so its result stands on anything but a
-- finished image; poweroff and reboot pass an event and keep their own screens (frontend/ui/uimanager.lua:84, :109).
function SleepScreen.install()
    if installed then
        return
    end
    installed = true
    local original = Screensaver.setup
    Screensaver.setup = function(self, event, event_message)
        original(self, event, event_message)
        if event then
            return
        end
        local ok, image = pcall(build, self.ui)
        if not ok then
            logger.err("KoPanda: could not draw the sleep screen:", image)
        elseif image then
            if self.image then
                self.image:free()
            end
            self.image, self.image_file, self.screensaver_type = image, nil, "cover"
        end
    end
end
```

In `main.lua`, after `DispatchBridge.install()`:

```lua
        -- Once per process; each sleep reads sleep.on.
        SleepScreen.install()
```

**Step 5: Run.** `bin/check spec/unit/sleep_screen_spec.lua`. Expected: PASS.

---

### Task 6: Emulator scenario

**Files:**
- Create: `spec/emulator/scenarios/2-scenario-sleep-screen.lua`
- Create: `spec/emulator/sleep_screen_spec.lua`

**Step 1: Write the scenario patch**, following `2-scenario-focused-panel.lua`'s shape (`report`, `fail`, `guarded`, its
poll for the reader). On the first home's settled signal, it reads `KOPANDA_SLEEP_STEP`:

- `book`: opens the library's book, and on the reader's arrival sleeps.
- `landscape`: as `book`, turning the reader with `Event:new("SetRotationMode", Screen.DEVICE_ROTATED_CLOCKWISE)` first.
- `home`: saves `lastfile` as the library's book and sleeps from the home.

Sleeping is `Device:simulateSuspend()` (`frontend/device/sdl/device.lua:462-468`), then `UIManager:tickAfterNext`, then
`report{ margin = Screen:scaleBySize(look.sleep.margin), outline = Screen:scaleBySize(look.sleep.outline_width),
width = Screen:getWidth(), height = Screen:getHeight(), screensaver_type = Screensaver.screensaver_type,
widget_shown = Screensaver.screensaver_widget ~= nil }`.

**Step 2: Write the spec**, with `library_with_one_book` and `settings_file` as `focused_panel_spec.lua` has them:

```lua
-- The sleep screen on the emulator, through a simulated sleep: the card over the cover from a book and from the home,
-- night's card in the look's night paper, a landscape book's screen in portrait, and no card with sleep.on off.
describe("the sleep screen on the emulator", function()
    -- (the requires, library_with_one_book and settings_file, as in focused_panel_spec.lua)
    local compare = require("emulator.compare")
    local Looks -- loaded as night_toggle_spec.lua loads it

    local function sleep(step, opts)
        local result = driver.capture{
            profile = "colorsoft",
            plugin_dir = plugin,
            library_dir = library_with_one_book(),
            patches = { scenario },
            shot_screen = "scenario",
            env = { KOPANDA_SLEEP_STEP = step },
            night_mode = opts and opts.night_mode,
            settings_file = opts and opts.settings_file,
        }
        assert.is_nil(result.sidecar.error)
        return result, result.sidecar
    end

    -- Near want, as #rrggbb, at the middle of the card's bottom padding.
    local function assert_card_paper(result, s, want)
        local got = compare.pixel(result.png, math.floor(s.width / 2), s.height - s.margin - s.outline - 3)
        local rgb = { tonumber(want:sub(2, 3), 16), tonumber(want:sub(4, 5), 16), tonumber(want:sub(6, 7), 16) }
        for c = 1, 3 do
            assert.truthy(math.abs(got[c] - rgb[c]) <= 16,
                string.format("paper %02x%02x%02x, want %s", got[1], got[2], got[3], want))
        end
    end

    local function diner(variant)
        return Looks.get("diner").palettes[variant].paper
    end

    it("shows the card over the cover from a book", function()
        local result, s = sleep("book")
        assert.equals("cover", s.screensaver_type)
        assert_card_paper(result, s, diner("day"))
    end)

    it("shows the last book from the home", function()
        local result, s = sleep("home")
        assert_card_paper(result, s, diner("day"))
    end)

    it("shows the look's night paper at night", function()
        local result, s = sleep("book", { night_mode = true })
        assert_card_paper(result, s, diner("night"))
    end)

    it("keeps a landscape book's screen in portrait", function()
        local result, s = sleep("landscape")
        assert.is_true(s.height > s.width)
        assert.is_true(result.height > result.width)
        assert_card_paper(result, s, diner("day"))
    end)

    it("shows no card with sleep.on off", function()
        local _, s = sleep("book", { settings_file = settings_file("off", { ["sleep.on"] = false }) })
        assert.is_not.equals("cover", s.screensaver_type)
    end)
end)
```

The default `look` is Diner, so `diner` is the look under test. A first run settles what the emulator's defaults do with
`screensaver_type`. The last test relies on that not being `cover`; set it in the scenario if it is.

**Step 3: Run.** `bin/check spec/emulator/sleep_screen_spec.lua`. Expected: PASS. A failure here is a real gap in the
tasks above, so fix the cause there.

**Step 4: Look at it.** Run the capture for each look and open the PNGs for the owner's look check at the end. Add
`look` to the `settings_file` to do so; these three renders are by eye, not asserted.

---

### Task 7: Docs

**Files:**
- Modify: `kopanda.koplugin/HOOKS.md`
- Modify: `AGENTS.md`
- Modify: `.tiller/design/2026-10-13-kopanda-design.md:142`
- Modify: `.tiller/design/2026-10-13-kopanda-ui-direction.md:130`
- Modify: `.tiller/design/handoff-2026-10-08.md:115`
- Modify: `docs/plans/2026-11-02-book-status-design.md:7` only if a reader would be misled; it's a dated record, so
  leave it otherwise

**Step 1:** Add a `### The sleep screen: Screensaver.setup, the cover image and night` section to `HOOKS.md`, citing the
design's Facts by `file:line`.

**Step 2:** In `AGENTS.md`'s reference plugins line, add `customisablesleepscreen (AGPL-3.0: read, don't copy)`.

**Step 3:** In the three design docs, keep the out-of-scope line and add after it: "One exception, decided 2026-11-05:
KoPanda's sleep screen (`docs/plans/2026-11-05-sleep-screen-design.md`)."

---

### Task 8: Gate and hand-off

**Step 1:** `bin/check` (the lead's full gate). Expected: exits 0. Note the 5 slowest tests.

**Step 2:** Review, one pass with no mutation checks (not push or file-ingesting code): a fresh Opus agent, briefed with
this plan and the diff, ending in a numbered fix list. A fix round is a fresh agent.

**Step 3:** Open the look captures for the owner, then ask: "Ready to commit and push?" Stage named files only, with no
AI attribution. Pushing to `main` with plugin changes cuts a release.

**Step 4:** After the push, update the memory index with the feature's status, naming the Kindle checks still open.

---

# Phase 2: The owner's additions

The design's Additions section is the spec. Tasks 1 to 7 are built and uncommitted in the working tree. These tasks
extend that work, on the same rules: TDD, no commits, `bin/check <spec>` while working.

### Task 9: `device_stats.lua`, battery reads

**Files:** Create `kopanda.koplugin/device_stats.lua`, `spec/unit/device_stats_spec.lua`, `spec/fixtures/battery_stats.lua`.

Take `MIN_RECORD`, `finite`, `DeviceStats.time_left`, `DeviceStats.left_text` and `DeviceStats.battery_totals` exactly as
`docs/plans/2026-11-05-stats-additions.md` Task 6 Step 4 writes them, with the same names, so that plan's later tasks
extend this file. Tests as its Task 6 lists them for these functions: a real file's shape, either side of the hour, zero,
malformed tables and a missing file. Make the fixture from a real file the emulator's Battery statistics plugin wrote.
Don't build `widgets/device.lua`.

### Task 10: The book's extra fields

**Files:** Modify `kopanda.koplugin/featured_book.lua`, `spec/unit/featured_book_spec.lua`.

`for_file`'s and `current`'s record gains `series` and `series_index` from the book record.

### Task 11: Clean chapter titles and the card's text

**Files:** Modify `kopanda.koplugin/sleep_screen.lua`, `spec/unit/sleep_screen_spec.lua`.

Pure functions, each tested at its edges:

- `SleepScreen.clean_chapter(title)`: "Chapter 5: The Storm", "CHAPTER V. The Storm", "Chapter One - The Storm" and
  "Chapter 12 — The Storm" (and an en dash) give "The Storm". "Chapter 5", "Chapter of Accidents", "Letter 4",
  "Chapter 5 The Storm" and "Chapter 5:" stay as they are.
- `SleepScreen.byline(book)`: "Authors · Series #2", "Series", "Authors", or nil. No index, no "#".
- The chapter line: the clean title, joined to "12 min left in chapter" when there is a time; either alone; nil with
  neither.
- `SleepScreen.today(seconds, pages)`: "Today 35 pages · 40 min", "Today 1 page · 1 min"; nil at zero pages.
- `SleepScreen.battery(percent, charging, totals)`: "62% · about 9 days left"; "62%" charging or with no time; nil with
  no percent.

### Task 12: Reads and the tiles

**Files:** Modify `kopanda.koplugin/sleep_screen.lua`, `kopanda.koplugin/widgets/forecast.lua`,
`spec/unit/sleep_screen_spec.lua`, `spec/unit/forecast_widget_spec.lua`, `kopanda.koplugin/looks/base.lua`.

- `live(ui)` adds `chapter_seconds`: pages left in the chapter, or in the book in its last chapter
  (`ui.document:getTotalPagesLeft`), times a finite positive `ui.statistics.avg_time`.
- `today`: `ui.statistics:getTodayBookStats()`, guarded, with no `ui.statistics` reading as nil.
- Forecast: `ctx.forecast_book` stands in for `FeaturedBook.current()`, and with it only the first two lines show. The
  home's forecast doesn't change.
- `paint_card` becomes one card as the design's Additions draw it. The tiles are half the inner width each, with a
  `sleep.tile_gap` token, drawn only when `ReadingStats.insights(ctx.now).state == "ok"`. The bottom line has today on
  the left and battery on the right. Measure battery first and give today the room left.
- A card over half the height drops the tiles. Test the edge: a card just over, and just under.
- `HOOKS.md`: the new reads, each `file:line`.

### Task 13: The emulator

**Files:** Modify `spec/emulator/scenarios/2-scenario-sleep-screen.lua`, `spec/emulator/sleep_screen_spec.lua`.

Seed the statistics database as the Stats window's capture does, and add one capture proving the tiles draw on the card.
Keep the five existing tests passing. Re-render the look check.
