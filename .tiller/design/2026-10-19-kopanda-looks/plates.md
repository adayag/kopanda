# 3a Plates · Wallpaper look

Your wallpaper fills the screen; every row sits on an opaque plate with an ink keyline and a paper halo. Nothing is ever printed on the image.

## Token table (board px)

| Token | Value |
|---|---|
| Display face | Atkinson Hyperlegible 700 |
| Text face | Atkinson Hyperlegible 400–700 + italic |
| Accent face | none |
| Paper / Ink | plate #fbfaf6 / #1b1a1f |
| Muted / Text | #4d4b55 / ink |
| Hairline | #d9d6df (sheet rows only) |
| Accents | violet #6b55c8 (progress), yellow #f2c230 (chip, lit tab) |
| Band | none; the wallpaper is the band |
| Stroke | 2 px ink keyline on every plate, 4 px paper halo outside it, 3 px ink nav edge |
| Shadow | none (sheet only: ink 5/7 beyond the halo) |
| Radius | 12 plates and tiles, 16 sheet, 999 chip/pill/progress, 0 cover |
| Tile | opaque plate: paper fill, 2 px ink keyline, 4 px paper halo; 14 px gutters show the wallpaper |
| Progress | 12 px pill, 2 px ink outline, violet on paper |
| Sheet | plate inset 16, radius 16, 4 px halo |
| Chip | yellow pill, 2 px ink, uppercase 700 |
| Labels | 11 px uppercase 700, 0.08 em |
| Date/clock | 18 px 700 / 84 px 700, on the header plate |

## Icon sets (chosen first)

- Phosphor Bold: MIT, github.com/phosphor-icons/core, npm @phosphor-icons/core, e.g. https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/bold/NAME-bold.svg. Heavy round strokes; friendlier than the grid wants.
- Material Symbols Rounded, 700: Apache-2.0, github.com/google/material-design-icons, npm @material-symbols/svg-700, e.g. https://cdn.jsdelivr.net/npm/@material-symbols/svg-700@0.27.0/rounded/NAME.svg. A thick, rounded, inked outline, like the brush-pen lettering in comic panels.
- Tabler Outline: MIT, github.com/tabler/tabler-icons, npm @tabler/icons, e.g. https://cdn.jsdelivr.net/npm/@tabler/icons@3.24.0/icons/outline/NAME.svg. Neutral 2 px outline; the safe fallback for any look.

## Verdict

A home screen for people who want their own picture on the device, a garden, a pet, a painting, without losing a single piece of information. The rule is simple: text never touches the wallpaper. Every row sits on an opaque plate, and the paper halo outside the ink keyline means the edge reads even against the busiest image, like these flowers. The wallpaper only shows in the margins and 14 px gutters, so it frames the information rather than competing with it. The look is fixed; only the image changes. You'd pick it over Diner to make the device feel like yours. The e-ink risk is the wallpaper itself: a full-screen photo is the heaviest possible redraw and ghosts on partial refresh. Under KOReader night mode the image is inverted unless image inversion is turned off, which turns flowers into a negative, so the night board assumes images aren't inverted. On the Paperwhite the photo dithers to 16 greys and a busy one turns to noise, which is exactly why the plates are opaque.

## Lua export (the design's own, not the plugin's token paths)

```lua
-- looks/plates.lua
return {
  name = "plates",
  faces = {
    display = {
      family = "Atkinson Hyperlegible",
      weight = 700,
      repo = "googlefonts/atkinson-hyperlegible",
      file = "AtkinsonHyperlegible-Bold.ttf"
    },
    text = {
      family = "Atkinson Hyperlegible",
      weight = 400,
      bold = 700,
      repo = "googlefonts/atkinson-hyperlegible",
      file = "AtkinsonHyperlegible-Regular.ttf, AtkinsonHyperlegible-Italic.ttf"
    },
    accent = "none"
  },
  palette = {
    day = {
      paper = "#fbfaf6",
      ink = "#1b1a1f",
      text = "#1b1a1f",
      muted = "#4d4b55",
      hairLight = "#d9d6df",
      a1 = "#6b55c8",
      a2 = "#f2c230",
      die = "#fbfaf6",
      card = "#fbfaf6"
    },
    night = {
      paper = "#1d1c22",
      ink = "#f3f1ec",
      text = "#f3f1ec",
      muted = "#b5b2bd",
      hairLight = "#3a3842",
      a1 = "#a593f2",
      a2 = "#8a6d10",
      die = "#1d1c22",
      card = "#1d1c22"
    },
    grey = {
      paper = "#ffffff",
      ink = "#000000",
      text = "#000000",
      muted = "#333333",
      hairLight = "#bbbbbb",
      a1 = "#000000",
      a1Fill = {
        angle = 135,
        pitch = 6,
        line = 2,
        color = "ink"
      },
      a2 = "#cccccc",
      die = "#ffffff",
      card = "#ffffff"
    }
  },
  stroke = {
    hair = 1,
    rule = 2,
    greyHair = 2
  },
  header = {
    layout = "clockRight",
    rule = 0,
    ruleColor = "none",
    tracking = -0.03,
    dateFace = "text",
    dateWeight = 700
  },
  cover = {
    w = 122,
    h = 183,
    outline = 2,
    outlineColor = "ink",
    shadow = "none",
    under = "none",
    frame = 0,
    radius = 0,
    ring = {
      w = 3,
      color = "paper"
    }
  },
  chip = {
    fill = "a2",
    color = "ink",
    border = 2,
    borderColor = "ink",
    radius = 999
  },
  title = {
    tracking = -0.015,
    mark = "none"
  },
  progress = {
    h = 12,
    outline = 2,
    outlineColor = "ink",
    fill = "a1",
    track = "paper",
    radius = 999
  },
  quote = {
    style = "plain",
    rule = 0,
    ruleColor = "none",
    face = "text",
    weight = 400,
    slant = "italic"
  },
  tile = {
    style = "plate",
    cols = 3,
    h = 74,
    border = 2,
    borderColor = "ink",
    fill = "paper",
    under = "none",
    radius = 12,
    gap = 14
  },
  nav = {
    edge = 3,
    edgeStyle = "solid",
    lit = "fill",
    litColor = "a2",
    bar = 0
  },
  sheet = {
    style = "inset",
    edge = 2,
    edgeStyle = "solid",
    inset = 16,
    border = 2,
    under = "none",
    band = "none",
    rowRule = "hairLight",
    radius = 16,
    ring = 4
  },
  picker = {
    border = 2,
    borderColor = "ink",
    fill = "paper",
    radius = 999
  },
  label = {
    size = 11,
    weight = 700,
    tracking = 0.08,
    case = "upper",
    color = "muted"
  },
  size = {
    date = 18,
    clock = 84,
    title = 32,
    author = 16,
    quote = 18,
    launcher = 19,
    label = 11,
    sheetRow = 18,
    nav = 11
  },
  misregister = "none",
  ruled = "none",
  frame = "none",
  align = "left",
  texture = "none",
  dots = "none",
  wallpaper = {
    file = "wallpaper.png",
    fit = "cover",
    position = "center",
    under_text = "never"
  },
  plate = {
    fill = "paper",
    border = 2,
    borderColor = "ink",
    ring = 4,
    ringColor = "paper",
    radius = 12
  },
  icons = {
    set = "Phosphor Bold",
    repo = "phosphor-icons/core",
    licence = "MIT",
    pkg = "@phosphor-icons/core",
    url_example = "https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/bold/NAME-bold.svg",
    size = 24,
    nav_size = 24,
    color = "ink",
    nav_unlit = "muted",
    files = {
      home = "house.svg",
      library = "books.svg",
      series = "stack.svg",
      authors = "user.svg",
      history = "clock-counter-clockwise.svg",
      wifi = "wifi-slash.svg",
      settings = "gear-six.svg",
      folder = "folder.svg"
    }
  }
}
```
