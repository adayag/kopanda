# Home golden tolerance lets a wrong caption pass on the Editorial goldens

## What

`spec/emulator/compare.lua:9` sets `M.defaults = { tolerance = 16, max_fraction = 0.0005 }`: up to
0.05 % of pixels may differ, about 1,060 px at 1264×1680. The review of home/featured-book/goldens
(T-2axtyg, 2026-10-15) mutated the home fixture on the `tiller/home/featured-book/goldens` branch:

- a 60 s page duration (caption "1 h 24 min left" instead of "2 h 6 min left") failed the three Diner
  goldens and passed all four Editorial ones;
- `percent_finished` 0.63 instead of 0.62 failed only `home-diner-paperwhite` (0.07 %).

So the featured caption's values are pinned in the goldens only by the Diner captures. The unit specs
(`featured_widget_spec.lua`, `featured_book_spec.lua`) pin the arithmetic and wording.

Give the home goldens a `max_fraction` (per spec, through `home_golden_spec.lua`'s compare call) tight
enough that both mutations fail on every populated home golden, and show it does not flake.

## Why

C8 of home/featured-book says the populated goldens show 62 % and a known time left. A golden that
accepts a different caption only looks like it checks that.

## Done when

With the new bound, both mutations above fail on all four populated home goldens; `home_golden_spec.lua`
passes 10 consecutive plain runs; no golden is regenerated to get there.
