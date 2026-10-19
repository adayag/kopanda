# Quick settings from the top menu: implementation plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

> Note, after review: the tab sits just before Main, not last. A tab with `remember = false` cannot be far right, since KOReader's right-third menu swipe opens the last index and TouchMenu turns that into tab 1 (`frontend/ui/widget/touchmenu.lua:458-462`, `:668`). Every "last" below reads "before Main"; the design doc has the final text.

**Goal:** A `kopanda_quick_settings` tab, last in KOReader's top menu in both the reader and the file browser, that closes the menu and opens the existing quick-settings sheet.

**Architecture:** `menu_entries.lua` already inserts the Home tab into the file browser's cached menu order; it is generalised to a tab spec (id, order module, menu-sorter name, position) and gains the two quick-settings tabs. `main.lua`'s `addToMainMenu` adds the item in both apps. In the reader the sheet gets a no-op `beneath`, so its failure path closes nothing. No schema key, no setting, no new icon.

**Tech Stack:** Lua on KOReader's LuaJIT; Busted unit specs run by `bin/check <spec>` from the emulator at `KOPANDA_EMULATOR`; `spec/plugin_harness.lua` (`harness.show_fm()`, `harness.open_reader()`, `harness.top(n)`, `harness.tick(n)`, `harness.stack()`).

Design: `docs/plans/2026-10-18-menu-quick-settings-design.md`. Mocks beside it.

Read first: `kopanda.koplugin/menu_entries.lua` (whole, 90 lines), `kopanda.koplugin/main.lua:405-490` (`addToMainMenu`), `kopanda.koplugin/quick_settings.lua:443-459` (`open`), `kopanda.koplugin/sheet.lua:125-140` and `:210-230` (`beneath`), `spec/unit/entry_points_spec.lua` (the Home-tab tests: the patterns to copy), `kopanda.koplugin/HOOKS.md:617-695` (the menu sections).

KOReader facts, at the pinned build `~/Projects/kodev/koreader/` (cite these in HOOKS.md):

- The reader builds its tab table once and caches it: `frontend/apps/reader/modules/readermenu.lua:396-400` (`onShowMenu` calls `setUpdateItemTable` only when `tab_item_table` is nil), `:330-340` (each registered widget's `addToMainMenu` is pcalled inside that build, then `MenuSorter:mergeAndSort("reader", self.menu_items, order)` against the require-cached `ui/elements/reader_menu_order`).
- The reader's default tabs: `readermenu.lua:55-80` (`getDefaultMenuButtons`; the file-browser tab at `:65-74` is `{ icon, remember = false, callback }`, the shape to copy). The order's buttons: `frontend/ui/elements/reader_menu_order.lua:4-12`; its empty file-browser entry `:228` (`filemanager = {}`).
- The reader's remembered tab is per book: `readermenu.lua:548` (read from the document's settings as `readermenu_tab_index`), `:551-553` (saved on close). Appending a tab shifts nothing.
- Closing the reader menu: `readermenu.lua:445-451` (`onCloseReaderMenu`), `:517-520` (`onTapCloseMenu`, which also closes the bottom config menu). Closing the file browser's: `frontend/apps/filemanager/filemanagermenu.lua:1049-1056` (`onCloseFileManagerMenu`), already cited.
- The far-right tab is what a menu swipe starting in the right third opens: `readermenu.lua:470-482` (`_getTabIndexFromLocation`), `filemanagermenu.lua:1083-1100` (already cited).
- The icon: `resources/icons/mdlight/appbar.contrast.svg`, resolved by name through `frontend/ui/widget/iconwidget.lua:19-30` (`ICONS_DIRS`: a user `icons/` folder under the settings directory when it exists at launch, then KOReader's own) and `:58-83` (lookup and cache).
- A user's own reader order file is `settings/reader_menu_order.lua`, read by `MenuSorter:readMSSettings("reader")` (`frontend/ui/menusorter.lua:22-32`, already cited for the file browser).

Running specs: `bin/check spec/unit/<name>_spec.lua` (several paths allowed). Read its output through a filter that keeps only the summary and failures, for example `bin/check spec/unit/x_spec.lua 2>&1 | grep -E "FAILED|PASSED|tests from|Error|error|expected|assert" | head -60`. `bin/check --lint` runs luacheck alone. The full unit gate is `bin/check --unit`.

Rules: TDD, each test written and seen failing before its code. No `git add -A`. Don't commit: the lead presents the diff to the owner. Keep the change minimal; mention anything you notice outside scope instead of fixing it.

---

### Task 1: generalise `menu_entries.lua` to a tab spec, Home tab unchanged

**Files:**
- Modify: `kopanda.koplugin/menu_entries.lua`
- Test: `spec/unit/entry_points_spec.lua` (existing; must keep passing)

**Step 1: Run the existing Home-tab specs to see them green before touching anything**

Run: `bin/check spec/unit/entry_points_spec.lua spec/unit/guards_spec.lua`
Expected: PASSED.

**Step 2: Rewrite `menu_entries.lua` around a spec**

Replace the module body so every function takes a spec. Keep the comments' citations. The shape:

```lua
local MenuSorter = require("ui/menusorter")
local State = require("state")
local logger = require("logger")

local MenuEntries = {}

local BUTTONS = "KOMenu:menu_buttons"

-- The tabs the plugin adds to KOReader's top menus. order is the require-cached order module
-- the menu is sorted against; menu is the MenuSorter name whose user file may override it; at
-- is the index the tab is inserted at, or "last". Only an index shifts a saved tab index.
local TABS = {
    home = {
        id = "kopanda_home", what = "the Home tab",
        order = "ui/elements/filemanager_menu_order", menu = "filemanager", at = 2,
    },
    filemanager_quick_settings = {
        id = "kopanda_quick_settings", what = "the Quick settings tab",
        order = "ui/elements/filemanager_menu_order", menu = "filemanager", at = "last",
    },
    reader_quick_settings = {
        id = "kopanda_quick_settings", what = "the Quick settings tab",
        order = "ui/elements/reader_menu_order", menu = "reader", at = "last",
    },
}
```

Then `contains`, `ensure_order_entry(order, id)`, `tab_allowed(order, user_buttons, id)`, `insert_tab(order, tab)` (index 2 → `table.insert(buttons, 2, id)`; "last" → `table.insert(buttons, id)`; both only when absent) and `shift_saved_tab_index()` unchanged in behaviour but only called for `tab.at == 2`. The public function:

```lua
-- Readies the cached order for the named tab and returns true when the menu gets it. ...
function MenuEntries.tab(name)
    local tab = assert(TABS[name], "no such tab: " .. tostring(name))
    local ok, result = pcall(function()
        local order = require(tab.order)
        local user_buttons = MenuSorter:readMSSettings(tab.menu)[BUTTONS]
        if user_buttons then
            return tab_allowed(order, user_buttons, tab.id)
        end
        insert_tab(order, tab)
        if tab.at ~= "last" then
            shift_saved_tab_index()
        end
        return true
    end)
    if not ok then
        logger.err("KoPanda: could not add " .. tab.what .. ":", result)
        return false
    end
    return result
end

-- The Home tab, index 2 of the file browser's menu.
function MenuEntries.home_tab()
    return MenuEntries.tab("home")
end
```

Keep the existing comment blocks (the index-2 reasoning, the saved-index shift) with their citations; add to the top comment that the reader's order is `frontend/ui/elements/reader_menu_order.lua` sorted at `readermenu.lua:330-340`.

**Step 3: Run the existing specs again**

Run: `bin/check spec/unit/entry_points_spec.lua spec/unit/guards_spec.lua spec/unit/failsafe_spec.lua`
Expected: PASSED, unchanged.

### Task 2: the tab in both menus (placement)

**Files:**
- Create: `spec/unit/quick_settings_tab_spec.lua`
- Modify: `kopanda.koplugin/main.lua:436-490` (`addToMainMenu`)

**Step 1: Write the failing placement tests**

```lua
-- The quick-settings tab in KOReader's top menus (design: docs/plans/2026-10-18-menu-quick-
-- settings-design.md): last in the file browser's and the reader's tab bar, opening the sheet.
describe("the quick-settings tab", function()
    local harness = require("plugin_harness")
    local DataStorage = require("datastorage")
    local UIManager = require("ui/uimanager")
    local Sheet, QuickSettings, Home

    local function find(list, id)
        for index, item in ipairs(list) do
            if item.id == id then
                return item, index
            end
        end
    end

    local function last(list)
        return list[#list]
    end

    -- Writes the user's own settings/<menu>_menu_order.lua naming these top-level tabs.
    local function write_user_order(menu, buttons)
        local path = DataStorage:getSettingsDir() .. "/" .. menu .. "_menu_order.lua"
        local f = assert(io.open(path, "w"))
        f:write("return {\n  [\"KOMenu:menu_buttons\"] = {\n")
        for _, id in ipairs(buttons) do
            f:write(string.format("    %q,\n", id))
        end
        f:write("  },\n}\n")
        f:close()
        return path
    end

    local function read(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local text = f:read("*a")
        f:close()
        return text
    end

    before_each(function()
        harness.load()
        Sheet = require("sheet")
        QuickSettings = require("quick_settings")
        Home = require("home")
    end)

    after_each(function()
        harness.teardown()
    end)

    describe("placement", function()
        it("is last in the file browser's menu, the Home tab still second", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            local tabs = fm.menu.tab_item_table
            local tab = last(tabs)
            assert.equals("kopanda_quick_settings", tab.id)
            assert.equals("appbar.contrast", tab.icon)
            assert.is_false(tab.remember)
            assert.equals("kopanda_home", tabs[2].id)
            assert.same({}, require("ui/elements/filemanager_menu_order").kopanda_quick_settings)
            local buttons = require("ui/elements/filemanager_menu_order")["KOMenu:menu_buttons"]
            assert.equals("kopanda_quick_settings", last(buttons))
        end)

        it("is last in the reader's menu, with no Home tab", function()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            local tabs = reader.menu.tab_item_table
            local tab = last(tabs)
            assert.equals("kopanda_quick_settings", tab.id)
            assert.equals("appbar.contrast", tab.icon)
            assert.is_false(tab.remember)
            assert.is_nil(find(tabs, "kopanda_home"))
            assert.same({}, require("ui/elements/reader_menu_order").kopanda_quick_settings)
            assert.equals("kopanda_quick_settings", last(require("ui/elements/reader_menu_order")["KOMenu:menu_buttons"]))
        end)

        it("is inserted once across menu builds", function()
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            fm.menu:onCloseFileManagerMenu()
            fm.menu:onShowMenu()
            local buttons = require("ui/elements/filemanager_menu_order")["KOMenu:menu_buttons"]
            local count = 0
            for _, id in ipairs(buttons) do
                if id == "kopanda_quick_settings" then count = count + 1 end
            end
            assert.equals(1, count)
        end)
    end)
end)
```

**Step 2: Run it to see it fail**

Run: `bin/check spec/unit/quick_settings_tab_spec.lua`
Expected: FAIL, `kopanda_quick_settings` not the last tab (the last is `main`).

**Step 3: Add the item in `addToMainMenu`**

In `main.lua`, after the Home-tab block and before `menu_items.kopanda = {...}`:

```lua
    -- The quick-settings tab, last in both menus (docs/plans/2026-10-18-menu-quick-settings-
    -- design.md): the shape of the reader's file-browser tab (readermenu.lua:65-74). Its callback
    -- closes the menu, then opens the sheet; in the reader nothing lies beneath the sheet to
    -- close on failure, so the page stays.
    local app = self.in_fm and "filemanager" or "reader"
    if MenuEntries.tab(app .. "_quick_settings") then
        menu_items.kopanda_quick_settings = {
            icon = "appbar.contrast",
            remember = false,
            callback = guarded("the Quick settings tab", function()
                local started = PaintClock.now()
                if self.in_fm then
                    self.ui.menu:onCloseFileManagerMenu()
                else
                    self.ui.menu:onTapCloseMenu()
                end
                require("quick_settings").open{
                    started = started,
                    beneath = not self.in_fm and { close = function() end } or nil,
                }
            end),
        }
    end
```

Check `main.lua`'s requires: add `local PaintClock = require("paint_clock")` if absent (`nav_bar.lua` shows the use). `quick_settings` is required at load by `main.lua:67` already, so `require` here is a cache hit; keep it a call-time require as the nav bar does.

**Step 4: Run the spec**

Run: `bin/check spec/unit/quick_settings_tab_spec.lua`
Expected: PASSED (3 tests).

**Step 5: Lint**

Run: `bin/check --lint`
Expected: 0 warnings, 0 errors.

### Task 3: the tap opens the sheet, in both apps

**Files:**
- Modify: `spec/unit/quick_settings_tab_spec.lua`
- Modify: `kopanda.koplugin/main.lua` only if a test fails

**Step 1: Add the failing behaviour tests**

Inside the describe, a new block:

```lua
    describe("the tap", function()
        local function sheets_on_stack()
            local count = 0
            for _, widget in ipairs(harness.stack()) do
                if widget.name == "kopanda_sheet" then count = count + 1 end
            end
            return count
        end

        it("closes the file browser's menu and opens the sheet over the home", function()
            local fm = harness.show_fm()
            harness.tick(2)
            local home = Home.shown
            fm.menu:onShowMenu()
            last(fm.menu.tab_item_table).callback()
            harness.tick(3)
            assert.is_nil(fm.menu.menu_container)
            local sheet = Sheet.shown
            assert.equals("quick_settings", sheet.spec.name)
            assert.equals(sheet, harness.top())
            assert.equals(home, harness.top(2))
            assert.equals(1, sheets_on_stack())
        end)

        it("closes the reader's menu and opens the sheet over the page", function()
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            last(reader.menu.tab_item_table).callback()
            harness.tick(3)
            assert.is_nil(reader.menu.menu_container)
            local sheet = Sheet.shown
            assert.equals("quick_settings", sheet.spec.name)
            assert.equals(sheet, harness.top())
            assert.equals(reader, harness.top(2))
            assert.equals(1, sheets_on_stack())
            assert.is_nil(Home.shown)
        end)

        it("leaves the page when the sheet fails in the reader", function()
            local reader = harness.open_reader()
            local original = QuickSettings.body
            QuickSettings.body = function() error("boom") end
            finally(function() QuickSettings.body = original end)
            reader.menu:onShowMenu()
            last(reader.menu.tab_item_table).callback()
            harness.tick(3)
            assert.is_nil(Sheet.shown)
            assert.equals(0, sheets_on_stack())
            assert.equals(reader, harness.top())
            assert.is_true(UIManager:isWidgetShown(reader))
        end)

        it("logs and leaves the menu usable when the opener raises", function()
            local reader = harness.open_reader()
            local logger = require("logger")
            local errors = {}
            local original = logger.err
            logger.err = function(...) errors[#errors + 1] = table.concat({ ... }, " ") end
            finally(function() logger.err = original end)
            local open = QuickSettings.open
            QuickSettings.open = function() error("no sheet") end
            finally(function() QuickSettings.open = open end)
            reader.menu:onShowMenu()
            last(reader.menu.tab_item_table).callback()
            harness.tick(3)
            assert.equals(0, sheets_on_stack())
            assert.equals(reader, harness.top())
            assert.truthy(#errors >= 1)
            assert.truthy(errors[1]:find("the Quick settings tab", 1, true))
            reader.menu:onShowMenu()
            assert.is_table(reader.menu.menu_container)
        end)
    end)
```

Check how `guarded` in `main.lua` logs (read `main.lua` for its definition) and make the log assertion match its exact prefix. If `QuickSettings.body` isn't what the sheet calls at layout, read `quick_settings.lua:443-459` and `sheet.lua`'s `lay_out` and stub what is actually called, the goal being a failure inside the sheet's own show path.

**Step 2: Run, expect the behaviour tests to fail or pass**

Run: `bin/check spec/unit/quick_settings_tab_spec.lua`
Expected: the sheet tests pass if Task 2's callback is right; a failure here is a real finding, fix `main.lua` minimally. Report which tests were red before the fix.

### Task 4: a user's own order, the saved indexes, the refused plugin

**Files:**
- Modify: `spec/unit/quick_settings_tab_spec.lua`
- Modify: `spec/unit/guards_spec.lua:143-174` (one assertion each for both menus)

**Step 1: Add the tests**

```lua
    describe("a user's own menu order", function()
        it("gets no tab in the reader when the user's file leaves it out, and the file is untouched", function()
            local path = write_user_order("reader", { "navi", "typeset", "setting", "tools", "search", "filemanager", "main" })
            local before = read(path)
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            assert.is_nil(find(reader.menu.tab_item_table, "kopanda_quick_settings"))
            assert.equals(before, read(path))
        end)

        it("places the tab where the user's reader file names it", function()
            write_user_order("reader", { "navi", "kopanda_quick_settings", "typeset", "setting", "tools", "search", "filemanager", "main" })
            local reader = harness.open_reader()
            reader.menu:onShowMenu()
            assert.equals("kopanda_quick_settings", reader.menu.tab_item_table[2].id)
        end)

        it("gets no tab in the file browser when the user's file leaves it out", function()
            write_user_order("filemanager", { "filemanager_settings", "kopanda_home", "setting", "tools", "search", "plus_menu", "main" })
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.is_nil(find(fm.menu.tab_item_table, "kopanda_quick_settings"))
            assert.equals("kopanda_home", fm.menu.tab_item_table[2].id)
        end)
    end)

    describe("the saved tab index", function()
        it("is not moved by the file browser's tab", function()
            -- The Home tab's one-time shift already happened in this profile.
            require("state").set("menu_tab_shifted", true)
            G_reader_settings:saveSetting("filemanagermenu_tab_index", 5)
            local fm = harness.show_fm()
            fm.menu:onShowMenu()
            assert.equals(5, G_reader_settings:readSetting("filemanagermenu_tab_index"))
        end)

        it("is not moved by the reader's tab", function()
            local reader = harness.open_reader()
            reader.menu.last_tab_index = 3
            reader.menu:onShowMenu()
            reader.menu:onCloseReaderMenu()
            assert.equals(3, reader.ui.doc_settings:readSetting("readermenu_tab_index"))
        end)
    end)
```

Read `spec/plugin_harness.lua:106-118` (`open_reader`) and `harness.state_dir` to confirm how state is written; `require("state").set` is the plugin's `State.set(key, value)`, check its signature in `kopanda.koplugin/state.lua`. For the reader's index, read `readermenu.lua:396-420` to see what `onShowMenu` does with `last_tab_index` and adjust the assertion so it tests that the plugin's tab did not move the index (3 in, 3 out).

In `guards_spec.lua`'s test "adds no Home tab or action, and nothing but Studio and Swatches to Tools", add after the `ids` assertions `assert.is_false(contains(ids, "kopanda_quick_settings"))` and after the reader's menu is shown `assert.is_nil(find-by-id over reader.menu.tab_item_table for "kopanda_quick_settings")` (write a tiny `find` there if the spec has none).

**Step 2: Run**

Run: `bin/check spec/unit/quick_settings_tab_spec.lua spec/unit/guards_spec.lua`
Expected: PASSED. The refused-plugin assertions pass already because `addToMainMenu` returns before the tab block; the user-order tests pass through `tab_allowed`. Any red is a finding; fix minimally and report it.

### Task 5: HOOKS.md and the full unit gate

**Files:**
- Modify: `kopanda.koplugin/HOOKS.md:617-695`
- Test: `spec/unit/hooks_doc_spec.lua`

**Step 1: Document the surfaces**

- Under "The cached menu order": add that `ui/elements/reader_menu_order` is sorted against at `readermenu.lua:330-340`, once, cached (`:396-400`), that `kopanda_quick_settings` is appended to `KOMenu:menu_buttons` of both orders with an empty entry, and the far-right swipe consequence (`readermenu.lua:470-482`).
- Under "`ui/menusorter`": the reader's file `settings/reader_menu_order.lua`, `MenuSorter:readMSSettings("reader")`.
- Under "`filemanagermenu_tab_index`": appending shifts nothing; the reader's `readermenu_tab_index` is per book (`readermenu.lua:548`, `:551-553`), untouched.
- Under "`TouchMenu` tab callbacks": the quick-settings tab `{ icon = "appbar.contrast", remember = false, callback }`, the icon resolved by `iconwidget.lua:19-30`, `:58-83`; its callback closes the reader menu with `onTapCloseMenu` (`readermenu.lua:517-520`) or the file browser's with `onCloseFileManagerMenu`, then opens the sheet with a no-op `beneath` in the reader.

**Step 2: Run the doc spec, then the whole unit gate**

Run: `bin/check spec/unit/hooks_doc_spec.lua`
Expected: PASSED.

Run: `bin/check --unit`
Expected: PASSED through luacheck, the studio's check and every unit spec. Report the summary lines.

**Step 3: The sheet's emulator golden, since the sheet module changed its call path**

Run: `bin/check spec/emulator/quick_settings_golden_spec.lua`
Expected: PASSED, 0 px difference.

### Task 6 (lead only): the design doc's out-of-scope line

`.tiller/design/2026-10-13-kopanda-design.md:141-142`: add "except a quick-settings tab in the reader's top menu (docs/plans/2026-10-18-menu-quick-settings-design.md)". The lead does this and tells the owner that Tiller may report design drift for it.
