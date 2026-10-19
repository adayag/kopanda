# 1b Riso · Two-drum Risograph

Blue and fluoro pink, no black anywhere. The pink is always a few pixels out of register.

## Token table (board px)

| Token | Value |
|---|---|
| Display face | Big Shoulders Display 900 |
| Text face | Work Sans 500–700 |
| Accent face | none |
| Paper / Ink | #f3eee2 / #22509f (blue drum, never black) |
| Muted / Text | #3d5b9a / ink |
| Hairline | pink #f2a9c4 for secondary rules; structure is ink |
| Accents | fluoro pink #e9508a, pink tint #f6c6d8 |
| Band | tint band at the top of the sheet only |
| Stroke | 3 px ink nav edge and sheet, 2 px ink tile outlines, 2 px pink rules |
| Shadow | misregistration, not shadow: pink 3 right 2 down under display type; tint 5/4 under tiles; pink 8/8 under the sheet; 2 px ink outline 6/6 behind the cover |
| Radius | 0 |
| Tile | 2 px ink outline, tint fill knocked 5/4 out of register |
| Progress | 14 px, 2 px ink outline, pink on paper |
| Sheet | inset 20, 3 px ink outline, pink 8/8 offset, tint header band |
| Chip | tint fill, ink uppercase 700 |
| Labels | 11 px uppercase 700, 0.12 em |
| Date/clock | 15 px 700 / 124 px 900, clock right |

## Icon sets (chosen first)

- Phosphor Fill: MIT, github.com/phosphor-icons/core, npm @phosphor-icons/core, e.g. https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/fill/NAME-fill.svg. Solid shapes print like a single riso pass, with no thin strokes for the 150 ppi colour layer to blur.
- Material Symbols Rounded, filled 500: Apache-2.0, github.com/google/material-design-icons, npm @material-symbols/svg-500, e.g. https://cdn.jsdelivr.net/npm/@material-symbols/svg-500@0.27.0/rounded/NAME-fill.svg. Soft solid blobs; less character than Phosphor.
- Phosphor Bold: MIT, github.com/phosphor-icons/core, npm @phosphor-icons/core, e.g. https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/bold/NAME-bold.svg. Heavy round strokes; friendlier than the grid wants.

## Verdict

A zine on the nightstand: two inks, no black, and the pink is printed a few pixels off on purpose. It's for people who picked Diner for the colour but want it to feel handmade, not like signage. Without colour the motif still works, because the offset layer becomes a light grey ghost behind black, but it loses half its point, so it's the weakest of the four on the Paperwhite. The e-ink risk: the Colorsoft's colour layer is 150 ppi against 300 ppi for mono, so a 3 px misregistration can read as blur rather than intent. Keep the offsets at 3 board px or more, and check that the blue text holds up in direct sun, since it has less contrast than ink black.

## Lua export (the design's own, not the plugin's token paths)

```lua
-- looks/riso.lua
return {
  name = "riso",
  faces = {
    display = {
      family = "Big Shoulders Display",
      weight = 900,
      repo = "xotypeco/big_shoulders",
      file = "BigShouldersDisplay-Black.ttf"
    },
    text = {
      family = "Work Sans",
      weight = 500,
      bold = 700,
      repo = "weiweihuanghuang/Work-Sans",
      file = "WorkSans-Medium.ttf, WorkSans-Bold.ttf"
    },
    accent = "none"
  },
  palette = {
    day = {
      paper = "#f3eee2",
      ink = "#22509f",
      text = "#22509f",
      muted = "#3d5b9a",
      hairLight = "#f2a9c4",
      a1 = "#e9508a",
      tint = "#f6c6d8"
    },
    night = {
      paper = "#141a2e",
      ink = "#f1ece0",
      text = "#f1ece0",
      muted = "#b8bfd8",
      hairLight = "#6e3557",
      a1 = "#f0729f",
      tint = "#4a2643"
    },
    grey = {
      paper = "#ffffff",
      ink = "#000000",
      text = "#000000",
      muted = "#333333",
      hairLight = "#bbbbbb",
      a1 = "#999999",
      a1Fill = {
        angle = 135,
        pitch = 6,
        line = 2,
        color = "ink"
      },
      tint = "#dddddd"
    }
  },
  stroke = {
    hair = 2,
    rule = 3,
    greyHair = 2
  },
  header = {
    layout = "clockRight",
    rule = 0,
    ruleColor = "none",
    tracking = -0.01,
    dateFace = "text",
    dateWeight = 700
  },
  cover = {
    w = 150,
    h = 225,
    outline = 0,
    outlineColor = "none",
    shadow = "none",
    under = {
      x = 6,
      y = 6,
      border = 2,
      color = "ink"
    },
    frame = 0,
    radius = 0
  },
  chip = {
    fill = "tint",
    color = "ink",
    border = 0,
    borderColor = "none"
  },
  title = {
    tracking = 0,
    mark = "none"
  },
  progress = {
    h = 14,
    outline = 2,
    outlineColor = "ink",
    fill = "a1",
    track = "paper"
  },
  quote = {
    style = "ruleBoth",
    rule = 2,
    ruleColor = "hairLight",
    face = "text",
    weight = 500,
    slant = "italic"
  },
  tile = {
    style = "box",
    cols = 3,
    h = 84,
    border = 2,
    borderColor = "ink",
    fill = "none",
    under = {
      x = 5,
      y = 4,
      fill = "tint"
    }
  },
  nav = {
    edge = 3,
    edgeStyle = "solid",
    lit = "fill",
    litColor = "tint",
    bar = 0
  },
  sheet = {
    style = "inset",
    edge = 3,
    edgeStyle = "solid",
    inset = 20,
    border = 3,
    under = {
      x = 8,
      y = 8,
      fill = "a1"
    },
    band = "tint",
    rowRule = "hairLight"
  },
  picker = {
    border = 2,
    borderColor = "ink",
    fill = "tint"
  },
  label = {
    size = 11,
    weight = 700,
    tracking = 0.12,
    case = "upper",
    color = "muted"
  },
  size = {
    date = 15,
    clock = 124,
    title = 46,
    author = 16,
    quote = 18,
    launcher = 19,
    label = 11,
    sheetRow = 19,
    nav = 11
  },
  misregister = {
    x = 3,
    y = 2,
    color = "a1"
  },
  ruled = "none",
  frame = "none",
  align = "left",
  texture = "none",
  dots = "none",
  wallpaper = "none",
  plate = "none",
  icons = {
    set = "Phosphor Fill",
    repo = "phosphor-icons/core",
    licence = "MIT",
    pkg = "@phosphor-icons/core",
    url_example = "https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/fill/NAME-fill.svg",
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
