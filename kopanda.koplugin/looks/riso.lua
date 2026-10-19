-- Riso: a two-drum Risograph, blue ink and fluoro pink on cream, no black anywhere, the pink
-- always a few pixels out of register. Pure data, typed from the design's token table and Lua
-- export (.tiller/design/2026-10-19-kopanda-looks/riso.md) and its boards in the design file
-- (`KoPanda Looks.dc.html` beside it, cited "Looks.dc.html:<line>"); where neither gives a value,
-- the line's comment says "no board" and names the analogy. Diner (looks/diner.lua) and Editorial
-- (looks/editorial.lua) declare the same paths.
--
-- Sizes are board pixels (the canvas's half size), scaled at draw time by Screen:scaleBySize;
-- font sizes go to Font:getFace unscaled. Colours are #rrggbb in the palettes only; every other
-- token names a colour by its palette role. false is a token this look doesn't have.
return {
    -- riso.md: Big Shoulders Display 900, Work Sans 500 and 700, no accent face.
    faces = {
        display = { file = "fonts/big-shoulders-display/BigShouldersDisplay-Black.ttf", -- riso.md
            label = "Big Shoulders Display 900" }, -- riso.md
        text = { file = "fonts/work-sans/WorkSans-Medium.ttf", label = "Work Sans 500" }, -- riso.md
        accent = { file = false, label = false }, -- riso.md: accent face none
        strong = { file = "fonts/work-sans/WorkSans-Bold.ttf", label = "Work Sans 700" }, -- riso.md
        -- riso.md's quote is Work Sans 500 italic; no Work Sans italic is vendored, so it is set upright.
        quote = { file = "fonts/work-sans/WorkSans-Medium.ttf", label = "Work Sans 500" },
    },

    -- The icon set the look draws with: a set id under icons/, or false for the registry's
    -- default Lucide set.
    icons = {
        set = "phosphor-fill", -- riso.md: Phosphor Fill, chosen first
    },

    -- riso.md's export palettes: its hairLight is hairline_light, its a1 the pink, its tint the
    -- tint. Structure is the ink, so outline, on_band and on_accent are the ink, and the band is
    -- the tint (the sheet's header band, riso.md "Band").
    palettes = {
        day = {
            paper = "#f3eee2", -- riso.md
            ink = "#22509f", -- riso.md: the blue drum, never black
            muted = "#3d5b9a", -- riso.md
            text = "#22509f", -- riso.md: text is the ink
            hairline = false, -- riso.md has one rule colour, hairline_light
            hairline_light = "#f2a9c4", -- riso.md: pink for secondary rules
            teal = false, -- Diner's accent; Riso has none
            pink = "#e9508a", -- riso.md: fluoro pink, a1
            mustard = false, -- Diner's accent; Riso has none
            violet = false, -- Frosted's accent; Riso has none
            yellow = false, -- Frosted's accent; Riso has none
            tint = "#f6c6d8", -- riso.md: pink tint
            sun = false, -- Toybox's accents and its nav pill's white; Riso has none
            coral = false, -- as sun
            mint = false, -- as sun
            die = false, -- as sun
            band = "#f6c6d8", -- riso.md: the tint band at the top of the sheet
            outline = "#22509f", -- riso.md: structure is ink
            shadow = false, -- riso.md: misregistration, not shadow
            on_band = "#22509f", -- no board: the ink on the tint band (Looks.dc.html:724)
            on_accent = "#22509f", -- riso.md: chips are ink on tint
            -- No board draws a typographic cover: a solid block of the blue drum, paper text on it.
            cover = "#22509f",
            on_cover = "#f3eee2", -- no board: the paper, as above
        },
        night = {
            paper = "#141a2e", -- riso.md
            ink = "#f1ece0", -- riso.md
            muted = "#b8bfd8", -- riso.md
            text = "#f1ece0", -- riso.md
            hairline = false, -- as by day
            hairline_light = "#6e3557", -- riso.md
            teal = false, -- as by day
            pink = "#f0729f", -- riso.md
            mustard = false, -- as by day
            violet = false, -- Frosted's accent; Riso has none
            yellow = false, -- Frosted's accent; Riso has none
            tint = "#4a2643", -- riso.md
            sun = false, -- as by day
            coral = false, -- as sun
            mint = false, -- as sun
            die = false, -- as sun
            band = "#4a2643", -- riso.md: the tint
            outline = "#f1ece0", -- riso.md: structure is the ink
            shadow = false, -- as by day
            on_band = "#f1ece0", -- no board: the night ink on the night tint
            on_accent = "#f1ece0", -- no board: the night ink on the night tint
            cover = "#22509f", -- no board: the day's blue block, as Diner keeps its cover by night
            on_cover = "#f3eee2", -- no board: the day's paper on it
        },
        grey = {
            paper = "#ffffff", -- riso.md
            ink = "#000000", -- riso.md
            muted = "#333333", -- riso.md
            text = "#000000", -- riso.md
            hairline = false, -- as by day
            hairline_light = "#bbbbbb", -- riso.md
            teal = false, -- as by day
            pink = "#999999", -- riso.md: a1, hatched where it fills a bar (progress.fill_grey)
            mustard = false, -- as by day
            violet = false, -- Frosted's accent; Riso has none
            yellow = false, -- Frosted's accent; Riso has none
            tint = "#dddddd", -- riso.md
            sun = false, -- as by day
            coral = false, -- as sun
            mint = false, -- as sun
            die = false, -- as sun
            band = "#dddddd", -- riso.md: the tint
            outline = "#000000", -- riso.md: structure is the ink
            shadow = false, -- as by day
            on_band = "#000000", -- no board: the ink on the grey tint
            on_accent = "#000000", -- no board: the ink on the grey tint
            cover = "#4a4a4a", -- no board: the direction doc's cover grey, as Diner's and Editorial's
            on_cover = "#ffffff", -- no board: the paper on it
        },
    },

    -- riso.md: 2 px ink tile outlines and pink rules, 3 px for the nav edge and the sheet (their own
    -- tokens, nav.edge_width and sheet.outline_width).
    stroke = {
        hairline = 2, -- riso.md: stroke.hair
        hairline_grey = 2, -- riso.md: stroke.greyHair
        rule = 2, -- riso.md: 2 px pink rules
        outline = 2, -- riso.md: 2 px ink tile outlines
        band = false, -- riso.md: no header band on the home
    },

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide. riso.md:
    -- "misregistration, not shadow": tint 5/4 under tiles, pink 8/8 under the sheet, a 2 px ink
    -- outline 6/6 behind the cover.
    shadow = {
        cover = { x = 6, y = 6, color = "outline", outline_width = 2 }, -- riso.md: cover.under
        tile = { x = 5, y = 4, color = "tint", outline_width = false }, -- riso.md: tile.under
        sheet = { x = 8, y = 8, color = "pink", outline_width = false }, -- riso.md: sheet.under
    },

    -- Display type printed twice, an offset copy in color under the part's own (riso.md: pink 3
    -- right 2 down under display type; in grey the pink's grey, a light ghost).
    misregister = { x = 3, y = 2, color = "pink" }, -- riso.md: misregister

    -- The plates Frosted sets its home rows on (looks/frosted.lua): Riso has none, so its rows
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

    -- The owner's image behind the home (wallpaper.file): Frosted's alone; Riso draws its paper.
    wallpaper = {
        enabled = false, -- the paper, as before the wallpaper setting
    },

    radius = {
        cover = 0, -- riso.md: radius 0
        box = 0, -- riso.md: radius 0
    },

    -- riso.md: a 2 px ink outline with no fill, the tint knocked 5/4 out of register behind it
    -- (shadow.tile), showing through.
    tile = {
        box = true, -- riso.md: tile.style box
        fill_color = false, -- riso.md: tile.fill none
        outline_color = "outline", -- riso.md: tile.borderColor ink
        rule_color = false, -- boxed, not ruled
    },

    -- riso.md: 14 px, 2 px ink outline, pink on paper; in grey a 135° hatch, as Diner's.
    progress = {
        height = 14, -- riso.md: progress.h
        fill_color = "pink", -- riso.md: progress.fill a1
        track_color = "paper", -- riso.md: progress.track
        outline_color = "outline", -- riso.md: progress.outlineColor ink
        outline_width = 2, -- riso.md: progress.outline
        fill_grey = "hatch_135", -- riso.md: a1Fill hatch, angle 135
        -- Square ends: 0 paints the bar through paintRect, as it was before the radius
        -- (Paint.fill with no radius).
        radius = 0,
    },

    -- riso.md: inset 20, a 3 px ink outline, pink 8/8 behind it (shadow.sheet), a tint header band
    -- under a 2 px ink rule, rows ruled in the pink hairline.
    sheet = {
        fill_color = "paper", -- Looks.dc.html:718
        rule_color = false, -- riso.md: an outlined inset box, not a panel under a rule
        rule_width = 0, -- as above
        outline_color = "outline", -- riso.md: sheet.border ink
        outline_width = 3, -- riso.md: sheet.border 3
        header_band = true, -- riso.md: sheet.band tint
        inset = { side = 20, bottom = 20 }, -- riso.md: sheet.inset (Looks.dc.html:715)
        padding = { top = 0, side = 0, bottom = 8 }, -- Looks.dc.html:718, the head spanning the box (:724)
        book_band_color = "tint", -- riso.md: sheet.band
        home_band_color = "tint", -- no board: the book sheet's band
        folder_band_color = "tint", -- no board: the book sheet's band
        quick_settings_band_color = "tint", -- no board: the book sheet's band
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
        row_rule_color = "hairline_light", -- riso.md: sheet.rowRule hairLight
        row_rule_width = 2, -- Looks.dc.html:735, the look's hairline (stroke.hairline)
        last_row_bottom = 12, -- no board: row_padding.y, the box's 8 px foot below (padding.bottom)
        status_chip_color = "tint", -- riso.md: chips are a tint fill
        state_chip_color = "tint", -- riso.md: chips are a tint fill
        chip_padding = { x = 8, y = 4 }, -- Looks.dc.html:659, the chip's padding
        chip_outline_width = 0, -- riso.md: chip.border 0
        selected_fill_color = "tint", -- no board: the lit nav tab's tint (riso.md nav.litColor)
        aside_above_gap = 2, -- no board: Diner's (SortC.dc.html:39)
        sublabel_gap = 2, -- no board: Diner's (SortC.dc.html:46)
        library_folder_band_color = "tint", -- no board: the book sheet's band
        folder_box = {
            size = 60, -- no board: Diner's (HoldFolderC.dc.html:36)
            outline_width = 2, -- no board: the tile's 2 px ink outline (riso.md)
            outline_color = "outline", -- no board: the tile's ink outline
            fill_color = "paper", -- no board: on paper, as the tile
            icon_size = 34, -- no board: Diner's (HoldFolderC.dc.html:37)
            icon_color = "ink", -- no board: riso.md's icons are ink
        },
        library_empty_band_color = "tint", -- no board: the book sheet's band
        sort_chip_color = "tint", -- no board: riso.md's chips are a tint fill
        show_chip_color = "tint", -- no board: riso.md's chips are a tint fill
        radius = 0, -- square: 0 paints the box and its band through paintRect, as before the radius
    },

    -- The quick-settings sheet's body. No board draws Riso's: the sheet's rows and pink rules, its
    -- progress bar for the levels, the tiles' 2 px ink outline for the buttons and tiles, and the
    -- on tile filled tint with ink text as the lit nav tab; the rest Diner's and Editorial's.
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
        button_outline_width = 2, -- no board: riso.md's picker border
        button_outline_color = "outline", -- no board: riso.md's picker border ink
        button_fill_color = "tint", -- no board: riso.md's picker fill
        level_h = 14, -- no board: progress.height
        level_outline_width = 2, -- no board: progress.outline_width
        level_outline_color = "outline", -- no board: progress.outline_color
        level_fill_color = "pink", -- no board: progress.fill_color
        level_track_color = "paper", -- no board: progress.track_color
        grid_gap = 10, -- no board: Editorial's (QuickSettings.dc.html:62)
        grid_padding = { top = 15, bottom = 20 }, -- no board: Diner's
        cell_padding = { top = 14, bottom = 12 }, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_gap = 8, -- no board: Editorial's (QuickSettings.dc.html:63)
        cell_icon_size = 24, -- no board: riso.md's icon size
        cell_outline_width = 2, -- no board: the tile's outline
        cell_outline_color = "outline", -- no board: the tile's ink outline
        cell_fill_color = "paper", -- no board: the sheet's fill_color
        on_fill_color = "tint", -- no board: the lit nav tab's fill (riso.md nav.litColor)
        on_text_color = "ink", -- no board: ink on the tint
    },

    -- riso.md: a tint fill, ink uppercase 700, no border.
    chip = {
        small_caps = false, -- riso.md: label.case upper
        uppercase = true, -- riso.md: label.case upper
        text_color = "ink", -- riso.md: chip.color ink
        fill_color = "tint", -- riso.md: chip.fill tint
        outline_color = false, -- riso.md: chip.border 0
        radius = 0, -- square: 0 paints the chip through paintRect, as before the radius
    },

    -- riso.md: 11 px uppercase 700, 0.12 em, muted.
    label = {
        size = 11, -- riso.md: label.size
        face = "strong", -- riso.md: label.weight 700
        small_caps = false, -- riso.md: label.case upper
        uppercase = true, -- riso.md: label.case upper
        tracking = 0.12, -- riso.md: label.tracking
    },

    -- The home's page (Looks.dc.html:607, :641-697): its margins, the gaps between rows and between
    -- columns, where the free height goes, the header drawn with row 1 and the footer. As Diner's
    -- and Editorial's were (owner, 2026-10-16), the page's top and bottom margins, its row gap, the
    -- quote's padding and the launcher's row gap are tightened to 65 % of the board's, rounded, the
    -- least that fits the default rows above the nav bar at the medium text size on the Colorsoft
    -- and the Paperwhite with the board's 124 px clock (a smaller clock alone doesn't: at 60 px
    -- the stats still don't fit).
    home = {
        -- The body's padding, 36 above, 40 at the sides and 14 above the bar (Looks.dc.html:607);
        -- top and bottom tightened.
        margin = { top = 23, side = 40, bottom = 9 },
        row_gap = 16, -- the body's gap (Looks.dc.html:607; was 24)
        column_gap = 16, -- the header's gap (Looks.dc.html:648)
        free_space = "before_last_row", -- the stats' margin-top: auto (Looks.dc.html:697)
        -- riso.md: no band and no rule; the date and weather left, the clock right, on their bottoms
        -- (Looks.dc.html:648, align-items: flex-end).
        header = {
            band_color = false, -- riso.md: band at the top of the sheet only
            edge_width = 0, -- riso.md: header.rule 0
            edge_color = false, -- riso.md: header.ruleColor none
            rule_color = false, -- riso.md: header.rule 0
            rule_width = 0, -- riso.md: header.rule 0
            rule_space = 0, -- riso.md: header.rule 0
            padding = { top = 0, side = 0, bottom = 0 }, -- Looks.dc.html:648, unpadded
            align = "bottom", -- Looks.dc.html:648
        },
        footer = {
            height = 0, -- riso.md: no footer
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
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role. Display
    -- type (the display face) is misregistered; the labels are the strong face, riso.md's 700.
    type = {
        -- The weekday over the date, the look's label (Looks.dc.html:650).
        date_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- riso.md: 15 px 700, CSS line height 1.1 (Looks.dc.html:651).
        date = { face = "strong", size = 15, uppercase = false, tracking = 0, line_height = 0.1, color = "ink" },
        -- riso.md: 124 px 900, -0.01 em, CSS line height 0.8 (Looks.dc.html:653).
        clock = {
            face = "display", size = 124, uppercase = false, tracking = -0.01, line_height = -0.2, color = "ink",
        },
        -- 14 px Work Sans 500 in the text colour (Looks.dc.html:652).
        weather = { face = "text", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text" },
        -- riso.md: 18 px Work Sans 500, CSS line height 1.35, ink (Looks.dc.html:669).
        quote = { face = "quote", size = 18, uppercase = false, tracking = 0, line_height = 0.35, color = "ink" },
        -- The look's label at 12 px in the text colour (Looks.dc.html:697).
        stats = { face = "strong", size = 12, uppercase = true, tracking = 0.12, line_height = 0, color = "text" },
        -- No board draws a typographic cover: Diner's sizes in the display face on the blue block.
        cover_title = {
            face = "display", size = 24, uppercase = true, tracking = 0.04, line_height = 0.05, color = "on_cover",
        },
        -- no board: Diner's authors line in the strong face
        cover_authors = {
            face = "strong", size = 10, uppercase = true, tracking = 0.12, line_height = 0, color = "on_cover",
        },
        -- no board: the look's label in the first run's dashed frame
        cover_empty = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- "Now reading" in its chip: the label, ink, 700 (Looks.dc.html:659).
        featured_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- riso.md: the title 46 px 900, CSS line height 1.04 (Looks.dc.html:660).
        featured_title = {
            face = "display", size = 46, uppercase = false, tracking = 0, line_height = 0.04, color = "ink",
        },
        -- riso.md: author 16 px Work Sans 500 in the text colour (Looks.dc.html:662).
        featured_authors = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- Not drawn on its own: the chapter joins the authors line (Looks.dc.html:68), in its style.
        featured_chapter = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- 14 px, weight 600 (Work Sans 700 here), the text colour (Looks.dc.html:666).
        featured_caption = {
            face = "strong", size = 14, uppercase = false, tracking = 0, line_height = 0, color = "text",
        },
        -- No board draws Riso's first run: the title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = {
            face = "display", size = 39, uppercase = false, tracking = 0, line_height = 0.04, color = "ink",
        },
        -- no board: the authors line's style at Editorial's first-run line height (EmptyStates.dc.html:37)
        featured_empty_body = {
            face = "text", size = 16, uppercase = false, tracking = 0, line_height = 0.4, color = "text",
        },
        -- no board: the look's label in ink, as the chip's
        featured_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- riso.md: launcher 19 px Work Sans 700, CSS line height 1.1 (Looks.dc.html:683).
        launcher_label = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- Its suffix, "Off", the look's label (Looks.dc.html:694).
        launcher_suffix = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- No board draws Riso's home sheet: the book sheet's title (Looks.dc.html:728) on the band.
        sheet_heading = {
            face = "display", size = 33, uppercase = false, tracking = 0, line_height = 0.05, color = "on_accent",
        },
        -- no board: the look's label on the band (Looks.dc.html:733's last-opened line)
        sheet_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- The title 0.72 of 46 px, CSS line height 1.05 (Looks.dc.html:728).
        sheet_title = {
            face = "display", size = 33, uppercase = false, tracking = 0, line_height = 0.05, color = "on_accent",
        },
        -- 15 px Work Sans in the text colour, the ink (Looks.dc.html:729).
        sheet_author = {
            face = "text", size = 15, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- "62% · Part 3 · opened yesterday": the progress row's 13 px 700 (Looks.dc.html:730).
        sheet_meta = {
            face = "strong", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- riso.md: sheet rows 19 px Work Sans 500, ink (Looks.dc.html:735).
        sheet_row = { face = "text", size = 19, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: a row's plain detail in the look's label
        sheet_detail = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- riso.md: a chip's label, ink on its tint
        sheet_chip = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "on_accent",
        },
        -- no board: sheet_chip in ink, for a chip on paper
        sheet_chip_plain = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- no board: the header's label at its right, the look's label
        sheet_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- no board: a row's second line, Work Sans 500 in muted
        sheet_sublabel = {
            face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted",
        },
        -- no board: a quick-settings bar's label and value, the look's label
        quick_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- no board: the bars' minus and plus, the strong face at Editorial's size (QuickSettings.dc.html:45)
        quick_button = {
            face = "strong", size = 18, uppercase = false, tracking = 0, line_height = 0, color = "ink",
        },
        -- no board: a quick-settings tile's label, the look's label in ink
        quick_cell = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- The editor screens have no Riso board: the header on paper over an ink rule, its title in
        -- the display face, the rest in the look's label, at Editorial's sizes and line height 0.3.
        -- no board: the look's label at Editorial's line height
        editor_aside = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "muted",
        },
        -- no board: Editorial's size and line height in the display face
        editor_title = {
            face = "display", size = 34, uppercase = false, tracking = 0, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label in ink
        editor_button = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "ink",
        },
        -- no board: the look's label
        editor_caption = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "muted",
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
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0.3, color = "muted",
        },
        -- no board: Diner's and Editorial's
        editor_note = {
            face = "text", size = 12, uppercase = false, tracking = 0, line_height = 0.3, color = "muted",
        },
        -- riso.md: nav labels 11 px, the look's label, muted unlit (Looks.dc.html:617, :622).
        nav_label = { face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted" },
        -- The lit tab's label in ink (Looks.dc.html:617); the board's 800 is Work Sans 700 here.
        nav_label_active = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- No board draws Riso's file browser: the library's (Looks.dc.html:744-749).
        -- The book count, the look's label (Looks.dc.html:747).
        title_bar_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- The library's title, 56 px, CSS line height 0.95 (Looks.dc.html:746).
        title_bar_title = {
            face = "display", size = 56, uppercase = false, tracking = 0, line_height = -0.05, color = "ink",
        },
        -- A picker's label, ink 700 (Looks.dc.html:749).
        title_bar_sort = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- The status picker's, as the sort's (Looks.dc.html:749).
        title_bar_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- The library's parts (Looks.dc.html:744-790). The count, the look's label (:747).
        library_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- The title, 56 px, CSS line height 0.95 (Looks.dc.html:746).
        library_title = {
            face = "display", size = 56, uppercase = false, tracking = 0, line_height = -0.05, color = "ink",
        },
        -- A picker's label, ink 700 (Looks.dc.html:749).
        library_picker = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- The status picker's, as the sort's (Looks.dc.html:749).
        library_picker_status = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
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
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- no board: "Page 1 of 24", the look's label in ink
        pager_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- The series and authors screens have no Riso board: the library's header and the home's
        -- tiles, by analogy.
        -- no board: the featured title's size, CSS line height 0.95 as the library's title
        shelf_detail_title = {
            face = "display", size = 46, uppercase = false, tracking = 0, line_height = -0.05, color = "ink",
        },
        -- no board: the look's label in ink, as a picker's
        shelf_back = { face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "ink" },
        -- no board: the library folder's name (Looks.dc.html:766)
        series_name = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- no board: Work Sans 500 in muted
        series_sub = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- no board: a chip's label, ink on its tint
        shelf_chip = {
            face = "strong", size = 10, uppercase = true, tracking = 0.12, line_height = 0, color = "on_accent",
        },
        -- no board: a chip's label on paper
        shelf_chip_plain = {
            face = "strong", size = 10, uppercase = true, tracking = 0.12, line_height = 0, color = "ink",
        },
        -- no board: a book's series index, Diner's size in the display face
        book_index = { face = "display", size = 40, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: the library folder's name (Looks.dc.html:766)
        book_row_title = {
            face = "strong", size = 19, uppercase = false, tracking = 0, line_height = 0.1, color = "ink",
        },
        -- no board: "read this one next" in the look's label on the tint row; Riso has no accent face
        book_next_note = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "on_accent",
        },
        -- no board: series_sub's style
        book_row_note = { face = "text", size = 13, uppercase = false, tracking = 0, line_height = 0, color = "muted" },
        -- no board: a group's letter on its tint column, in the display face
        author_letter = {
            face = "display", size = 28, uppercase = false, tracking = 0, line_height = 0, color = "on_accent",
        },
        -- no board: Diner's
        author_name = { face = "strong", size = 17, uppercase = false, tracking = 0, line_height = 0, color = "ink" },
        -- no board: the look's label
        author_count = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- no board: the look's label, as the pager's
        shelf_empty = {
            face = "strong", size = 12, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
        -- no board: the header's static label, the look's label
        shelf_label = {
            face = "strong", size = 11, uppercase = true, tracking = 0.12, line_height = 0, color = "muted",
        },
    },

    -- riso.md: three columns of 84 px boxed tiles, the icon at the top and the label at the foot
    -- (Looks.dc.html:674-694).
    launcher = {
        columns = 3, -- riso.md: tile.cols
        column_gap = 16, -- Looks.dc.html:674
        row_gap = 10, -- Looks.dc.html:674, 16 for boxed tiles; tightened with the home (home above)
        icon_size = 24, -- riso.md: icons 24 px
        icon_gap = false, -- the icon sits above the label, not beside it (Looks.dc.html:680)
        padding = { x = 12, y = 11 }, -- Looks.dc.html:680
        tile_height = 84, -- riso.md: tile.h
        accent_1_color = false, -- riso.md: every tile alike
        accent_2_color = false, -- riso.md: every tile alike
        accent_3_color = false, -- riso.md: every tile alike
        suffix_gap = 6, -- no board: Editorial's (EmptyStates.dc.html:65)
        -- On the label's line: the board's sub-label under it (Looks.dc.html:682) runs into the icon
        -- in an 84 px tile at KOReader's line heights.
        suffix_below = false,
        -- No badge: a size of 0 draws the tile's icon bare, as the tiles were before badges.
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

    -- The quote between 2 px pink rules (riso.md: quote.style ruleBoth), 14 px between the rules and
    -- the text (Looks.dc.html:668), tightened with the home (home above).
    quote = {
        padding = 9, -- Looks.dc.html:668; was 14
        rule_width = 2, -- riso.md: quote.rule
        rule_color = "hairline_light", -- riso.md: quote.ruleColor hairLight
    },

    -- The featured book's cover box (riso.md: 150 × 225, no outline, radius 0).
    featured = {
        cover_w = 150, -- riso.md: cover.w
        cover_h = 225, -- riso.md: cover.h
        cover_padding = { x = 10, y = 10 }, -- the cover's padding (Looks.dc.html:639)
        cover_outline_color = false, -- riso.md: cover.outline 0
        dash = 4, -- no board: Diner's and Editorial's first-run frame
        dash_gap = 4, -- no board: Diner's and Editorial's first-run frame
        gap = 24, -- Looks.dc.html:655
        column_padding_y = 2, -- the text column's top padding (Looks.dc.html:657)
        title_gap = 12, -- the chip's margin below it (Looks.dc.html:659)
        chip_outline = 0, -- riso.md: chip.border 0, a tint chip
        chip_padding = { x = 8, y = 4 }, -- Looks.dc.html:659
        button_padding = { x = 14, y = 9 }, -- no board: Diner's and Editorial's (EmptyStates.dc.html:38)
        button_fill_color = "tint", -- no board: riso.md's picker fill
        button_outline_color = "outline", -- no board: riso.md's picker border ink
    },
    -- The editor screens, edit layout and launcher management. No board draws Riso's: the header
    -- on paper over a 3 px ink rule (no band, riso.md: "tint band at the top of the sheet only"),
    -- 2 px ink outlines with the tile's tint knocked out of register behind cards, the selected card
    -- tint; spacing as Editorial's boards give it.
    editor = {
        padding = { top = 40, side = 40, bottom = 28 }, -- no board: Editorial's
        header_band_color = false, -- no board: riso.md's band is the sheet's only
        header_text_color = false, -- no board: no band
        header_rule_color = "outline", -- no board: riso.md's ink structure
        header_rule_width = 3, -- no board: riso.md's 3 px nav edge
        header_gap = 16, -- no board: Editorial's
        body_gap = 18, -- no board: Editorial's
        button_outline_color = "outline", -- no board: riso.md's picker border ink
        button_outline_width = 2, -- no board: riso.md's picker border
        button_fill_color = "tint", -- no board: riso.md's picker fill
        button_padding = { x = 14, y = 8 }, -- no board: Editorial's
        card_gap = 10, -- no board: Diner's, so the default layout's five rows fit with one selected
        card_padding = { x = 14, y = 12 }, -- no board: Editorial's
        card_outline_color = "outline", -- no board: the tile's ink outline
        card_outline_width = 2, -- no board: the tile's outline
        card_shadow = { x = 5, y = 4, color = "tint" }, -- no board: the tile's tint out of register
        selected_outline_color = "outline", -- no board: the tile's ink outline
        selected_fill_color = "tint", -- no board: the lit nav tab's tint
        arrow_size = 28, -- no board: Editorial's
        arrow_gap = 14, -- no board: Editorial's
        disabled_color = "muted", -- no board: Riso's quietest text
        box_padding = { x = 12, y = 10 }, -- no board: Editorial's
        box_gap = 8, -- no board: Editorial's
        row_padding = { y = 14 }, -- no board: Editorial's
        row_rule_color = "hairline_light", -- no board: the sheet's pink row rules
        row_rule_width = 2, -- no board: the sheet's row rules
        icon_size = 22, -- no board: Editorial's
        icon_gap = 14, -- no board: Editorial's
        control_size = 30, -- no board: Editorial's
        kind_gap = 8, -- no board: Editorial's
        kind_columns = 2, -- no board: Editorial's
    },
    -- The nav bar: a 3 px ink edge over paper, five tabs of an icon over a label, the lit tab filled
    -- tint, its icon and label ink and the rest muted (riso.md; Looks.dc.html:608-622).
    nav = {
        fill_color = "paper", -- Looks.dc.html:608
        edge_width = 3, -- riso.md: nav.edge
        edge_color = "ink", -- Looks.dc.html:608
        padding_x = 0, -- the bar is unpadded at its sides (Looks.dc.html:608)
        -- The 84 px bar less its edge, icon, gap and label line, shared above and below the tab's
        -- centred content (Looks.dc.html:584, :620).
        padding_top = 17,
        padding_bottom = 17, -- as padding_top
        icon_size = 24, -- riso.md: nav_size 24
        icon_gap = 7, -- Looks.dc.html:620
        icon_color = "muted", -- riso.md: nav_unlit muted
        active_icon_color = "ink", -- Looks.dc.html:617
        active_rule_width = 0, -- riso.md: nav.bar 0
        active_rule_color = false, -- riso.md: nav.bar 0
        active_fill_color = "tint", -- riso.md: nav.lit fill, litColor tint
        divider_width = 0, -- no dividers between tabs (Looks.dc.html:620)
        divider_color = false, -- no dividers
        -- A bar across the screen's bottom, not Toybox's floating pill: float false paints the band
        -- and its tabs as the bar did before the pill, and the pill's tokens are none.
        float = false,
        margin = { side = 0, bottom = 0 }, -- no pill: the bar meets the screen's sides and bottom
        radius = 0, -- no pill
        float_fill_color = false, -- no pill
        shadow = { x = 0, y = 0, color = false }, -- no pill
        tab_gap = 0, -- the tabs share the width with no gap, as before the pill
        active_outline_width = 0, -- the lit tab is not outlined, as before the pill
        active_outline_color = false, -- not outlined
    },
    -- The file browser's title bar. No board draws Riso's: the library's header (Looks.dc.html:744-749),
    -- a count and a 56 px title on paper with no rule, the pickers boxed in 2 px ink on tint.
    title_bar = {
        fill_color = "paper", -- no board: the library's header on paper
        padding = { top = 36, side = 40, bottom = 16 }, -- no board: the home's top margin and the sides
        edge_width = 0, -- no board: riso.md's header.rule 0
        edge_color = false, -- no board: no edge
        line_gap = 4, -- no board: the library header's gap (Looks.dc.html:745)
        picker_gap = 8, -- no board: the library's pickers' gap (Looks.dc.html:131)
        sort_fill_color = "tint", -- no board: riso.md's picker fill
        status_fill_color = "tint", -- no board: riso.md's picker fill
        picker_outline_width = 2, -- no board: riso.md's picker border
        picker_outline_color = "outline", -- no board: riso.md's picker border ink
        picker_padding = { x = 10, y = 7 }, -- no board: Looks.dc.html:749
        icon_size = 16, -- no board draws the plus: the pickers' size
        icon_color = "ink", -- no board draws the plus: the pickers' ink
        count_on_shelf = false, -- no board: "148 books", as the library's (Looks.dc.html:129)
        picker_radius = 0, -- square: 0 paints the pickers through paintRect, as before the radius
    },
    -- The library (Looks.dc.html:740-790): a 56 px title and count on paper with no rule, the
    -- pickers boxed in 2 px ink on tint, three columns of covers each with its ink outline out of
    -- register, a pink strip under each, and a pager of boxes above the nav bar.
    library = {
        header = {
            fill_color = false, -- the page under the header (Looks.dc.html:744)
            padding = { top = 36, side = 40, bottom = 16 }, -- the body's padding (Looks.dc.html:607)
            edge_width = 0, -- riso.md: header.rule 0 (Looks.dc.html:744)
            edge_color = false, -- no edge
            line_gap = 4, -- Looks.dc.html:745
            picker_gap = 8, -- Looks.dc.html:131
            picker_padding = { x = 10, y = 7 }, -- Looks.dc.html:749
            picker_outline_width = 2, -- riso.md: picker.border
            picker_outline_color = "outline", -- riso.md: picker.borderColor ink
            sort_fill_color = "tint", -- riso.md: picker.fill tint
            status_fill_color = "tint", -- riso.md: picker.fill tint
            picker_radius = 0, -- square: 0 paints the pickers through paintRect, as before the radius
        },
        grid = {
            padding_top = 28, -- the body's gap and the grid's margin (Looks.dc.html:607, :751)
            side = 40, -- Looks.dc.html:607
            row_gap = 22, -- Looks.dc.html:751
            column_gap = 20, -- Looks.dc.html:751
            cover_h = 195, -- no board: Diner's (D2), so two rows fit; the board's 255 fits one
            strip_gap = 12, -- the item's 8 px gap and the strip's offset outline below the cover (Looks.dc.html:752)
            title_gap = 8, -- the item's gap (Looks.dc.html:752)
        },
        -- The board's 2:3 covers fill their box (Looks.dc.html:750); at Diner's 195 a cover is fitted
        -- in its box on paper, so the box takes the tiles' 2 px ink outline and the offset outline
        -- reads against it rather than standing off the artwork.
        cover = {
            outline_width = 2, -- no board: the tiles' outline (riso.md)
            outline_color = "outline", -- no board: the tiles' ink outline
            radius = 0, -- riso.md: cover.radius 0
            shadow = { x = 6, y = 6, color = "outline", outline_width = 2 }, -- riso.md: cover.under
            padding = { x = 10, y = 10 }, -- the cover's padding (Looks.dc.html:639)
        },
        strip = {
            height = 8, -- the strip: the bar's height at most 8 (Looks.dc.html:767)
            outline_width = 2, -- Looks.dc.html:767
        },
        -- The folder's tile (Looks.dc.html:754-766): its 2 px ink outline on paper. Its shadow is the
        -- covers' (library.cover.shadow), not the board's tint 5/4.
        folder = {
            fill_color = false, -- Looks.dc.html:754, transparent
            outline_width = 2, -- Looks.dc.html:756
            outline_color = "outline", -- Looks.dc.html:756
            icon_size = 28, -- Looks.dc.html:790
            icon_color = "ink", -- Looks.dc.html:790
            padding = { x = 14, y = 14 }, -- Looks.dc.html:756
            count_gap = 4, -- the name's margin (Looks.dc.html:766)
        },
        badge = {
            size = 34, -- no board: Diner's overhanging badge, a size down for the 2 px stroke
            outline_width = 2, -- no board: the tile's outline
            outline_color = "outline", -- no board: the tile's ink outline
            fill_color = "tint", -- no board: riso.md's picker fill
            icon_size = 20, -- no board: Diner's
            icon_color = "ink", -- no board: riso.md's ink icons
            inset = -10, -- no board: Diner's overhang, a size down
            align = "top", -- no board: Diner's
        },
        not_downloaded = {
            outline_color = false, -- no board: riso.md's chips have no border
            padding = { x = 8, y = 4 }, -- no board: the chip's padding (Looks.dc.html:659)
        },
        pager = {
            button_w = 44, -- no board: Diner's
            button_h = 32, -- no board: Diner's
            gap = 18, -- no board: Diner's
            bottom = 16, -- no board: Diner's
            outline_width = 2, -- no board: riso.md's picker border
            outline_color = "outline", -- no board: riso.md's picker border ink
            prev_fill_color = "paper", -- no board: Diner's paper box
            next_fill_color = "tint", -- no board: riso.md's picker fill
            dead_color = false, -- no board: Diner's, a dead arrow left out
            prev_icon_color = "ink", -- no board: riso.md's ink icons
            next_icon_color = "ink", -- no board: riso.md's ink icons
            label_in_words = true, -- no board: Diner's "Page 1 of 24"
        },
    },
    -- The series and authors screens. No board draws Riso's: the library's header on paper, rows
    -- and groups boxed as the home's tiles (2 px ink, the tint out of register behind, unfilled),
    -- tint chips and letters, the up-next book on tint.
    shelf = {
        series_fill_color = false, -- no board: the library's header on paper
        authors_fill_color = false, -- no board: the library's header on paper
        detail = {
            padding = { top = 36, side = 40, bottom = 16 }, -- no board: the library header's
            back_gap = 10, -- no board: Diner's
        },
        back = {
            fill_color = "tint", -- no board: riso.md's picker fill
            outline_width = 2, -- no board: riso.md's picker border
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
            outline_width = 2, -- no board: the tile's outline
            shadow = { x = 5, y = 4 }, -- no board: the tile's tint offset (shadow.tile)
            rule_width = 0, -- no board: boxed, not ruled
            rule_color = "outline", -- no board: unused at rule_width 0
        },
        stack = {
            cover_w = 38, -- no board: Diner's
            cover_h = 56, -- no board: Diner's
            offset_x = 10, -- no board: Diner's
            offset_y = 2, -- no board: Diner's
            outline_width = 2, -- no board: the tile's outline
            outline_color = "outline", -- no board: the tile's ink outline
        },
        chip = {
            padding = { x = 8, y = 2 }, -- no board: the chip's padding, shorter in a row
            outline_width = 0, -- no board: riso.md's chips have no border
            under_way_fill_color = "tint", -- no board: riso.md's chips are a tint fill
            finished_fill_color = "tint", -- no board: riso.md's chips are a tint fill
            not_started_fill_color = "paper", -- no board: Diner's paper chip
            up_next_fill_color = "tint", -- no board: riso.md's chips are a tint fill
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
            cover_outline_width = 0, -- no board: riso.md's covers have no outline
            line_gap = 6, -- no board: Diner's
            bar_height = 8, -- no board: the library's strip
            bar_outline_width = 2, -- no board: the library's strip
            badge_size = 28, -- no board: Diner's
            badge_outline_width = 2, -- no board: the tile's outline
            badge_icon_size = 14, -- no board: Diner's
            badge_inset = -10, -- no board: Diner's overhang
        },
        next = {
            fill_color = "tint", -- no board: riso.md's tint fill
            shadow = { x = 5, y = 4 }, -- no board: the tile's tint offset
            line_gap = 4, -- no board: Diner's
            text_color = "on_accent", -- no board: ink on the tint
        },
        groups = {
            padding_top = 28, -- no board: the library grid's
            gap = 16, -- no board: the launcher's row gap
        },
        group = {
            outline_width = 2, -- no board: the tile's outline
            shadow = { x = 5, y = 4 }, -- no board: the tile's tint offset
            rule_width = 0, -- no board: boxed, not ruled
            rule_color = "outline", -- no board: unused at rule_width 0
            letter_w = 48, -- no board: Diner's
            letter_fill_color = "tint", -- no board: riso.md's tint fill
            letter_rule_width = 2, -- no board: the tile's outline
        },
        author = {
            padding = { x = 16, y = 11 }, -- no board: Diner's
            rule_width = 2, -- no board: the sheet's row rules
            rule_color = "hairline_light", -- no board: the sheet's pink row rules
        },
        author_grid = {
            cover_h = 174, -- no board: Diner's, the library's less the one-author header
        },
        up_next = {
            fill_color = "tint", -- no board: riso.md's chips are a tint fill
            outline_width = 0, -- no board: riso.md's chips have no border
        },
    },
}
