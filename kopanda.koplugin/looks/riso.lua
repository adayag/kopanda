-- Riso: a two-drum Risograph, blue ink and fluoro pink on cream, no black anywhere, the pink
-- always a few pixels out of register. Pure data, typed from the design's token table and Lua
-- export (.tiller/design/2026-10-19-kopanda-looks/riso.md) and its boards in the design file
-- (`KoPanda Looks.dc.html` beside it, cited "Looks.dc.html:<line>"); where neither gives a value,
-- the line's comment says "no board" and names the analogy. It declares only what differs from
-- the base look (looks/base.lua), which holds every other token.
return {
    -- riso.md: Big Shoulders Display 900, Work Sans 500 and 700, no accent face.
    faces = {
        display = { file = "fonts/big-shoulders-display/BigShouldersDisplay-Black.ttf", -- riso.md
            label = "Big Shoulders Display 900" }, -- riso.md
        text = { file = "fonts/work-sans/WorkSans-Medium.ttf", label = "Work Sans 500" }, -- riso.md
        strong = { file = "fonts/work-sans/WorkSans-Bold.ttf", label = "Work Sans 700" }, -- riso.md
        -- riso.md's quote is Work Sans 500 italic; no Work Sans italic is vendored, so it is set upright.
        quote = { file = "fonts/work-sans/WorkSans-Medium.ttf", label = "Work Sans 500" },
    },

    icons = { set = "phosphor-fill" }, -- riso.md: Phosphor Fill, chosen first

    -- riso.md's export palettes: its hairLight is hairline_light, its a1 the pink, its tint the
    -- tint. Structure is the ink, so outline, on_band and on_accent are the ink, and the band is
    -- the tint (the sheet's header band, riso.md "Band").
    palettes = {
        day = {
            paper = "#f3eee2", -- riso.md
            ink = "#22509f", -- riso.md: the blue drum, never black
            muted = "#3d5b9a", -- riso.md
            text = "#22509f", -- riso.md: text is the ink
            hairline_light = "#f2a9c4", -- riso.md: pink for secondary rules
            pink = "#e9508a", -- riso.md: fluoro pink, a1
            tint = "#f6c6d8", -- riso.md: pink tint
            band = "#f6c6d8", -- riso.md: the tint band at the top of the sheet
            outline = "#22509f", -- riso.md: structure is ink
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
            hairline_light = "#6e3557", -- riso.md
            pink = "#f0729f", -- riso.md
            tint = "#4a2643", -- riso.md
            band = "#4a2643", -- riso.md: the tint
            outline = "#f1ece0", -- riso.md: structure is the ink
            on_band = "#f1ece0", -- no board: the night ink on the night tint
            on_accent = "#f1ece0", -- no board: the night ink on the night tint
            cover = "#22509f", -- no board: the day's blue block, as Diner keeps its cover by night
            on_cover = "#f3eee2", -- no board: the day's paper on it
        },
        grey = {
            hairline_light = "#bbbbbb", -- riso.md
            pink = "#999999", -- riso.md: a1, hatched where it fills a bar (progress.fill_grey)
            tint = "#dddddd", -- riso.md
            band = "#dddddd", -- riso.md: the tint
            on_band = "#000000", -- no board: the ink on the grey tint
        },
    },

    -- riso.md: 2 px ink tile outlines and pink rules, 3 px for the nav edge and the sheet (their own
    -- tokens, nav.edge_width and sheet.outline_width).
    stroke = {
        hairline = 2, -- riso.md: stroke.hair
        outline = 2, -- riso.md: 2 px ink tile outlines
    },

    -- A shadow is a fill at its offset, or with an outline_width an outline that wide. riso.md:
    -- "misregistration, not shadow": tint 5/4 under tiles, pink 8/8 under the sheet, a 2 px ink
    -- outline 6/6 behind the cover.
    shadow = {
        cover = { color = "outline", outline_width = 2 }, -- riso.md: cover.under
        tile = { x = 5, y = 4, color = "tint" }, -- riso.md: tile.under
        sheet = { x = 8, color = "pink" }, -- riso.md: sheet.under
    },

    -- Display type printed twice, an offset copy in color under the part's own (riso.md: pink 3
    -- right 2 down under display type; in grey the pink's grey, a light ghost).
    misregister = { x = 3, y = 2, color = "pink" }, -- riso.md: misregister

    -- riso.md: a 2 px ink outline with no fill, the tint knocked 5/4 out of register behind it
    -- (shadow.tile), showing through.
    tile = { fill_color = false }, -- riso.md: tile.fill none

    -- riso.md: 14 px, 2 px ink outline, pink on paper; in grey a 135° hatch, as Diner's.
    progress = { fill_color = "pink" }, -- riso.md: progress.fill a1

    -- riso.md: inset 20, a 3 px ink outline, pink 8/8 behind it (shadow.sheet), a tint header band
    -- under a 2 px ink rule, rows ruled in the pink hairline.
    sheet = {
        inset = { side = 20, bottom = 20 }, -- riso.md: sheet.inset (Looks.dc.html:715)
        book_band_color = "tint", -- riso.md: sheet.band
        home_band_color = "tint", -- no board: the book sheet's band
        folder_band_color = "tint", -- no board: the book sheet's band
        quick_settings_band_color = "tint", -- no board: the book sheet's band
        status_chip_color = "tint", -- riso.md: chips are a tint fill
        state_chip_color = "tint", -- riso.md: chips are a tint fill
        chip_outline_width = 0, -- riso.md: chip.border 0
        selected_fill_color = "tint", -- no board: the lit nav tab's tint (riso.md nav.litColor)
        library_folder_band_color = "tint", -- no board: the book sheet's band
        library_empty_band_color = "tint", -- no board: the book sheet's band
        sort_chip_color = "tint", -- no board: riso.md's chips are a tint fill
        show_chip_color = "tint", -- no board: riso.md's chips are a tint fill
    },

    -- The quick-settings sheet's body. No board draws Riso's: the sheet's rows and pink rules, its
    -- progress bar for the levels, the tiles' 2 px ink outline for the buttons and tiles, and the
    -- on tile filled tint with ink text as the lit nav tab; the rest Diner's and Editorial's.
    quick_settings = {
        button_fill_color = "tint", -- no board: riso.md's picker fill
        level_fill_color = "pink", -- no board: progress.fill_color
        on_fill_color = "tint", -- no board: the lit nav tab's fill (riso.md nav.litColor)
    },

    -- riso.md: a tint fill, ink uppercase 700, no border.
    chip = {
        fill_color = "tint", -- riso.md: chip.fill tint
        outline_color = false, -- riso.md: chip.border 0
    },

    -- riso.md: 11 px uppercase 700, 0.12 em, muted.
    label = { tracking = 0.12 }, -- riso.md: label.tracking

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
        margin = { top = 23, bottom = 9 },
        row_gap = 16, -- the body's gap (Looks.dc.html:607; was 24)
    },

    -- The home widgets' text, per part: a face role, a size in board pixels (before text_size),
    -- case, tracking in em, line height as KOReader's TextBoxWidget counts it (extra space in
    -- em, frontend/ui/widget/textboxwidget.lua:48, so CSS 1.4 is 0.4) and a palette role. Display
    -- type (the display face) is misregistered; the labels are the strong face, riso.md's 700.
    type = {
        -- The weekday over the date, the look's label (Looks.dc.html:650).
        date_label = { tracking = 0.12 },
        -- riso.md: 15 px 700, CSS line height 1.1 (Looks.dc.html:651).
        date = { size = 15 },
        -- riso.md: 124 px 900, -0.01 em, CSS line height 0.8 (Looks.dc.html:653).
        clock = { size = 124, tracking = -0.01 },
        stats = { tracking = 0.12 },
        cover_empty = { tracking = 0.12 },
        -- "Now reading" in its chip: the label, ink, 700 (Looks.dc.html:659).
        featured_label = { face = "strong", tracking = 0.12 },
        -- riso.md: the title 46 px 900, CSS line height 1.04 (Looks.dc.html:660).
        featured_title = { size = 46 },
        -- No board draws Riso's first run: the title's face at Diner's 24/28 of its size, and its line height.
        featured_empty_title = { size = 39 },
        -- Its suffix, "Off", the look's label (Looks.dc.html:694).
        launcher_suffix = { tracking = 0.12 },
        -- No board draws Riso's home sheet: the book sheet's title (Looks.dc.html:728) on the band.
        sheet_heading = { size = 33 },
        sheet_aside = { tracking = 0.12 },
        -- The title 0.72 of 46 px, CSS line height 1.05 (Looks.dc.html:728).
        sheet_title = { size = 33 },
        -- riso.md: sheet rows 19 px Work Sans 500, ink (Looks.dc.html:735).
        sheet_row = { size = 19 },
        sheet_detail = { tracking = 0.12 },
        -- riso.md: a chip's label, ink on its tint
        sheet_chip = { tracking = 0.12 },
        sheet_chip_plain = { tracking = 0.12 },
        sheet_label = { tracking = 0.12 },
        -- no board: a quick-settings tile's label, the look's label in ink
        quick_cell = { tracking = 0.12 },
        -- The editor screens have no Riso board: the header on paper over an ink rule, its title in
        -- the display face, the rest in the look's label, at Editorial's sizes and line height 0.3.
        -- no board: the look's label at Editorial's line height
        editor_aside = { tracking = 0.12 },
        editor_kind = { tracking = 0.12 },
        -- No board draws Riso's file browser: the library's (Looks.dc.html:744-749).
        -- The book count, the look's label (Looks.dc.html:747).
        title_bar_count = { tracking = 0.12 },
        -- The library's title, 56 px, CSS line height 0.95 (Looks.dc.html:746).
        title_bar_title = { size = 56 },
        -- The library's parts (Looks.dc.html:744-790). The count, the look's label (:747).
        library_count = { tracking = 0.12 },
        -- The title, 56 px, CSS line height 0.95 (Looks.dc.html:746).
        library_title = { size = 56 },
        folder_reading = { tracking = 0.12 },
        pager_label = { tracking = 0.12 },
        -- The series and authors screens have no Riso board: the library's header and the home's
        -- tiles, by analogy.
        -- no board: the featured title's size, CSS line height 0.95 as the library's title
        shelf_detail_title = { size = 46 },
        shelf_back = { tracking = 0.12 },
        -- no board: the library folder's name (Looks.dc.html:766)
        series_name = { face = "strong" },
        -- no board: a chip's label, ink on its tint
        shelf_chip = { tracking = 0.12 },
        shelf_chip_plain = { tracking = 0.12 },
        -- no board: the library folder's name (Looks.dc.html:766)
        book_row_title = { face = "strong" },
        -- no board: "read this one next" in the look's label on the tint row; Riso has no accent face
        book_next_note = { tracking = 0.12 },
        shelf_empty = { tracking = 0.12 },
    },

    -- riso.md: three columns of 84 px boxed tiles, the icon at the top and the label at the foot
    -- (Looks.dc.html:674-694).
    launcher = {
        row_gap = 10, -- Looks.dc.html:674, 16 for boxed tiles; tightened with the home (home above)
        icon_size = 24, -- riso.md: icons 24 px
        padding = { x = 12 }, -- Looks.dc.html:680
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
        cover_outline_color = false, -- riso.md: cover.outline 0
        chip_outline = 0, -- riso.md: chip.border 0, a tint chip
        chip_padding = { x = 8 }, -- Looks.dc.html:659
        button_fill_color = "tint", -- no board: riso.md's picker fill
    },

    -- The editor screens, edit layout and launcher management. No board draws Riso's: the header
    -- on paper over a 3 px ink rule (no band, riso.md: "tint band at the top of the sheet only"),
    -- 2 px ink outlines with the tile's tint knocked out of register behind cards, the selected card
    -- tint; spacing as Editorial's boards give it.
    editor = {
        button_fill_color = "tint", -- no board: riso.md's picker fill
        card_outline_width = 2, -- no board: the tile's outline
        card_shadow = { x = 5, y = 4, color = "tint" }, -- no board: the tile's tint out of register
        selected_fill_color = "tint", -- no board: the lit nav tab's tint
    },

    -- The nav bar: a 3 px ink edge over paper, five tabs of an icon over a label, the lit tab filled
    -- tint, its icon and label ink and the rest muted (riso.md; Looks.dc.html:608-622).
    nav = { active_fill_color = "tint" }, -- riso.md: nav.lit fill, litColor tint

    -- The file browser's title bar. No board draws Riso's: the library's header (Looks.dc.html:744-749),
    -- a count and a 56 px title on paper with no rule, the pickers boxed in 2 px ink on tint.
    title_bar = {
        sort_fill_color = "tint", -- no board: riso.md's picker fill
        status_fill_color = "tint", -- no board: riso.md's picker fill
    },

    -- The library (Looks.dc.html:740-790): a 56 px title and count on paper with no rule, the
    -- pickers boxed in 2 px ink on tint, three columns of covers each with its ink outline out of
    -- register, a pink strip under each, and a pager of boxes above the nav bar.
    library = {
        header = {
            sort_fill_color = "tint", -- riso.md: picker.fill tint
            status_fill_color = "tint", -- riso.md: picker.fill tint
        },
        -- The board's 2:3 covers fill their box (Looks.dc.html:750); at Diner's 195 a cover is fitted
        -- in its box on paper, so the box takes the tiles' 2 px ink outline and the offset outline
        -- reads against it rather than standing off the artwork.
        cover = {
            outline_width = 2, -- no board: the tiles' outline (riso.md)
            shadow = { x = 6, color = "outline", outline_width = 2 }, -- riso.md: cover.under
        },
        -- The folder's tile (Looks.dc.html:754-766): its 2 px ink outline on paper. Its shadow is the
        -- covers' (library.cover.shadow), not the board's tint 5/4.
        folder = {
            fill_color = false, -- Looks.dc.html:754, transparent
            outline_width = 2, -- Looks.dc.html:756
        },
        badge = { fill_color = "tint" }, -- no board: riso.md's picker fill
        not_downloaded = {
            outline_color = false, -- no board: riso.md's chips have no border
            padding = { x = 8 }, -- no board: the chip's padding (Looks.dc.html:659)
        },
        pager = { next_fill_color = "tint" }, -- no board: riso.md's picker fill
    },

    -- The series and authors screens. No board draws Riso's: the library's header on paper, rows
    -- and groups boxed as the home's tiles (2 px ink, the tint out of register behind, unfilled),
    -- tint chips and letters, the up-next book on tint.
    shelf = {
        detail = { padding = { top = 36 } }, -- no board: the library header's
        back = { fill_color = "tint" }, -- no board: riso.md's picker fill
        row = {
            outline_width = 2, -- no board: the tile's outline
            shadow = { x = 5, y = 4 }, -- no board: the tile's tint offset (shadow.tile)
        },
        chip = {
            outline_width = 0, -- no board: riso.md's chips have no border
            under_way_fill_color = "tint", -- no board: riso.md's chips are a tint fill
            finished_fill_color = "tint", -- no board: riso.md's chips are a tint fill
            up_next_fill_color = "tint", -- no board: riso.md's chips are a tint fill
        },
        next = {
            fill_color = "tint", -- no board: riso.md's tint fill
            shadow = { x = 5, y = 4 }, -- no board: the tile's tint offset
        },
        groups = { gap = 16 }, -- no board: the launcher's row gap
        group = {
            outline_width = 2, -- no board: the tile's outline
            shadow = { x = 5, y = 4 }, -- no board: the tile's tint offset
            letter_fill_color = "tint", -- no board: riso.md's tint fill
        },
        up_next = {
            fill_color = "tint", -- no board: riso.md's chips are a tint fill
            outline_width = 0, -- no board: riso.md's chips have no border
        },
    },
}
