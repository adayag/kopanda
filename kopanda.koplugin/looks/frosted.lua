-- Frosted Plates: the owner's wallpaper behind the home, every row on a plate washed toward paper
-- with a 2 px ink keyline, violet and yellow accents. Pure data, typed from the design's token
-- table and Lua export (.tiller/design/2026-10-19-kopanda-looks/frosted.md, and plates.md, which
-- it inherits) and its boards in the design file (`KoPanda Looks.dc.html` beside them, cited
-- "Looks.dc.html:<line>"); where neither gives a value, the line's comment says "no board" and
-- names the analogy. Diner, Editorial and Riso (looks/diner.lua, looks/editorial.lua,
-- looks/riso.lua) declare the same paths.
--
-- Sizes are board pixels (the canvas's half size), scaled at draw time by Screen:scaleBySize;
-- font sizes go to Font:getFace unscaled. Colours are #rrggbb in the palettes only; every other
-- token names a colour by its palette role. false is a token this look doesn't have.
return {
    -- frosted.md: Atkinson Hyperlegible 700 for display, 400 and 700 and italic for text, no accent face.
    faces = {
        display = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf", -- frosted.md
            label = "Atkinson Hyperlegible 700" }, -- frosted.md
        text = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Regular.ttf", -- frosted.md
            label = "Atkinson Hyperlegible 400" }, -- frosted.md
        accent = { file = false, label = false }, -- frosted.md: accent face none
        strong = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf", -- frosted.md: text bold 700
            label = "Atkinson Hyperlegible 700" }, -- frosted.md
        quote = { file = "fonts/atkinson-hyperlegible/AtkinsonHyperlegible-Italic.ttf", -- frosted.md: quote italic
            label = "Atkinson Hyperlegible 400 italic" }, -- frosted.md
    },

    -- The icon set the look draws with: a set id under icons/, or false for the registry's
    -- default Lucide set.
    icons = {
        set = "phosphor-bold", -- frosted.md: Phosphor Bold, chosen first
    },

    -- frosted.md's export palettes: its hairLight is hairline_light, its a1 the violet, its a2 the
    -- yellow. Structure is the ink, so outline, shadow and on_accent are the ink.
    palettes = {
        day = {
            paper = "#fbfaf6", -- frosted.md
            ink = "#1b1a1f", -- frosted.md
            muted = "#4d4b55", -- frosted.md
            text = "#1b1a1f", -- frosted.md: text is the ink
            hairline = false, -- frosted.md has one rule colour, hairline_light
            hairline_light = "#d9d6df", -- frosted.md: sheet rows only
            teal = false, -- Diner's accent; Frosted has none
            pink = false, -- Diner's and Riso's accent; Frosted has none
            mustard = false, -- Diner's accent; Frosted has none
            tint = false, -- Riso's tint; Frosted has none
            violet = "#6b55c8", -- frosted.md: a1, the progress
            yellow = "#f2c230", -- frosted.md: a2, the chip and the lit tab
            sun = false, -- Toybox's accents and its nav pill's white; Frosted has none
            coral = false, -- as sun
            mint = false, -- as sun
            die = false, -- as sun
            band = false, -- frosted.md: band none
            outline = "#1b1a1f", -- frosted.md: keylines are ink
            shadow = "#1b1a1f", -- frosted.md: the sheet's shadow is ink
            on_band = false, -- no band
            on_accent = "#1b1a1f", -- frosted.md: chip.color ink, on the yellow
            -- No board draws a typographic cover: a solid violet block, paper text on it.
            cover = "#6b55c8",
            on_cover = "#fbfaf6", -- no board: the paper, as above
        },
        night = {
            paper = "#1d1c22", -- frosted.md
            ink = "#f3f1ec", -- frosted.md
            muted = "#b5b2bd", -- frosted.md
            text = "#f3f1ec", -- frosted.md
            hairline = false, -- as by day
            hairline_light = "#3a3842", -- frosted.md
            teal = false, -- as by day
            pink = false, -- as by day
            mustard = false, -- as by day
            tint = false, -- as by day
            violet = "#a593f2", -- frosted.md: a1
            yellow = "#8a6d10", -- frosted.md: a2
            sun = false, -- as by day
            coral = false, -- as sun
            mint = false, -- as sun
            die = false, -- as sun
            band = false, -- as by day
            outline = "#f3f1ec", -- frosted.md: structure is the ink
            shadow = "#f3f1ec", -- frosted.md: structure is the ink
            on_band = false, -- as by day
            on_accent = "#f3f1ec", -- no board: the night ink on the night yellow
            cover = "#6b55c8", -- no board: the day's violet block, as Diner keeps its cover by night
            on_cover = "#fbfaf6", -- no board: the day's paper on it
        },
        grey = {
            paper = "#ffffff", -- frosted.md
            ink = "#000000", -- frosted.md
            muted = "#333333", -- frosted.md
            text = "#000000", -- frosted.md
            hairline = false, -- as by day
            hairline_light = "#bbbbbb", -- frosted.md
            teal = false, -- as by day
            pink = false, -- as by day
            mustard = false, -- as by day
            tint = false, -- as by day
            -- frosted.md's a1 is #000000 under a hatch, which progress.fill_grey draws in ink; an
            -- unhatched violet fill takes the cover's grey, so violet stays apart from the ink.
            violet = "#4a4a4a",
            yellow = "#cccccc", -- frosted.md: a2
            sun = false, -- as by day
            coral = false, -- as sun
            mint = false, -- as sun
            die = false, -- as sun
            band = false, -- as by day
            outline = "#000000", -- frosted.md: structure is the ink
            shadow = "#000000", -- frosted.md: structure is the ink
            on_band = false, -- as by day
            on_accent = "#000000", -- no board: the ink on the grey yellow
            cover = "#4a4a4a", -- no board: the direction doc's cover grey, as Diner's, Editorial's and Riso's
            on_cover = "#ffffff", -- no board: the paper on it
        },
    },

    -- frosted.md: 1 px hairlines (2 in grey), 2 px ink keylines; the nav edge and the sheet's
    -- outline have their own tokens (nav.edge_width, sheet.outline_width).
    stroke = {
        hairline = 1, -- frosted.md: stroke.hair
        hairline_grey = 2, -- frosted.md: stroke.greyHair
        rule = 2, -- frosted.md: stroke.rule
        outline = 2, -- frosted.md: 2 px ink keyline on every plate
        band = false, -- frosted.md: band none
    },

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide. frosted.md:
    -- shadow none, but the sheet's ink 5/7.
    shadow = {
        cover = { x = 0, y = 0, color = false, outline_width = false }, -- frosted.md: cover.shadow none
        tile = { x = 0, y = 0, color = false, outline_width = false }, -- frosted.md: tile.under none
        sheet = { x = 5, y = 7, color = "shadow", outline_width = false }, -- frosted.md: sheet only, ink 5/7
    },

    -- Display type printed once (frosted.md: misregister none).
    misregister = { x = 0, y = 0, color = false }, -- frosted.md: misregister none

    radius = {
        cover = 0, -- frosted.md: cover.radius 0
        box = 0, -- no board: the cover's square corners
    },

    -- The plates every home row sits on (frosted.md "Tile", "Translucency"; Looks.dc.html:594-598,
    -- :698-705): a 2 px ink keyline at radius 12 over the wallpaper lightened toward paper, by day
    -- 0.82, at night 0.84 and in grey 0.85; with no wallpaper, filled paper. Row 1 is one header
    -- plate padded by home.header.padding; every other row's widgets each sit on their own plate,
    -- padded and rounded by slots. The launcher's tiles are plates themselves.
    plate = {
        fill_color = "paper", -- frosted.md: plate.fill paper
        keyline = 2, -- frosted.md: plate.border
        keyline_color = "ink", -- frosted.md: plate.borderColor
        radius = 12, -- frosted.md: plate.radius
        -- A named deviation (plate.lua): KOReader's lightenRect blends toward white, and at night
        -- the stored pixels toward black, not toward the paper frosted.md names (#fbfaf6 by day,
        -- #1d1c22 at night), so night plates show about 24 levels darker than the night paper.
        lighten = {
            day = 0.82, -- frosted.md: plate.lighten.day
            night = 0.84, -- frosted.md: plate.lighten.night
            grey = 0.85, -- frosted.md: plate.lighten.grey
        },
        slots = {
            -- no board puts the date or clock off the header: the header plate's padding (Looks.dc.html:700)
            date = { x = 18, y = 14, radius = 12 },
            clock = { x = 18, y = 14, radius = 12 }, -- no board: as the date
            -- no board puts the weather off the header: the stats' pill (Looks.dc.html:704)
            weather = { x = 14, y = 8, radius = 999 },
            stats = { x = 14, y = 8, radius = 999 }, -- Looks.dc.html:704, a pill
            quote = { x = 18, y = 12, radius = 12 }, -- Looks.dc.html:703
            featured = { x = 14, y = 14, radius = 12 }, -- Looks.dc.html:702
            launcher = false, -- Looks.dc.html:692: each tile is a plate
        },
    },

    -- The owner's image behind the home's rows (wallpaper.file), scaled to cover the screen.
    wallpaper = {
        enabled = true, -- frosted.md: the wallpaper look
    },

    -- frosted.md: each tile a plate, its 2 px ink keyline and lightened ground drawn by the plate
    -- tokens; no shadow under it.
    tile = {
        box = true, -- frosted.md: tile.style plate
        fill_color = "paper", -- frosted.md: tile.fill paper, with no wallpaper
        outline_color = "outline", -- frosted.md: tile.borderColor ink
        rule_color = false, -- boxed, not ruled
    },

    -- frosted.md: a 12 px pill, 2 px ink outline, violet on paper; in grey a 135° hatch, as Diner's.
    progress = {
        height = 12, -- frosted.md: progress.h
        fill_color = "violet", -- frosted.md: progress.fill a1
        track_color = "paper", -- frosted.md: progress.track
        outline_color = "outline", -- frosted.md: progress.outlineColor ink
        outline_width = 2, -- frosted.md: progress.outline
        fill_grey = "hatch_135", -- frosted.md: grey a1 hatched
        radius = 999, -- frosted.md: progress.radius 999, round ends
    },

    -- frosted.md: an opaque inset plate, 16 in, a 2 px ink outline, the ink shadow 5/7 behind it
    -- (shadow.sheet), no band, the head under a 2 px ink rule, rows ruled in the light hairline.
    sheet = {
        fill_color = "paper", -- frosted.md: the sheet stays opaque
        rule_color = false, -- frosted.md: an outlined inset box, not a panel under a rule
        rule_width = 0, -- as above
        outline_color = "outline", -- frosted.md: sheet.border ink
        outline_width = 2, -- frosted.md: sheet.border 2
        header_band = false, -- frosted.md: sheet.band none
        inset = { side = 16, bottom = 16 }, -- frosted.md: sheet.inset
        padding = { top = 0, side = 0, bottom = 8 }, -- Looks.dc.html:720, the head spanning the box (:724)
        book_band_color = false, -- frosted.md: band none
        home_band_color = false, -- frosted.md: band none
        folder_band_color = false, -- frosted.md: band none
        quick_settings_band_color = false, -- frosted.md: band none
        header_rule_color = "outline", -- Looks.dc.html:724, the head's ink border
        header_rule_width = 2, -- Looks.dc.html:724, 2 px for an inset sheet
        header_padding = { top = 18, side = 20, bottom = 16 }, -- Looks.dc.html:724
        book_header_padding = { top = 18, side = 20, bottom = 16 }, -- Looks.dc.html:724
        cover_gap = 16, -- Looks.dc.html:724, the head's gap
        cover_w = 64, -- Looks.dc.html:725
        cover_h = 96, -- Looks.dc.html:725
        line_gap = 6, -- Looks.dc.html:727, the meta column's gap
        meta_gap = 4, -- Looks.dc.html:730, the progress row's margin
        aside_gap = 12, -- no board: Diner's, Editorial's and Riso's
        -- Looks.dc.html:735: 48 px rows, a 1 px light rule, the content centred.
        row_padding = { x = 20, y = 12 },
        row_gap = 14, -- no board: Diner's and Riso's
        icon_size = 22, -- no board: Diner's, Editorial's and Riso's
        row_rule_color = "hairline_light", -- frosted.md: sheet.rowRule hairLight
        row_rule_width = 1, -- Looks.dc.html:735, the look's hairline (stroke.hairline)
        last_row_bottom = 12, -- no board: row_padding.y, the box's 8 px foot below (padding.bottom)
        status_chip_color = "yellow", -- no board: frosted.md's chip is yellow
        state_chip_color = "yellow", -- no board: frosted.md's chip is yellow
        chip_padding = { x = 11, y = 4 }, -- Looks.dc.html:659, a rounded chip's padding
        chip_outline_width = 2, -- frosted.md: chip.border 2
        selected_fill_color = "yellow", -- no board: the lit nav tab's yellow (frosted.md nav.litColor)
        aside_above_gap = 2, -- no board: Diner's (SortC.dc.html:39)
        sublabel_gap = 2, -- no board: Diner's (SortC.dc.html:46)
        library_folder_band_color = false, -- no board: band none, as the book sheet's
        folder_box = {
            size = 60, -- no board: Diner's (HoldFolderC.dc.html:36)
            outline_width = 2, -- no board: the plate's 2 px ink keyline
            outline_color = "outline", -- no board: the plate's ink keyline
            fill_color = "paper", -- no board: on paper, as a plate with no wallpaper
            icon_size = 34, -- no board: Diner's (HoldFolderC.dc.html:37)
            icon_color = "ink", -- no board: frosted.md's icons are ink
        },
        library_empty_band_color = false, -- no board: band none, as the book sheet's
        sort_chip_color = "paper", -- no board: frosted.md's picker fill
        show_chip_color = "yellow", -- no board: frosted.md's chip is yellow
        radius = 16, -- frosted.md: sheet.radius 16
    },

    -- The quick-settings sheet's body. No board draws Frosted's: the sheet's rows and light rules,
    -- its progress bar for the levels, the plates' 2 px ink keyline for the buttons and tiles, and
    -- the on tile filled yellow with ink text as the lit nav tab; the rest Diner's and Editorial's.
    quick_settings = {
        padding_x = 20, -- no board: the sheet's row_padding.x
        first_section_padding = { top = 15, bottom = 15 }, -- no board: Diner's
        section_padding = { top = 15, bottom = 15 }, -- no board: Diner's
        section_gap = 10, -- no board: Editorial's (QuickSettings.dc.html:40)
        section_rule_width = 1, -- no board: the sheet's row_rule_width
        section_rule_color = "hairline_light", -- no board: the sheet's row_rule_color
        control_gap = 12, -- no board: Editorial's (QuickSettings.dc.html:44)
        button_w = 44, -- no board: Editorial's (QuickSettings.dc.html:45)
        button_h = 36, -- no board: Editorial's (QuickSettings.dc.html:45)
        button_outline_width = 2, -- no board: frosted.md's picker border
        button_outline_color = "outline", -- no board: frosted.md's picker border ink
        button_fill_color = "paper", -- no board: frosted.md's picker fill
        level_h = 12, -- no board: progress.height
        level_outline_width = 2, -- no board: progress.outline_width
        level_outline_color = "outline", -- no board: progress.outline_color
        level_fill_color = "violet", -- no board: progress.fill_color
        level_track_color = "paper", -- no board: progress.track_color
        grid_gap = 10, -- no board: Editorial's (QuickSettings.dc.html:62)
        grid_padding = { top = 15, bottom = 20 }, -- no board: Diner's
        cell_padding = { top = 14, bottom = 12 }, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_gap = 8, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_icon_size = 24, -- no board: frosted.md's icon size
        cell_outline_width = 2, -- no board: the plate's keyline
        cell_outline_color = "outline", -- no board: the plate's ink keyline
        cell_fill_color = "paper", -- no board: the sheet's fill_color
        on_fill_color = "yellow", -- no board: the lit nav tab's fill (frosted.md nav.litColor)
        on_text_color = "ink", -- no board: ink on the yellow
    },

    -- frosted.md: a yellow pill, ink uppercase 700, a 2 px ink border.
    chip = {
        small_caps = false, -- frosted.md: label.case upper
        uppercase = true, -- frosted.md: label.case upper
        text_color = "ink", -- frosted.md: chip.color ink
        fill_color = "yellow", -- frosted.md: chip.fill a2
        outline_color = "outline", -- frosted.md: chip.borderColor ink
        radius = 999, -- frosted.md: chip.radius 999, a pill
    },

    -- frosted.md: 11 px uppercase 700, 0.08 em, muted.
    label = {
        size = 11, -- frosted.md: label.size
        face = "strong", -- frosted.md: label.weight 700
        small_caps = false, -- frosted.md: label.case upper
        uppercase = true, -- frosted.md: label.case upper
        tracking = 0.08, -- frosted.md: label.tracking
    },

    -- The home's page (Looks.dc.html:583, :607, :641-705): the wallpaper's margins, the gutters
    -- between plates, where the free height goes, the header plate and no footer.
    home = {
        -- The body's padding for a plate look: 26 above, 24 at the sides and 14 above the bar
        -- (Looks.dc.html:583, :607).
        margin = { top = 26, side = 24, bottom = 14 },
        row_gap = 12, -- frosted.md: 12 px gutters between plates (Looks.dc.html:444)
        column_gap = 12, -- frosted.md: 12 px gutters, the tiles' (Looks.dc.html:444)
        free_space = "before_last_row", -- the stats' margin-top: auto (Looks.dc.html:697)
        -- frosted.md: the header plate, no band and no rule; the date and weather left, the clock
        -- right, padded 14 by 18 inside the keyline (Looks.dc.html:700).
        header = {
            band_color = false, -- frosted.md: band none
            edge_width = 0, -- frosted.md: header.rule 0
            edge_color = false, -- frosted.md: header.ruleColor none
            rule_color = false, -- frosted.md: header.rule 0
            rule_width = 0, -- frosted.md: header.rule 0
            rule_space = 0, -- frosted.md: header.rule 0
            padding = { top = 14, side = 18, bottom = 14 }, -- Looks.dc.html:700
            -- Looks.dc.html:700 centres the header's columns; here on one baseline, as every look's.
            align = "bottom",
        },
        footer = {
            height = 0, -- frosted.md: no footer
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
        -- The date's lines: 2, the weekday as a label over "October 13" (Looks.dc.html:55-56, :650-651).
        date_lines = 2,
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
    -- labels are the strong face, frosted.md's 700.
    type = {
        -- The weekday over the date, the look's label (Looks.dc.html:650).
        date_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- frosted.md: 18 px 700, CSS line height 1.1 (Looks.dc.html:651).
        date = { face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0.1, color = "ink" },
        -- frosted.md: 84 px 700, -0.03 em, CSS line height 0.8 (Looks.dc.html:653).
        clock = {
            face = "display", size = 84, uppercase = false, tracking = -0.03, line_height = -0.2, color = "ink",
        },
        -- 14 px Atkinson in the text colour (Looks.dc.html:652).
        weather = { face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text" },
        -- frosted.md: 18 px italic 400, CSS line height 1.35, ink (Looks.dc.html:669).
        quote = { face = "quote", size = 18, uppercase = false, tracking = 0, line_height = 0.35, color = "ink" },
        -- The look's label at 12 px in the text colour (Looks.dc.html:697).
        stats = { face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "text" },
        -- No board draws a typographic cover: Diner's sizes in the display face on the violet block.
        cover_title = {
            face = "display", size = 24, uppercase = true, tracking = 0.04, line_height = 0.05, color = "on_cover",
        },
        -- no board: Diner's authors line in the strong face
        cover_authors = {
            face = "strong", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "on_cover",
        },
        -- no board: the look's label in the first run's dashed frame
        cover_empty = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- "Now reading" in its chip: the label, ink, 700 (Looks.dc.html:659).
        featured_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- frosted.md: the title 32 px 700, -0.015 em, CSS line height 1.04 (Looks.dc.html:660).
        featured_title = {
            face = "display", size = 32, uppercase = false, tracking = -0.015, line_height = 0.04, color = "ink",
        },
        -- frosted.md: author 16 px in the text colour (Looks.dc.html:662).
        featured_authors = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- Not drawn on its own: the chapter joins the authors line (Looks.dc.html:68), in its style.
        featured_chapter = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- 14 px, weight 600 (Atkinson 700 here), the text colour (Looks.dc.html:666).
        featured_caption = {
            face = "strong", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- No board draws Frosted's first run: the title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = {
            face = "display", size = 27, uppercase = false, tracking = -0.015, line_height = 0.04, color = "ink",
        },
        -- no board: the authors line's style at Editorial's first-run line height (EmptyStates.dc.html:37)
        featured_empty_body = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0.4, color = "text",
        },
        -- no board: the look's label in ink, as the chip's
        featured_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- frosted.md: launcher 19 px 700, CSS line height 1.1 (Looks.dc.html:683).
        launcher_label = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its suffix, "Off", the look's label (Looks.dc.html:694).
        launcher_suffix = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- No board draws Frosted's home sheet: the book sheet's title (Looks.dc.html:728) in ink.
        sheet_heading = {
            face = "display", size = 23, uppercase = false, tracking = -0.015, line_height = 0.05, color = "ink",
        },
        -- no board: the look's label (Looks.dc.html:733's last-opened line)
        sheet_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- The title 0.72 of 32 px, CSS line height 1.05 (Looks.dc.html:728).
        sheet_title = {
            face = "display", size = 23, uppercase = false, tracking = -0.015, line_height = 0.05, color = "ink",
        },
        -- 15 px Atkinson in the text colour (Looks.dc.html:729).
        sheet_author = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- "62% · Part 3 · opened yesterday": the progress row's 13 px 700 (Looks.dc.html:730).
        sheet_meta = {
            face = "strong", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- frosted.md: sheet rows 18 px, weight 500 (Atkinson 400 here), ink (Looks.dc.html:735).
        sheet_row = { face = "text", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: a row's plain detail in the look's label
        sheet_detail = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- frosted.md: a chip's label, ink on its yellow
        sheet_chip = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- no board: sheet_chip in ink, for a chip on paper
        sheet_chip_plain = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- no board: the header's label at its right, the look's label
        sheet_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- no board: a row's second line, Atkinson 400 in muted
        sheet_sublabel = {
            face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted",
        },
        -- no board: a quick-settings bar's label and value, the look's label
        quick_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- no board: the bars' minus and plus, the strong face at Editorial's size (QuickSettings.dc.html:45)
        quick_button = {
            face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- no board: a quick-settings tile's label, the look's label in ink
        quick_cell = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The editor screens have no Frosted board: the header on paper over an ink rule, its title
        -- in the display face, the rest in the look's label, at Editorial's sizes and line height 0.3.
        -- no board: the look's label at Editorial's line height
        editor_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0.3, color = "muted",
        },
        -- no board: Editorial's size and line height in the display face
        editor_title = {
            face = "display", size = 34, uppercase = false, tracking = -0.015, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label in ink
        editor_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label
        editor_caption = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0.3, color = "muted",
        },
        -- no board: Diner's and Editorial's
        editor_box = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: Diner's and Editorial's
        editor_share = {
            face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        -- no board: Diner's and Editorial's, so six rows fit above the add-an-entry foot
        editor_label = {
            face = "strong", size = 16, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label
        editor_kind = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0.3, color = "muted",
        },
        -- no board: Diner's and Editorial's
        editor_note = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        -- frosted.md: nav labels 11 px, the look's label, muted unlit (Looks.dc.html:617, :622).
        nav_label = { face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted" },
        -- The lit tab's label in ink (Looks.dc.html:617); the board's 800 is Atkinson 700 here.
        nav_label_active = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- No board draws Frosted's file browser: the library's (Looks.dc.html:744-749).
        -- The book count, the look's label (Looks.dc.html:747).
        title_bar_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- The library's title, 32 px, -0.015 em, CSS line height 0.95 (Looks.dc.html:746).
        title_bar_title = {
            face = "display", size = 32, uppercase = false, tracking = -0.015, line_height = -0.05, color = "ink",
        },
        -- A picker's label, ink 700 (Looks.dc.html:749).
        title_bar_sort = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The status picker's, as the sort's (Looks.dc.html:749).
        title_bar_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The library's parts (Looks.dc.html:744-790). The count, the look's label (:747).
        library_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- The title, 32 px, -0.015 em, CSS line height 0.95 (Looks.dc.html:746).
        library_title = {
            face = "display", size = 32, uppercase = false, tracking = -0.015, line_height = -0.05, color = "ink",
        },
        -- A picker's label, ink 700 (Looks.dc.html:749).
        library_picker = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The status picker's, as the sort's (Looks.dc.html:749).
        library_picker_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- no board: a tile's title, one line, the strong face at Diner's size and line height
        tile_title = {
            face = "strong", size = 12, uppercase = false, tracking = 0, line_height = 0.2, color = "ink",
        },
        -- The placeholder's title, 20 px, CSS line height 1.1 (Looks.dc.html:776).
        tile_cover_title = {
            face = "display", size = 20, uppercase = false, tracking = 0, line_height = 0.1, color = "on_cover",
        },
        -- A folder's book count: its name's style, 19 px 700, CSS line height 1.1 (Looks.dc.html:766).
        folder_count = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its reading count, the look's label (Looks.dc.html:747).
        folder_reading = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- no board: "Page 1 of 24", the look's label in ink
        pager_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- The series and authors screens have no Frosted board: the library's header and the
        -- home's plates, by analogy.
        -- no board: the featured title's size, CSS line height 0.95 as the library's title
        shelf_detail_title = {
            face = "display", size = 32, uppercase = false, tracking = -0.015, line_height = -0.05, color = "ink",
        },
        -- no board: the look's label in ink, as a picker's
        shelf_back = { face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "ink" },
        -- no board: the library folder's name (Looks.dc.html:766)
        series_name = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- no board: Atkinson 400 in muted
        series_sub = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- no board: a chip's label, ink on its yellow
        shelf_chip = {
            face = "strong", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- no board: a chip's label on paper
        shelf_chip_plain = {
            face = "strong", size = 10, uppercase = true, tracking = 0.08, line_height = 0, color = "ink",
        },
        -- no board: a book's series index, Diner's size in the display face
        book_index = { face = "display", size = 40, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: the library folder's name (Looks.dc.html:766)
        book_row_title = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- no board: "read this one next" in the look's label on the yellow row; Frosted has no accent face
        book_next_note = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "on_accent",
        },
        -- no board: series_sub's style
        book_row_note = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- no board: a group's letter on its yellow column, in the display face
        author_letter = {
            face = "display", size = 28, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- no board: Diner's
        author_name = { face = "strong", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: the look's label
        author_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- no board: the look's label, as the pager's
        shelf_empty = {
            face = "strong", size = 12, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
        -- no board: the header's static label, the look's label
        shelf_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.08, line_height = 0, color = "muted",
        },
    },

    -- frosted.md: three columns of 74 px plates 12 apart, the icon at the top and the label at
    -- the foot (Looks.dc.html:690-692).
    launcher = {
        columns = 3, -- frosted.md: tile.cols
        column_gap = 12, -- frosted.md: tile.gap (Looks.dc.html:444, :684)
        row_gap = 12, -- frosted.md: tile.gap (Looks.dc.html:444, :684)
        icon_size = 24, -- frosted.md: icons 24 px
        icon_gap = false, -- the icon sits above the label, not beside it (Looks.dc.html:690)
        padding = { x = 13, y = 11 }, -- Looks.dc.html:692
        tile_height = 74, -- frosted.md: tile.h
        accent_1_color = false, -- frosted.md: every tile alike
        accent_2_color = false, -- frosted.md: every tile alike
        accent_3_color = false, -- frosted.md: every tile alike
        suffix_gap = 8, -- Looks.dc.html:685, the label's row gap
        suffix_below = false, -- on the label's line, beside it (Looks.dc.html:685)
        -- No badge: frosted.md's tiles are plates with the icon bare (Looks.dc.html:690), so a size
        -- of 0 draws no badge.
        badge = {
            size = 0, -- no badge
            outline_width = 0, -- no badge
            outline_color = false, -- no badge
            fill_1_color = false, -- no badge
            fill_2_color = false, -- no badge
            fill_3_color = false, -- no badge
            fill_4_color = false, -- no badge
            fill_5_color = false, -- no badge
            fill_6_color = false, -- no badge
        },
    },

    -- The quote plain on its plate (frosted.md: quote.style plain, no rules; the plate's padding is
    -- plate.slots.quote).
    quote = {
        padding = 0, -- frosted.md: quote.style plain
        rule_width = 0, -- frosted.md: quote.rule 0
        rule_color = false, -- frosted.md: quote.ruleColor none
    },

    -- The featured book's cover box (frosted.md: 122 × 183, a 2 px ink outline, radius 0, no shadow).
    featured = {
        cover_w = 122, -- frosted.md: cover.w
        cover_h = 183, -- frosted.md: cover.h
        cover_padding = { x = 10, y = 10 }, -- the cover's padding (Looks.dc.html:639)
        cover_outline_color = "outline", -- frosted.md: cover.outlineColor ink
        dash = 4, -- no board: Diner's and Editorial's first-run frame
        dash_gap = 4, -- no board: Diner's and Editorial's first-run frame
        gap = 20, -- Looks.dc.html:702, the plate's gap
        column_padding_y = 2, -- the text column's top padding (Looks.dc.html:657)
        title_gap = 12, -- the chip's margin below it (Looks.dc.html:659)
        chip_outline = 2, -- frosted.md: chip.border 2
        chip_padding = { x = 11, y = 4 }, -- Looks.dc.html:659, a rounded chip's padding
        button_padding = { x = 14, y = 9 }, -- no board: Diner's and Editorial's (EmptyStates.dc.html:38)
        button_fill_color = "yellow", -- no board: frosted.md's chip yellow
        button_outline_color = "outline", -- no board: frosted.md's picker border ink
    },
    -- The editor screens, edit layout and launcher management. No board draws Frosted's: the header
    -- on paper over a 3 px ink rule (the nav's edge), cards outlined in the plates' 2 px ink with
    -- no shadow, the selected card yellow; spacing as Editorial's boards give it.
    editor = {
        padding = { top = 40, side = 40, bottom = 28 }, -- no board: Editorial's
        header_band_color = false, -- no board: frosted.md has no band
        header_text_color = false, -- no board: no band
        header_rule_color = "outline", -- no board: frosted.md's ink structure
        header_rule_width = 3, -- no board: frosted.md's 3 px nav edge
        header_gap = 16, -- no board: Editorial's
        body_gap = 18, -- no board: Editorial's
        button_outline_color = "outline", -- no board: frosted.md's picker border ink
        button_outline_width = 2, -- no board: frosted.md's picker border
        button_fill_color = "paper", -- no board: frosted.md's picker fill
        button_padding = { x = 14, y = 8 }, -- no board: Editorial's
        card_gap = 10, -- no board: Diner's, so the default layout's five rows fit with one selected
        card_padding = { x = 14, y = 12 }, -- no board: Editorial's
        card_outline_color = "outline", -- no board: the plate's ink keyline
        card_outline_width = 2, -- no board: the plate's keyline
        card_shadow = { x = 0, y = 0, color = false }, -- no board: frosted.md's plates have no shadow
        selected_outline_color = "outline", -- no board: the plate's ink keyline
        selected_fill_color = "yellow", -- no board: the lit nav tab's yellow
        arrow_size = 28, -- no board: Editorial's
        arrow_gap = 14, -- no board: Editorial's
        disabled_color = "muted", -- no board: Frosted's quietest text
        box_padding = { x = 12, y = 10 }, -- no board: Editorial's
        box_gap = 8, -- no board: Editorial's
        row_padding = { y = 14 }, -- no board: Editorial's
        row_rule_color = "hairline_light", -- no board: the sheet's light row rules
        row_rule_width = 1, -- no board: the sheet's row rules
        icon_size = 22, -- no board: Editorial's
        icon_gap = 14, -- no board: Editorial's
        control_size = 30, -- no board: Editorial's
        kind_gap = 8, -- no board: Editorial's
        kind_columns = 2, -- no board: Editorial's
    },
    -- The nav bar, opaque on purpose: a 3 px ink edge over paper, five tabs of an icon over a
    -- label, the lit tab filled yellow, its icon and label ink and the rest muted (frosted.md;
    -- Looks.dc.html:608-622).
    nav = {
        fill_color = "paper", -- Looks.dc.html:608
        edge_width = 3, -- frosted.md: nav.edge
        edge_color = "ink", -- Looks.dc.html:608
        padding_x = 0, -- the bar is unpadded at its sides (Looks.dc.html:608)
        -- The 84 px bar less its edge, icon, gap and label line, shared above and below the tab's
        -- centred content (Looks.dc.html:584, :620), as Riso's.
        padding_top = 17,
        padding_bottom = 17, -- as padding_top
        icon_size = 24, -- frosted.md: nav_size 24
        icon_gap = 7, -- Looks.dc.html:620
        icon_color = "muted", -- frosted.md: nav_unlit muted
        active_icon_color = "ink", -- Looks.dc.html:617
        active_rule_width = 0, -- frosted.md: nav.bar 0
        active_rule_color = false, -- frosted.md: nav.bar 0
        active_fill_color = "yellow", -- frosted.md: nav.lit fill, litColor a2
        divider_width = 0, -- no dividers between tabs (Looks.dc.html:620)
        divider_color = false, -- no dividers
        -- A bar across the screen's bottom, not Toybox's floating pill (frosted.md: the nav stays
        -- opaque under its edge): float false paints the band and its tabs as the bar did before
        -- the pill, and the pill's tokens are none.
        float = false,
        margin = { side = 0, bottom = 0 }, -- no pill: the bar meets the screen's sides and bottom
        radius = 0, -- no pill
        float_fill_color = false, -- no pill
        shadow = { x = 0, y = 0, color = false }, -- no pill
        tab_gap = 0, -- the tabs share the width with no gap, as before the pill
        active_outline_width = 0, -- the lit tab is not outlined (frosted.md: nav.lit fill)
        active_outline_color = false, -- not outlined
    },
    -- The file browser's title bar. No board draws Frosted's: the library's header (Looks.dc.html:744-749,
    -- :761-764), a count and a 32 px title on paper with no rule, the pickers outlined in 2 px ink on paper.
    title_bar = {
        fill_color = "paper", -- no board: the library's header on paper
        padding = { top = 26, side = 24, bottom = 16 }, -- no board: the home's top margin and the sides
        edge_width = 0, -- no board: frosted.md's header.rule 0
        edge_color = false, -- no board: no edge
        line_gap = 4, -- no board: the library header's gap (Looks.dc.html:745)
        picker_gap = 8, -- no board: the library's pickers' gap (Looks.dc.html:131)
        sort_fill_color = "paper", -- no board: frosted.md's picker fill
        status_fill_color = "paper", -- no board: frosted.md's picker fill
        picker_outline_width = 2, -- no board: frosted.md's picker border
        picker_outline_color = "outline", -- no board: frosted.md's picker border ink
        picker_padding = { x = 10, y = 7 }, -- no board: Looks.dc.html:749
        icon_size = 16, -- no board draws the plus: the pickers' size
        icon_color = "ink", -- no board draws the plus: the pickers' ink
        count_on_shelf = false, -- no board: "148 books", as the library's (Looks.dc.html:129)
        picker_radius = 999, -- no board: frosted.md's picker.radius 999, a pill
    },
    -- The library (Looks.dc.html:740-790), on paper: the wallpaper is the home's alone. A 32 px
    -- title and count with no rule, the pickers outlined in 2 px ink on paper, three columns of
    -- covers each in its 2 px ink outline, a violet strip under each, and a pager above the nav.
    library = {
        header = {
            fill_color = false, -- the page under the header (Looks.dc.html:744)
            padding = { top = 26, side = 24, bottom = 16 }, -- the body's padding (Looks.dc.html:583, :607)
            edge_width = 0, -- frosted.md: header.rule 0 (Looks.dc.html:744)
            edge_color = false, -- no edge
            line_gap = 4, -- Looks.dc.html:745
            picker_gap = 8, -- Looks.dc.html:131
            picker_padding = { x = 10, y = 7 }, -- Looks.dc.html:749
            picker_outline_width = 2, -- frosted.md: picker.border
            picker_outline_color = "outline", -- frosted.md: picker.borderColor ink
            sort_fill_color = "paper", -- frosted.md: picker.fill paper
            status_fill_color = "paper", -- frosted.md: picker.fill paper
            picker_radius = 999, -- frosted.md: picker.radius 999, a pill
        },
        grid = {
            padding_top = 28, -- the body's gap and the grid's margin (Looks.dc.html:607, :751)
            side = 24, -- Looks.dc.html:583
            row_gap = 22, -- Looks.dc.html:751
            column_gap = 20, -- Looks.dc.html:751
            cover_h = 195, -- no board: Diner's (D2), so two rows fit, as Riso's
            strip_gap = 8, -- the item's 8 px gap (Looks.dc.html:752)
            title_gap = 8, -- the item's gap (Looks.dc.html:752)
        },
        -- The covers in their 2 px ink outline (frosted.md cover.outline), square, no shadow.
        cover = {
            outline_width = 2, -- frosted.md: cover.outline
            outline_color = "outline", -- frosted.md: cover.outlineColor ink
            radius = 0, -- frosted.md: cover.radius 0
            shadow = { x = 0, y = 0, color = false, outline_width = false }, -- frosted.md: cover.shadow none
            padding = { x = 10, y = 10 }, -- the cover's padding (Looks.dc.html:639)
        },
        strip = {
            height = 8, -- the strip: the bar's height at most 8 (Looks.dc.html:776)
            outline_width = 2, -- Looks.dc.html:776
        },
        -- The folder's tile (Looks.dc.html:754-766): a plate's 2 px ink keyline on paper (:764).
        folder = {
            fill_color = "paper", -- Looks.dc.html:764, a plate with no wallpaper
            outline_width = 2, -- Looks.dc.html:764, the plate's keyline
            outline_color = "outline", -- Looks.dc.html:764, the plate's ink keyline
            icon_size = 28, -- Looks.dc.html:781
            icon_color = "ink", -- Looks.dc.html:781
            padding = { x = 14, y = 14 }, -- Looks.dc.html:756
            count_gap = 4, -- the name's margin (Looks.dc.html:766)
        },
        badge = {
            size = 34, -- no board: Riso's, a size down from Diner's for the 2 px stroke
            outline_width = 2, -- no board: the plate's keyline
            outline_color = "outline", -- no board: the plate's ink keyline
            fill_color = "yellow", -- no board: frosted.md's chip yellow
            icon_size = 20, -- no board: Diner's
            icon_color = "ink", -- no board: frosted.md's ink icons
            inset = -10, -- no board: Riso's overhang
            align = "top", -- no board: Diner's
        },
        not_downloaded = {
            outline_color = "outline", -- no board: frosted.md's chip border ink
            padding = { x = 10, y = 5 }, -- Looks.dc.html:778, the missing label's pill
        },
        pager = {
            button_w = 44, -- no board: Diner's
            button_h = 32, -- no board: Diner's
            gap = 18, -- no board: Diner's
            bottom = 16, -- no board: Diner's
            outline_width = 2, -- no board: frosted.md's picker border
            outline_color = "outline", -- no board: frosted.md's picker border ink
            prev_fill_color = "paper", -- no board: frosted.md's picker fill
            next_fill_color = "yellow", -- no board: the lit nav tab's yellow
            dead_color = false, -- no board: Diner's, a dead arrow left out
            prev_icon_color = "ink", -- no board: frosted.md's ink icons
            next_icon_color = "ink", -- no board: frosted.md's ink icons
            label_in_words = true, -- no board: Diner's "Page 1 of 24"
        },
    },
    -- The series and authors screens. No board draws Frosted's: the library's header on paper,
    -- rows and groups outlined as the home's plates (2 px ink, no shadow), yellow chips and letters,
    -- the up-next book on yellow.
    shelf = {
        series_fill_color = false, -- no board: the library's header on paper
        authors_fill_color = false, -- no board: the library's header on paper
        detail = {
            padding = { top = 26, side = 24, bottom = 16 }, -- no board: the library header's
            back_gap = 10, -- no board: Diner's
        },
        back = {
            fill_color = "paper", -- no board: frosted.md's picker fill
            outline_width = 2, -- no board: frosted.md's picker border
            padding = { left = 6, right = 10, y = 4 }, -- no board: Diner's
            icon_size = 14, -- no board: Diner's
            gap = 6, -- no board: Diner's
        },
        list = {
            padding_top = 28, -- no board: the library grid's
            side = 24, -- no board: the library grid's
            row_gap = 12, -- no board: the plates' gutter
            pager_gap = 14, -- no board: Diner's
        },
        row = {
            padding = { x = 16, y = 9 }, -- no board: Diner's
            gap = 18, -- no board: Diner's
            line_gap = 3, -- no board: Diner's
            outline_width = 2, -- no board: the plate's keyline
            shadow = { x = 0, y = 0 }, -- no board: frosted.md's plates have no shadow
            rule_width = 0, -- no board: boxed, not ruled
            rule_color = "outline", -- no board: unused at rule_width 0
        },
        stack = {
            cover_w = 38, -- no board: Diner's
            cover_h = 56, -- no board: Diner's
            offset_x = 10, -- no board: Diner's
            offset_y = 2, -- no board: Diner's
            outline_width = 2, -- no board: the plate's keyline
            outline_color = "outline", -- no board: the plate's ink keyline
        },
        chip = {
            padding = { x = 8, y = 2 }, -- no board: the chip's padding, shorter in a row
            outline_width = 2, -- no board: frosted.md's chip border
            under_way_fill_color = "yellow", -- no board: frosted.md's chips are yellow
            finished_fill_color = "yellow", -- no board: frosted.md's chips are yellow
            not_started_fill_color = "paper", -- no board: Diner's paper chip
            up_next_fill_color = "yellow", -- no board: frosted.md's chips are yellow
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
            cover_outline_width = 2, -- no board: frosted.md's cover outline
            line_gap = 6, -- no board: Diner's
            bar_height = 8, -- no board: the library's strip
            bar_outline_width = 2, -- no board: the library's strip
            badge_size = 28, -- no board: Diner's
            badge_outline_width = 2, -- no board: the plate's keyline
            badge_icon_size = 14, -- no board: Diner's
            badge_inset = -10, -- no board: Diner's overhang
        },
        next = {
            fill_color = "yellow", -- no board: frosted.md's yellow fill
            shadow = { x = 0, y = 0 }, -- no board: frosted.md's plates have no shadow
            line_gap = 4, -- no board: Diner's
            text_color = "on_accent", -- no board: ink on the yellow
        },
        groups = {
            padding_top = 28, -- no board: the library grid's
            gap = 12, -- no board: the plates' gutter
        },
        group = {
            outline_width = 2, -- no board: the plate's keyline
            shadow = { x = 0, y = 0 }, -- no board: frosted.md's plates have no shadow
            rule_width = 0, -- no board: boxed, not ruled
            rule_color = "outline", -- no board: unused at rule_width 0
            letter_w = 48, -- no board: Diner's
            letter_fill_color = "yellow", -- no board: frosted.md's yellow fill
            letter_rule_width = 2, -- no board: the plate's keyline
        },
        author = {
            padding = { x = 16, y = 11 }, -- no board: Diner's
            rule_width = 1, -- no board: the sheet's row rules
            rule_color = "hairline_light", -- no board: the sheet's light row rules
        },
        author_grid = {
            cover_h = 174, -- no board: Diner's, the library's less the one-author header
        },
        up_next = {
            fill_color = "yellow", -- no board: frosted.md's chips are yellow
            outline_width = 2, -- no board: frosted.md's chip border
        },
    },
}
