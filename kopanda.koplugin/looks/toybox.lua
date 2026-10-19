-- Toybox: chunky toy blocks, rounded paper blocks standing on a solid ink edge, the colour kept to
-- round badges, and a floating pill nav. Pure data, typed from the design's token table and Lua
-- export (.tiller/design/2026-10-19-kopanda-looks/toybox.md) and its boards in the design file
-- (`KoPanda Looks.dc.html` beside it, cited "Looks.dc.html:<line>"); where neither gives a value,
-- the line's comment says "no board" and names the analogy. Diner (looks/diner.lua), Editorial
-- (looks/editorial.lua) and Riso (looks/riso.lua) declare the same paths.
--
-- Sizes are board pixels (the canvas's half size), scaled at draw time by Screen:scaleBySize;
-- font sizes go to Font:getFace unscaled. Colours are #rrggbb in the palettes only; every other
-- token names a colour by its palette role. false is a token this look doesn't have.
return {
    -- toybox.md: Baloo 2 800, Nunito 700 and 800, Nunito 600 italic for the quote, no accent face.
    faces = {
        display = { file = "fonts/baloo-2/Baloo2-ExtraBold.ttf", label = "Baloo 2 800" }, -- toybox.md
        text = { file = "fonts/nunito/Nunito-Bold.ttf", label = "Nunito 700" }, -- toybox.md: text 700
        accent = { file = false, label = false }, -- toybox.md: accent face none
        strong = { file = "fonts/nunito/Nunito-ExtraBold.ttf", label = "Nunito 800" }, -- toybox.md: bold 800
        quote = { file = "fonts/nunito/Nunito-SemiBoldItalic.ttf", label = "Nunito 600 italic" }, -- toybox.md
    },

    -- The icon set the look draws with: a set id under icons/, or false for the registry's
    -- default Lucide set.
    icons = {
        set = "mingcute-line", -- toybox.md: MingCute Line, chosen first
    },

    -- toybox.md's export palettes: its hairLight is hairline_light, its a1, a2 and a3 the sun,
    -- coral and mint, its die the nav pill's white. Structure and the block edge are the ink, so
    -- outline, shadow, on_band and on_accent are the ink, and the band is the mint (the sheet's
    -- header band, toybox.md "Band"). Its card is its paper by day and in grey; the night card
    -- (#24232e) has no part here that draws it.
    palettes = {
        day = {
            paper = "#fbf5ec", -- toybox.md
            ink = "#2b2934", -- toybox.md
            muted = "#5b5867", -- toybox.md
            text = "#2b2934", -- toybox.md: text is the ink
            hairline = false, -- toybox.md has one rule colour, hairline_light
            hairline_light = "#e7ddcd", -- toybox.md: the sheet's row rules
            teal = false, -- Diner's accent; Toybox has none
            pink = false, -- Diner's and Riso's accent; Toybox has none
            mustard = false, -- Diner's accent; Toybox has none
            violet = false, -- Frosted's accent; Toybox has none
            yellow = false, -- Frosted's accent; Toybox has none
            tint = false, -- Riso's tint; Toybox has none
            sun = "#ffc94a", -- toybox.md: a1
            coral = "#ff8f75", -- toybox.md: a2
            mint = "#86d3b4", -- toybox.md: a3
            die = "#ffffff", -- toybox.md: the floating nav's white
            band = "#86d3b4", -- toybox.md: the mint band on the sheet
            outline = "#2b2934", -- toybox.md: 3 px ink blocks
            shadow = "#2b2934", -- toybox.md: the solid ink edge
            on_band = "#2b2934", -- no board: the ink on the mint band (Looks.dc.html:724)
            on_accent = "#2b2934", -- toybox.md: chips are ink on mint
            -- No board draws a typographic cover: a solid block of the ink, paper text on it.
            cover = "#2b2934",
            on_cover = "#fbf5ec", -- no board: the paper, as above
        },
        night = {
            paper = "#1e1d26", -- toybox.md
            ink = "#f4f0ea", -- toybox.md
            muted = "#b4b1c0", -- toybox.md
            text = "#f4f0ea", -- toybox.md
            hairline = false, -- as by day
            hairline_light = "#383645", -- toybox.md
            teal = false, -- as by day
            pink = false, -- as by day
            mustard = false, -- as by day
            violet = false, -- Frosted's accent; Toybox has none
            yellow = false, -- Frosted's accent; Toybox has none
            tint = false, -- as by day
            sun = "#8a6a12", -- toybox.md
            coral = "#a2493a", -- toybox.md
            mint = "#2f7a5c", -- toybox.md
            die = "#282733", -- toybox.md
            band = "#2f7a5c", -- toybox.md: the mint
            outline = "#f4f0ea", -- toybox.md: structure is the ink
            shadow = "#f4f0ea", -- toybox.md: the edge is the ink
            on_band = "#f4f0ea", -- no board: the night ink on the night mint
            on_accent = "#f4f0ea", -- no board: the night ink on the night mint
            cover = "#2b2934", -- no board: the day's ink block, as Diner keeps its cover by night
            on_cover = "#fbf5ec", -- no board: the day's paper on it
        },
        grey = {
            paper = "#ffffff", -- toybox.md
            ink = "#000000", -- toybox.md
            muted = "#333333", -- toybox.md
            text = "#000000", -- toybox.md
            hairline = false, -- as by day
            hairline_light = "#cccccc", -- toybox.md
            teal = false, -- as by day
            pink = false, -- as by day
            mustard = false, -- as by day
            violet = false, -- Frosted's accent; Toybox has none
            yellow = false, -- Frosted's accent; Toybox has none
            tint = false, -- as by day
            sun = "#dddddd", -- toybox.md
            coral = "#999999", -- toybox.md: a2, hatched where it fills a bar (progress.fill_grey)
            mint = "#bbbbbb", -- toybox.md
            -- toybox.md's grey die is #ffffff, the grey paper; none, so the pill shows the paper and
            -- the roles that differ by day stay apart in grey.
            die = false,
            band = "#bbbbbb", -- toybox.md: the mint
            outline = "#000000", -- toybox.md: structure is the ink
            shadow = "#000000", -- toybox.md: the edge is the ink
            on_band = "#000000", -- no board: the ink on the grey mint
            on_accent = "#000000", -- no board: the ink on the grey mint
            cover = "#4a4a4a", -- no board: the direction doc's cover grey, as Diner's and Editorial's
            on_cover = "#ffffff", -- no board: the paper on it
        },
    },

    -- toybox.md: 3 px ink blocks, cover, progress and nav, 2 px hairlines.
    stroke = {
        hairline = 2, -- toybox.md: stroke.hair
        hairline_grey = 2, -- toybox.md: stroke.greyHair
        rule = 3, -- toybox.md: stroke.rule
        outline = 3, -- toybox.md: 3 px ink blocks, cover and progress
        band = false, -- toybox.md: no header band on the home
    },

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide. toybox.md:
    -- a solid block edge, ink 0 right 6 down under the tiles and the cover, 8 under the sheet.
    shadow = {
        cover = { x = 0, y = 6, color = "shadow", outline_width = false }, -- toybox.md: cover.shadow
        tile = { x = 0, y = 6, color = "shadow", outline_width = false }, -- toybox.md: tile.edge 6
        sheet = { x = 0, y = 8, color = "shadow", outline_width = false }, -- toybox.md: sheet.under
    },

    -- toybox.md: misregister none, display type printed once.
    misregister = { x = 0, y = 0, color = false }, -- toybox.md: misregister none

    -- The plates Frosted sets its home rows on (looks/frosted.lua): Toybox has none, so its rows
    -- sit on the page as before plates (fill_color false skips them in layout.lua and
    -- home_rows.lua), with no padding round a widget and nothing lightened.
    plate = {
        fill_color = false, -- no plates
        keyline = 0, -- no plates
        keyline_color = false, -- no plates
        radius = 0, -- no plates
        lighten = { day = false, night = false, grey = false }, -- no plates, nothing lightened
        slots = {
            date = { x = 0, y = 0, radius = 0 }, -- no plates: the widget at its slot's edge
            clock = { x = 0, y = 0, radius = 0 }, -- no plates
            weather = { x = 0, y = 0, radius = 0 }, -- no plates
            stats = { x = 0, y = 0, radius = 0 }, -- no plates
            quote = { x = 0, y = 0, radius = 0 }, -- no plates
            featured = { x = 0, y = 0, radius = 0 }, -- no plates
            launcher = false, -- the launcher's tiles are its own
        },
    },

    -- The owner's image behind the home (wallpaper.file): Frosted's alone; Toybox draws its paper.
    wallpaper = {
        enabled = false, -- the paper, as before the wallpaper setting
    },

    radius = {
        cover = 6, -- toybox.md: cover.radius
        box = 18, -- toybox.md: tile.radius, the launcher's blocks
    },

    -- toybox.md: a paper block in a 3 px ink outline on its ink edge (shadow.tile), rounded 18.
    tile = {
        box = true, -- toybox.md: tile.style block
        fill_color = "paper", -- toybox.md: tile.fill paper
        outline_color = "outline", -- toybox.md: tile.borderColor ink
        rule_color = false, -- boxed, not ruled
    },

    -- toybox.md: an 18 px pill in a 3 px ink outline, coral on paper; in grey a 135° hatch.
    progress = {
        -- The 18 px pill less its 3 px outline above and below: the board's bar is border-box
        -- (Looks.dc.html:664).
        height = 12,
        fill_color = "coral", -- toybox.md: progress.fill a2
        track_color = "paper", -- toybox.md: progress.track
        outline_color = "outline", -- toybox.md: progress.outlineColor ink
        outline_width = 3, -- toybox.md: progress.outline
        fill_grey = "hatch_135", -- no board: Diner's and Riso's grey fill, a 135° hatch
        radius = 999, -- toybox.md: progress.radius, round ends
    },

    -- toybox.md: inset 16, a 3 px ink outline rounded 24 on an 8 px ink edge (shadow.sheet), a mint
    -- header band under a 2 px ink rule, rows ruled in the hairline.
    sheet = {
        fill_color = "paper", -- toybox.md: card is the paper (Looks.dc.html:720)
        rule_color = false, -- toybox.md: an outlined inset box, not a panel under a rule
        rule_width = 0, -- as above
        outline_color = "outline", -- toybox.md: sheet.border ink
        outline_width = 3, -- toybox.md: sheet.border 3
        header_band = true, -- toybox.md: sheet.band a3
        inset = { side = 16, bottom = 16 }, -- toybox.md: sheet.inset (Looks.dc.html:715)
        -- Looks.dc.html:720, the head spanning the box (:724). The board's foot is 8; 10 ends a lit
        -- last row's fill 13 px above the box's foot, inside the 24 px corners' outer curve (12.4 at
        -- the 3 px outline), so no sun shows in their ring.
        padding = { top = 0, side = 0, bottom = 10 },
        book_band_color = "mint", -- toybox.md: sheet.band a3
        home_band_color = "mint", -- no board: the book sheet's band
        folder_band_color = "mint", -- no board: the book sheet's band
        quick_settings_band_color = "mint", -- no board: the book sheet's band
        header_rule_color = "outline", -- Looks.dc.html:724, the head's ink border
        header_rule_width = 2, -- Looks.dc.html:724, 2 px for an inset sheet
        header_padding = { top = 18, side = 20, bottom = 16 }, -- Looks.dc.html:724
        book_header_padding = { top = 18, side = 20, bottom = 16 }, -- Looks.dc.html:724
        cover_gap = 16, -- Looks.dc.html:724, the head's gap
        cover_w = 64, -- Looks.dc.html:725
        cover_h = 96, -- Looks.dc.html:725
        line_gap = 6, -- Looks.dc.html:727, the meta column's gap
        meta_gap = 4, -- Looks.dc.html:730, the progress row's margin
        aside_gap = 12, -- no board: Diner's and Editorial's
        -- Looks.dc.html:735: 48 px rows, a 22 px icon and a 2 px rule, the content centred.
        row_padding = { x = 20, y = 12 },
        row_gap = 14, -- no board: Diner's
        icon_size = 22, -- no board: Diner's and Editorial's
        row_rule_color = "hairline_light", -- toybox.md: sheet.rowRule hairLight
        row_rule_width = 2, -- Looks.dc.html:735, the look's hairline (stroke.hairline)
        -- no board: row_padding.y and the box's 10 px foot below (padding.bottom), so a lit last row
        -- clears the 24 px corners.
        last_row_bottom = 12,
        status_chip_color = "mint", -- toybox.md: chips are a mint fill
        state_chip_color = "mint", -- toybox.md: chips are a mint fill
        chip_padding = { x = 11, y = 4 }, -- Looks.dc.html:659, a round chip's padding
        chip_outline_width = 2, -- toybox.md: chip.border 2
        selected_fill_color = "sun", -- no board: the lit nav tab's sun (toybox.md nav.litColor a1)
        aside_above_gap = 2, -- no board: Diner's (SortC.dc.html:39)
        sublabel_gap = 2, -- no board: Diner's (SortC.dc.html:46)
        library_folder_band_color = "mint", -- no board: the book sheet's band
        folder_box = {
            size = 60, -- no board: Diner's (HoldFolderC.dc.html:36)
            outline_width = 3, -- no board: the block's 3 px ink outline (toybox.md)
            outline_color = "outline", -- no board: the block's ink outline
            fill_color = "paper", -- no board: on paper, as the block
            icon_size = 34, -- no board: Diner's (HoldFolderC.dc.html:37)
            icon_color = "ink", -- no board: toybox.md's icons are ink
        },
        library_empty_band_color = "mint", -- no board: the book sheet's band
        sort_chip_color = "mint", -- no board: toybox.md's chips are a mint fill
        show_chip_color = "mint", -- no board: toybox.md's chips are a mint fill
        radius = 24, -- toybox.md: sheet.radius
    },

    -- The quick-settings sheet's body. No board draws Toybox's: the sheet's rows and hairline
    -- rules, its progress pill for the levels, the pickers' 2 px ink outline for the buttons, the
    -- block's 3 px ink outline for the tiles, and the on tile filled sun with ink text as the lit
    -- nav tab; the rest Diner's and Editorial's.
    quick_settings = {
        padding_x = 20, -- no board: the sheet's row_padding.x
        first_section_padding = { top = 15, bottom = 15 }, -- no board: Diner's
        section_padding = { top = 15, bottom = 15 }, -- no board: Diner's
        section_gap = 10, -- no board: Editorial's (QuickSettings.dc.html:40)
        section_rule_width = 2, -- no board: the sheet's row_rule_width
        section_rule_color = "hairline_light", -- no board: the sheet's row_rule_color
        control_gap = 12, -- no board: Editorial's (QuickSettings.dc.html:44)
        button_w = 44, -- no board: Editorial's (QuickSettings.dc.html:45)
        button_h = 36, -- no board: Editorial's (QuickSettings.dc.html:45)
        button_outline_width = 2, -- no board: toybox.md's picker border
        button_outline_color = "outline", -- no board: toybox.md's picker border ink
        button_fill_color = "paper", -- no board: toybox.md's picker fill
        level_h = 12, -- no board: progress.height
        level_outline_width = 3, -- no board: progress.outline_width
        level_outline_color = "outline", -- no board: progress.outline_color
        level_fill_color = "coral", -- no board: progress.fill_color
        level_track_color = "paper", -- no board: progress.track_color
        grid_gap = 10, -- no board: Editorial's (QuickSettings.dc.html:62)
        grid_padding = { top = 15, bottom = 20 }, -- no board: Diner's
        cell_padding = { top = 14, bottom = 12 }, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_gap = 8, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_icon_size = 24, -- no board: toybox.md's icon size
        cell_outline_width = 3, -- no board: the block's outline
        cell_outline_color = "outline", -- no board: the block's ink outline
        cell_fill_color = "paper", -- no board: the sheet's fill_color
        on_fill_color = "sun", -- no board: the lit nav tab's fill (toybox.md nav.litColor a1)
        on_text_color = "ink", -- no board: ink on the sun
    },

    -- toybox.md: a mint pill, ink uppercase 800, a 2 px ink border.
    chip = {
        small_caps = false, -- toybox.md: label.case upper
        uppercase = true, -- toybox.md: label.case upper
        text_color = "ink", -- toybox.md: chip.color ink
        fill_color = "mint", -- toybox.md: chip.fill a3
        outline_color = "outline", -- toybox.md: chip.borderColor ink
        radius = 999, -- toybox.md: chip.radius, a pill
    },

    -- toybox.md: 11 px uppercase 800, 0.1 em, muted.
    label = {
        size = 11, -- toybox.md: label.size
        face = "strong", -- toybox.md: label.weight 800
        small_caps = false, -- toybox.md: label.case upper
        uppercase = true, -- toybox.md: label.case upper
        tracking = 0.1, -- toybox.md: label.tracking
    },

    -- The home's page (Looks.dc.html:607, :641-697): its margins, the gaps between rows and between
    -- columns, where the free height goes, the header drawn with row 1 and the footer.
    home = {
        -- The body's padding, 36 above and 40 at the sides (Looks.dc.html:607); below, the 98 px
        -- the board leaves above its foot less the floating nav's 68 and the 20 under it, so the
        -- rows stop 10 above the pill.
        margin = { top = 36, side = 40, bottom = 10 },
        row_gap = 18, -- toybox.md: bodyGap 18 (Looks.dc.html:550, :607)
        column_gap = 16, -- the header's gap (Looks.dc.html:648)
        free_space = "before_last_row", -- the stats' margin-top: auto (Looks.dc.html:697)
        -- toybox.md: no band and no rule; the slots on their bottoms (Looks.dc.html:648,
        -- align-items: flex-end).
        header = {
            band_color = false, -- toybox.md: band on the sheet only
            edge_width = 0, -- toybox.md: header.rule 0
            edge_color = false, -- toybox.md: header.ruleColor none
            rule_color = false, -- toybox.md: header.rule 0
            rule_width = 0, -- toybox.md: header.rule 0
            rule_space = 0, -- toybox.md: header.rule 0
            padding = { top = 0, side = 0, bottom = 0 }, -- Looks.dc.html:648, unpadded
            align = "bottom", -- Looks.dc.html:648
        },
        footer = {
            height = 0, -- toybox.md: no footer
            stripe_color = false, -- no footer
            gap_color = false, -- no footer
            line_width = 0, -- no footer
            line_pitch = 0, -- no footer
            edge_width = 0, -- no footer
            edge_color = false, -- no footer
        },
        weather_icon = { size = 0, gap = 0 }, -- the weather is a line of text alone (Looks.dc.html:57, :652)
        -- The weather line's order: degrees_first, "61° Partly cloudy" (Looks.dc.html:57).
        weather_order = "degrees_first",
        -- The date's lines: 1, toybox.md's 18 px 800 date, "Tuesday, October 13" (Looks.dc.html:56, :651).
        date_lines = 1,
        -- The stats joined, "3-day streak · 42 min today" (Looks.dc.html:96).
        stats_line = "joined",
        stats_streak = "count_first", -- "3-day streak" (Looks.dc.html:96)
        featured_label = "now_reading", -- "Now reading" (Looks.dc.html:66)
        -- "Mary Shelley · Letter IV" and "62% · 2 h 6 min left", each joined (Looks.dc.html:68, :71).
        featured_details = "joined",
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role. The
    -- board's 700 is the text face, its 800 the strong face; its 500 and 600 the text face too,
    -- the lightest Nunito vendored.
    type = {
        -- The weekday's label, unused while the date is one line (home.date_lines).
        date_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- toybox.md: 18 px 800, CSS line height 1.1 (Looks.dc.html:651).
        date = { face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0.1, color = "ink" },
        -- toybox.md: 100 px 800, -0.02 em, CSS line height 0.8 (Looks.dc.html:653).
        clock = {
            face = "display", size = 100, uppercase = false, tracking = -0.02, line_height = -0.2, color = "ink",
        },
        -- 14 px Nunito in the text colour (Looks.dc.html:652).
        weather = { face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text" },
        -- toybox.md: 18 px Nunito 600 italic, CSS line height 1.35, ink (Looks.dc.html:669).
        quote = { face = "quote", size = 18, uppercase = false, tracking = 0, line_height = 0.35, color = "ink" },
        -- The look's label at 12 px in the text colour (Looks.dc.html:697).
        stats = { face = "strong", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "text" },
        -- No board draws a typographic cover: Diner's sizes in the display face on the ink block.
        cover_title = {
            face = "display", size = 24, uppercase = true, tracking = 0.04, line_height = 0.05, color = "on_cover",
        },
        -- no board: Diner's authors line in the strong face
        cover_authors = {
            face = "strong", size = 10, uppercase = true, tracking = 0.1, line_height = 0, color = "on_cover",
        },
        -- no board: the look's label in the first run's dashed frame
        cover_empty = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- "Now reading" in its chip: the label, ink; a boxed chip's 700 (Looks.dc.html:659).
        featured_label = {
            face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- toybox.md: the title 36 px 800, -0.01 em, CSS line height 1.04 (Looks.dc.html:660).
        featured_title = {
            face = "display", size = 36, uppercase = false, tracking = -0.01, line_height = 0.04, color = "ink",
        },
        -- toybox.md: author 16 px Nunito in the text colour (Looks.dc.html:662).
        featured_authors = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- Not drawn on its own: the chapter joins the authors line (Looks.dc.html:68), in its style.
        featured_chapter = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- 14 px, weight 600, the text colour (Looks.dc.html:666).
        featured_caption = {
            face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- No board draws Toybox's first run: the title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = {
            face = "display", size = 31, uppercase = false, tracking = -0.01, line_height = 0.04, color = "ink",
        },
        -- no board: the authors line's style at Editorial's first-run line height (EmptyStates.dc.html:37)
        featured_empty_body = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0.4, color = "text",
        },
        -- no board: the look's label in ink, as the chip's
        featured_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- toybox.md: launcher 19 px Nunito 700, CSS line height 1.1 (Looks.dc.html:683).
        launcher_label = {
            face = "text", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its suffix, "Off", the look's label (Looks.dc.html:694).
        launcher_suffix = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- No board draws Toybox's home sheet: the book sheet's title (Looks.dc.html:728) on the band.
        sheet_heading = {
            face = "display", size = 26, uppercase = false, tracking = 0, line_height = 0.05, color = "on_accent",
        },
        -- no board: the look's label on the band (Looks.dc.html:733's last-opened line)
        sheet_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- The title 0.72 of 36 px, CSS line height 1.05 (Looks.dc.html:728).
        sheet_title = {
            face = "display", size = 26, uppercase = false, tracking = 0, line_height = 0.05, color = "on_accent",
        },
        -- 15 px Nunito in the text colour, the ink (Looks.dc.html:729).
        sheet_author = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- "62% · Part 3 · opened yesterday": the progress row's 13 px 700 (Looks.dc.html:730).
        sheet_meta = {
            face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- toybox.md: sheet rows 18 px Nunito, ink (Looks.dc.html:735).
        sheet_row = { face = "text", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: a row's plain detail in the look's label
        sheet_detail = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- toybox.md: a chip's label, ink on its mint
        sheet_chip = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "on_accent",
        },
        -- no board: sheet_chip in ink, for a chip on paper
        sheet_chip_plain = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- no board: the header's label at its right, the look's label
        sheet_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- no board: a row's second line, Nunito in muted
        sheet_sublabel = {
            face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted",
        },
        -- no board: a quick-settings bar's label and value, the look's label
        quick_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- no board: the bars' minus and plus, the strong face at Editorial's size (QuickSettings.dc.html:45)
        quick_button = {
            face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- no board: a quick-settings tile's label, the look's label in ink
        quick_cell = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- The editor screens have no Toybox board: the header on paper over an ink rule, its title in
        -- the display face, the rest in the look's label, at Editorial's sizes and line height 0.3.
        -- no board: the look's label at Editorial's line height
        editor_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "muted",
        },
        -- no board: Editorial's size and line height in the display face
        editor_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label in ink
        editor_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label
        editor_caption = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "muted",
        },
        -- no board: Diner's and Editorial's
        editor_box = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: Diner's and Editorial's
        editor_share = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        -- no board: Diner's and Editorial's, so six rows fit above the add-an-entry foot
        editor_label = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label
        editor_kind = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0.3, color = "muted",
        },
        -- no board: Diner's and Editorial's
        editor_note = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        -- toybox.md: nav labels 11 px, the look's label, muted unlit (Looks.dc.html:620, :622).
        nav_label = { face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted" },
        -- The lit tab's label in ink, 800 (Looks.dc.html:622).
        nav_label_active = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- No board draws Toybox's file browser: the library's (Looks.dc.html:744-749).
        -- The book count, the look's label (Looks.dc.html:747).
        title_bar_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- The library's title, 36 px, -0.01 em, CSS line height 0.95 (Looks.dc.html:746).
        title_bar_title = {
            face = "display", size = 36, uppercase = false, tracking = -0.01, line_height = -0.05, color = "ink",
        },
        -- A picker's label, ink 700 (Looks.dc.html:749).
        title_bar_sort = {
            face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- The status picker's, as the sort's (Looks.dc.html:749).
        title_bar_status = {
            face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- The library's parts (Looks.dc.html:744-790). The count, the look's label (:747).
        library_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- The title, 36 px, -0.01 em, CSS line height 0.95 (Looks.dc.html:746).
        library_title = {
            face = "display", size = 36, uppercase = false, tracking = -0.01, line_height = -0.05, color = "ink",
        },
        -- A picker's label, ink 700 (Looks.dc.html:749).
        library_picker = {
            face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- The status picker's, as the sort's (Looks.dc.html:749).
        library_picker_status = {
            face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- no board: a tile's title, one line, the text face at Diner's size and line height
        tile_title = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0.2, color = "ink",
        },
        -- The placeholder's title, 20 px, CSS line height 1.1 (Looks.dc.html:776).
        tile_cover_title = {
            face = "display", size = 20, uppercase = false, tracking = 0, line_height = 0.1, color = "on_cover",
        },
        -- A folder's book count: its name's style, 19 px 700, CSS line height 1.1 (Looks.dc.html:766).
        folder_count = {
            face = "text", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its reading count, the look's label (Looks.dc.html:747).
        folder_reading = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- no board: "Page 1 of 24", the look's label in ink
        pager_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- The series and authors screens have no Toybox board: the library's header and the home's
        -- blocks, by analogy.
        -- no board: the featured title's size, CSS line height 0.95 as the library's title
        shelf_detail_title = {
            face = "display", size = 36, uppercase = false, tracking = -0.01, line_height = -0.05, color = "ink",
        },
        -- no board: a picker's label in ink
        shelf_back = { face = "text", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "ink" },
        -- no board: the library folder's name (Looks.dc.html:766)
        series_name = {
            face = "text", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- no board: Nunito in muted
        series_sub = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- no board: a chip's label, ink on its mint
        shelf_chip = {
            face = "strong", size = 10, uppercase = true, tracking = 0.1, line_height = 0, color = "on_accent",
        },
        -- no board: a chip's label on paper
        shelf_chip_plain = {
            face = "strong", size = 10, uppercase = true, tracking = 0.1, line_height = 0, color = "ink",
        },
        -- no board: a book's series index, Diner's size in the display face
        book_index = { face = "display", size = 40, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: the library folder's name (Looks.dc.html:766)
        book_row_title = {
            face = "text", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- no board: "read this one next" in the look's label on the sun row; Toybox has no accent face
        book_next_note = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "on_accent",
        },
        -- no board: series_sub's style
        book_row_note = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- no board: a group's letter on its mint column, in the display face
        author_letter = {
            face = "display", size = 28, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- no board: Diner's
        author_name = { face = "text", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: the look's label
        author_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- no board: the look's label, as the pager's
        shelf_empty = {
            face = "strong", size = 12, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
        -- no board: the header's static label, the look's label
        shelf_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.1, line_height = 0, color = "muted",
        },
    },

    -- toybox.md: three columns of 84 px paper blocks, each with a 42 px round badge under its 22 px
    -- icon (Looks.dc.html:674-694). The board stacks the badge over the label; at KOReader's line
    -- heights the two overrun an 84 px block, so the label sits beside the badge.
    launcher = {
        columns = 3, -- toybox.md: tile.cols
        column_gap = 16, -- toybox.md: tile.gap
        row_gap = 16, -- toybox.md: tile.gap
        icon_size = 22, -- Looks.dc.html:694, the icon inside its badge
        icon_gap = 10, -- no board: the badge to the label beside it, the board's text gap (Looks.dc.html:685)
        padding = { x = 11, y = 9 }, -- Looks.dc.html:694
        tile_height = 84, -- toybox.md: tile.h
        accent_1_color = false, -- toybox.md: every block paper, the colour in its badge
        accent_2_color = false, -- toybox.md: every block paper
        accent_3_color = false, -- toybox.md: every block paper
        suffix_gap = 6, -- no board: Editorial's (EmptyStates.dc.html:65); unused while the suffix is below
        -- Under the label: "Terminal PLUGIN MISSING" doesn't fit beside a badge on one line.
        suffix_below = true,
        -- toybox.md: a 42 px round badge, a 2.5 px ink ring, filled sun, coral, mint, coral, mint,
        -- sun in tile order, then again (Looks.dc.html:544, :694).
        badge = {
            size = 42, -- Looks.dc.html:694
            outline_width = 2.5, -- Looks.dc.html:694
            outline_color = "outline", -- Looks.dc.html:694, ink
            fill_1_color = "sun", -- toybox.md: tile.fills a1
            fill_2_color = "coral", -- toybox.md: tile.fills a2
            fill_3_color = "mint", -- toybox.md: tile.fills a3
            fill_4_color = "coral", -- toybox.md: tile.fills a2
            fill_5_color = "mint", -- toybox.md: tile.fills a3
            fill_6_color = "sun", -- toybox.md: tile.fills a1
        },
    },

    -- toybox.md: quote.style plain, no rules and no tile (Looks.dc.html:668).
    quote = {
        padding = 0, -- Looks.dc.html:668, a plain quote's padding
        rule_width = 0, -- toybox.md: quote.rule 0
        -- A rule colour sets the quote between rules, of no width here, rather than in a tile.
        rule_color = "hairline_light",
    },

    -- The featured book's cover box (toybox.md: 140 × 210, a 3 px ink outline, radius 6).
    featured = {
        cover_w = 140, -- toybox.md: cover.w
        cover_h = 210, -- toybox.md: cover.h
        cover_padding = { x = 10, y = 10 }, -- the cover's padding (Looks.dc.html:639)
        cover_outline_color = "outline", -- toybox.md: cover.outlineColor ink, stroke.outline wide
        dash = 4, -- no board: Diner's and Editorial's first-run frame
        dash_gap = 4, -- no board: Diner's and Editorial's first-run frame
        gap = 24, -- Looks.dc.html:655
        column_padding_y = 2, -- the text column's top padding (Looks.dc.html:657)
        title_gap = 12, -- the chip's margin below it (Looks.dc.html:659)
        chip_outline = 2, -- toybox.md: chip.border 2
        chip_padding = { x = 11, y = 4 }, -- Looks.dc.html:659, a round chip's padding
        button_padding = { x = 14, y = 9 }, -- no board: Diner's and Editorial's (EmptyStates.dc.html:38)
        button_fill_color = "sun", -- no board: the lit nav tab's sun, a block to press
        button_outline_color = "outline", -- no board: the block's ink outline
    },
    -- The editor screens, edit layout and launcher management. No board draws Toybox's: the header
    -- on paper over a 3 px ink rule (no band, toybox.md: "mint band on the sheet only"), cards as
    -- the home's blocks in a 3 px ink outline on their ink edge, the selected card sun; spacing as
    -- Editorial's boards give it.
    editor = {
        padding = { top = 40, side = 40, bottom = 28 }, -- no board: Editorial's
        header_band_color = false, -- no board: toybox.md's band is the sheet's only
        header_text_color = false, -- no board: no band
        header_rule_color = "outline", -- no board: toybox.md's ink structure
        header_rule_width = 3, -- no board: toybox.md's 3 px strokes
        header_gap = 16, -- no board: Editorial's
        body_gap = 18, -- no board: Editorial's
        button_outline_color = "outline", -- no board: toybox.md's picker border ink
        button_outline_width = 2, -- no board: toybox.md's picker border
        button_fill_color = "paper", -- no board: toybox.md's picker fill
        button_padding = { x = 14, y = 8 }, -- no board: Editorial's
        card_gap = 12, -- no board: Diner's 10 and the block's 6 px edge less its 4, so the edge clears the next card
        card_padding = { x = 14, y = 12 }, -- no board: Editorial's
        card_outline_color = "outline", -- no board: the block's ink outline
        card_outline_width = 3, -- no board: the block's outline
        card_shadow = { x = 0, y = 6, color = "shadow" }, -- no board: the block's ink edge (shadow.tile)
        selected_outline_color = "outline", -- no board: the block's ink outline
        selected_fill_color = "sun", -- no board: the lit nav tab's sun
        arrow_size = 28, -- no board: Editorial's
        arrow_gap = 14, -- no board: Editorial's
        disabled_color = "muted", -- no board: Toybox's quietest text
        box_padding = { x = 12, y = 10 }, -- no board: Editorial's
        box_gap = 8, -- no board: Editorial's
        row_padding = { y = 14 }, -- no board: Editorial's
        row_rule_color = "hairline_light", -- no board: the sheet's row rules
        row_rule_width = 2, -- no board: the sheet's row rules
        icon_size = 22, -- no board: Editorial's
        icon_gap = 14, -- no board: Editorial's
        control_size = 30, -- no board: Editorial's
        kind_gap = 8, -- no board: Editorial's
        kind_columns = 2, -- no board: Editorial's
    },
    -- The nav bar: a white pill floating 22 px in from the sides and 20 up from the bottom, in a
    -- 3 px ink outline on a 6 px ink edge, five tabs of an icon over a label, the lit tab a sun pill
    -- in a 2 px ink outline, its icon and label ink and the rest muted (toybox.md; Looks.dc.html:608,
    -- :620).
    nav = {
        fill_color = "paper", -- the page round the floating pill (Looks.dc.html:608)
        edge_width = 3, -- toybox.md: nav.edge, the pill's outline
        edge_color = "ink", -- Looks.dc.html:608
        padding_x = 5, -- the pill's padding (Looks.dc.html:608), round the tabs on every side
        -- The pill's 68 px less its outline and padding, a lit tab's 2 px outline, the icon, the gap
        -- and the label line, shared above and below the tab's centred content (Looks.dc.html:608, :620).
        padding_top = 9,
        padding_bottom = 9, -- as padding_top
        icon_size = 24, -- toybox.md: nav_size 24
        icon_gap = 4, -- Looks.dc.html:620, a pill tab's gap
        icon_color = "muted", -- toybox.md: nav_unlit muted
        active_icon_color = "ink", -- Looks.dc.html:617
        active_rule_width = 0, -- toybox.md: nav.bar 0
        active_rule_color = false, -- toybox.md: nav.bar 0
        active_fill_color = "sun", -- toybox.md: nav.lit pill, litColor a1
        divider_width = 0, -- no dividers between tabs (Looks.dc.html:620)
        divider_color = false, -- no dividers
        float = true, -- toybox.md: nav.float, a floating pill
        margin = { side = 22, bottom = 20 }, -- Looks.dc.html:608
        radius = 999, -- toybox.md: nav.radius, the pill and its lit tab
        float_fill_color = "die", -- Looks.dc.html:608, the pill's white
        shadow = { x = 0, y = 6, color = "shadow" }, -- toybox.md: nav.float 6, the ink edge
        tab_gap = 4, -- Looks.dc.html:608, the gap between tabs
        active_outline_width = 2, -- Looks.dc.html:620, the lit pill's ink border
        active_outline_color = "outline", -- Looks.dc.html:620, ink
    },
    -- The file browser's title bar. No board draws Toybox's: the library's header (Looks.dc.html:744-749),
    -- a count and a 36 px title on paper with no rule, the pickers 2 px ink pills on paper.
    title_bar = {
        fill_color = "paper", -- no board: the library's header on paper
        padding = { top = 36, side = 40, bottom = 16 }, -- no board: the home's top margin and the sides
        edge_width = 0, -- no board: toybox.md's header.rule 0
        edge_color = false, -- no board: no edge
        line_gap = 4, -- no board: the library header's gap (Looks.dc.html:745)
        picker_gap = 8, -- no board: the library's pickers' gap (Looks.dc.html:131)
        sort_fill_color = "paper", -- no board: toybox.md's picker fill
        status_fill_color = "paper", -- no board: toybox.md's picker fill
        picker_outline_width = 2, -- no board: toybox.md's picker border
        picker_outline_color = "outline", -- no board: toybox.md's picker border ink
        picker_padding = { x = 12, y = 7 }, -- no board: Looks.dc.html:749, 2 px wider for the round ends
        icon_size = 16, -- no board draws the plus: the pickers' size
        icon_color = "ink", -- no board draws the plus: the pickers' ink
        count_on_shelf = false, -- no board: "148 books", as the library's (Looks.dc.html:129)
        picker_radius = 999, -- no board: toybox.md's picker radius, a pill
    },
    -- The library (Looks.dc.html:740-790): a 36 px title and count on paper with no rule, the
    -- pickers 2 px ink pills on paper, three columns of covers rounded 6 in a 3 px ink outline on
    -- their ink edge, a coral pill strip under each, and a pager above the nav.
    library = {
        header = {
            fill_color = false, -- the page under the header (Looks.dc.html:744)
            padding = { top = 36, side = 40, bottom = 16 }, -- the body's padding (Looks.dc.html:607)
            edge_width = 0, -- toybox.md: header.rule 0 (Looks.dc.html:744)
            edge_color = false, -- no edge
            line_gap = 4, -- Looks.dc.html:745
            picker_gap = 8, -- Looks.dc.html:131
            picker_padding = { x = 12, y = 7 }, -- Looks.dc.html:749, 2 px wider for the round ends
            picker_outline_width = 2, -- toybox.md: picker.border
            picker_outline_color = "outline", -- toybox.md: picker.borderColor ink
            sort_fill_color = "paper", -- toybox.md: picker.fill paper
            status_fill_color = "paper", -- toybox.md: picker.fill paper
            picker_radius = 999, -- toybox.md: picker.radius
        },
        grid = {
            padding_top = 28, -- the body's gap and the grid's margin (Looks.dc.html:607, :751)
            side = 40, -- Looks.dc.html:607
            row_gap = 22, -- Looks.dc.html:751
            column_gap = 20, -- Looks.dc.html:751
            cover_h = 195, -- no board: Diner's (D2), so two rows fit; the board's 255 fits one
            strip_gap = 14, -- the item's 8 px gap below the cover's 6 px edge (Looks.dc.html:752)
            title_gap = 8, -- the item's gap (Looks.dc.html:752)
        },
        -- The board's 2:3 covers fill their box (Looks.dc.html:750); at Diner's 195 a cover is fitted
        -- in its box on paper, so the box takes the cover's 3 px ink outline and its ink edge.
        cover = {
            outline_width = 3, -- toybox.md: cover.outline
            outline_color = "outline", -- toybox.md: cover.outlineColor ink
            radius = 6, -- toybox.md: cover.radius
            shadow = { x = 0, y = 6, color = "shadow", outline_width = false }, -- toybox.md: cover.shadow
            padding = { x = 10, y = 10 }, -- the cover's padding (Looks.dc.html:639)
        },
        strip = {
            height = 8, -- the strip: the bar's height at most 8 (Looks.dc.html:767)
            outline_width = 2, -- Looks.dc.html:767, the progress outline at most 2
        },
        -- The folder's block (Looks.dc.html:754-766, :758): its 3 px ink outline on paper. Its radius
        -- and edge are the covers' (library.cover), not the board's 18.
        folder = {
            fill_color = "paper", -- Looks.dc.html:758
            outline_width = 3, -- Looks.dc.html:758
            outline_color = "outline", -- Looks.dc.html:758
            icon_size = 28, -- Looks.dc.html:790
            icon_color = "ink", -- Looks.dc.html:790
            padding = { x = 14, y = 14 }, -- Looks.dc.html:756
            count_gap = 4, -- the name's margin (Looks.dc.html:766)
        },
        badge = {
            size = 34, -- no board: Diner's overhanging badge, a size down, round as the launcher's
            outline_width = 2, -- no board: the chip's outline
            outline_color = "outline", -- no board: the chip's ink outline
            fill_color = "sun", -- no board: the launcher's first badge
            icon_size = 20, -- no board: Diner's
            icon_color = "ink", -- no board: toybox.md's ink icons
            inset = -10, -- no board: Diner's overhang, a size down
            align = "top", -- no board: Diner's
        },
        not_downloaded = {
            outline_color = "outline", -- no board: toybox.md's chips have a 2 px ink border
            padding = { x = 11, y = 4 }, -- no board: the chip's padding (Looks.dc.html:659)
        },
        pager = {
            button_w = 44, -- no board: Diner's
            button_h = 32, -- no board: Diner's
            gap = 18, -- no board: Diner's
            bottom = 16, -- no board: Diner's
            outline_width = 2, -- no board: toybox.md's picker border
            outline_color = "outline", -- no board: toybox.md's picker border ink
            prev_fill_color = "paper", -- no board: Diner's paper box
            next_fill_color = "sun", -- no board: the lit nav tab's sun
            dead_color = false, -- no board: Diner's, a dead arrow left out
            prev_icon_color = "ink", -- no board: toybox.md's ink icons
            next_icon_color = "ink", -- no board: toybox.md's ink icons
            label_in_words = true, -- no board: Diner's "Page 1 of 24"
        },
    },
    -- The series and authors screens. No board draws Toybox's: the library's header on paper, rows
    -- and groups as the home's blocks (3 px ink on paper on their ink edge), mint chips and letters,
    -- the up-next book on sun.
    shelf = {
        series_fill_color = false, -- no board: the library's header on paper
        authors_fill_color = false, -- no board: the library's header on paper
        detail = {
            padding = { top = 36, side = 40, bottom = 16 }, -- no board: the library header's
            back_gap = 10, -- no board: Diner's
        },
        back = {
            fill_color = "paper", -- no board: toybox.md's picker fill
            outline_width = 2, -- no board: toybox.md's picker border
            padding = { left = 6, right = 10, y = 4 }, -- no board: Diner's
            icon_size = 14, -- no board: Diner's
            gap = 6, -- no board: Diner's
        },
        list = {
            padding_top = 28, -- no board: the library grid's
            side = 40, -- no board: the library grid's
            row_gap = 16, -- no board: the launcher's row gap
            pager_gap = 14, -- no board: Diner's
        },
        row = {
            padding = { x = 16, y = 9 }, -- no board: Diner's
            gap = 18, -- no board: Diner's
            line_gap = 3, -- no board: Diner's
            outline_width = 3, -- no board: the block's outline
            shadow = { x = 0, y = 6 }, -- no board: the block's ink edge (shadow.tile)
            rule_width = 0, -- no board: boxed, not ruled
            rule_color = "outline", -- no board: unused at rule_width 0
        },
        stack = {
            cover_w = 38, -- no board: Diner's
            cover_h = 56, -- no board: Diner's
            offset_x = 10, -- no board: Diner's
            offset_y = 2, -- no board: Diner's
            outline_width = 2, -- no board: the chip's outline
            outline_color = "outline", -- no board: the block's ink outline
        },
        chip = {
            padding = { x = 8, y = 2 }, -- no board: the chip's padding, shorter in a row
            outline_width = 2, -- no board: toybox.md's chip border
            under_way_fill_color = "mint", -- no board: toybox.md's chips are a mint fill
            finished_fill_color = "mint", -- no board: toybox.md's chips are a mint fill
            not_started_fill_color = "paper", -- no board: Diner's paper chip
            up_next_fill_color = "sun", -- no board: the lit nav tab's sun
        },
        books = {
            padding_top = 24, -- no board: Diner's
            row_gap = 18, -- no board: Diner's
        },
        book = {
            padding = { x = 16, y = 14 }, -- no board: Diner's
            index_w = 40, -- no board: Diner's
            cover_w = 64, -- no board: the sheet's cover (Looks.dc.html:725)
            cover_h = 96, -- no board: the sheet's cover (Looks.dc.html:725)
            cover_outline_width = 3, -- no board: toybox.md's cover outline
            line_gap = 6, -- no board: Diner's
            bar_height = 8, -- no board: the library's strip
            bar_outline_width = 2, -- no board: the library's strip
            badge_size = 28, -- no board: Diner's
            badge_outline_width = 2, -- no board: the chip's outline
            badge_icon_size = 14, -- no board: Diner's
            badge_inset = -10, -- no board: Diner's overhang
        },
        next = {
            fill_color = "sun", -- no board: the lit nav tab's sun
            shadow = { x = 0, y = 6 }, -- no board: the block's ink edge
            line_gap = 4, -- no board: Diner's
            text_color = "on_accent", -- no board: ink on the sun
        },
        groups = {
            padding_top = 28, -- no board: the library grid's
            gap = 16, -- no board: the launcher's row gap
        },
        group = {
            outline_width = 3, -- no board: the block's outline
            shadow = { x = 0, y = 6 }, -- no board: the block's ink edge
            rule_width = 0, -- no board: boxed, not ruled
            rule_color = "outline", -- no board: unused at rule_width 0
            letter_w = 48, -- no board: Diner's
            letter_fill_color = "mint", -- no board: toybox.md's mint fill
            letter_rule_width = 2, -- no board: the chip's outline
        },
        author = {
            padding = { x = 16, y = 11 }, -- no board: Diner's
            rule_width = 2, -- no board: the sheet's row rules
            rule_color = "hairline_light", -- no board: the sheet's hairline row rules
        },
        author_grid = {
            cover_h = 174, -- no board: Diner's, the library's less the one-author header
        },
        up_next = {
            fill_color = "sun", -- no board: the lit nav tab's sun
            outline_width = 2, -- no board: toybox.md's chip border
        },
    },
}
