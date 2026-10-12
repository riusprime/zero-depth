# Dev panel (lighting and balance tuning in the running game)

Status: **built 2026-10-12** (Steps 1–7: `f26b541`, `713aaa3`, `00b3a04`, `daa7411`, `d10bb05`, Step 6 commit).

## Owner lines (2026-10-12)

| # | Line (verbatim) |
|---|---|
| D1 | "I'd like to know if there's actual way that I can see these changes without you needing to render … so I can go into the the app itself and change the lighting myself and see it like live render it and we don't need to wait for you to render the images and then push the PR and wait the full suite and the .exe generation" |
| D2 | "we need like a master dev panel, not only for lighting, but we are also going to be adding all the variables that affect the balancing of the game, the actual difficulty, so I can tweak from there and test myself, so we don't have to just wait for a full run and patch" |
| D3 | "we are going to be including the the health, the damage enemies do, how many they spawn, and everything you balance. Don't forget to add, even if I didn't mention it, add everything to that panel. We'll work balancing from there." |

## Owner decisions (2026-10-12, asked in chat)

| Question | Answer |
|---|---|
| When does a balance change take effect? | **Live**, plus a **Restart floor** button: values the sim reads every tick change at once; values fixed at spawn or floor start apply to the next spawns or on restart. |
| Which builds have it? | **All builds**, opened with a hidden key (**F10**). Removing or locking it before a public release goes on the release checklist. |
| How are tweaks kept? | **Saved on the owner's PC** (user folder, persists between launches, with **Reset all**) plus a **Copy changes** button; the lead writes copied changes into the content files. |
| Do tweaked runs count? | **No.** While any balance value differs from the shipped one, a **DEV** mark shows and the run saves no progress, unlocks or records. Lighting tweaks don't trigger this. |

## Rules it needs (LOCKED_DECISIONS change log, 2026-10-12)

- **EI-07 exception:** the dev panel is not presentation. It lives in its own app-layer folder and writes the World's
  tuning tables, between ticks only, through one tuning API. Presentation stays read-only.
- **Determinism:** a tweaked run is marked and never saved or replay-checked; with no tweaks the game hashes as
  before (the goldens don't change).
- **EI-10:** the panel's labels go through `tr()` like every visible string.

## What it covers ("add everything")

The knob inventory (2026-10-12) found these sources. Every one gets a page in the panel.

| Group | Sources | Applies |
|---|---|---|
| Lighting | the current biome's BiomeMood (all fields, the grade included) and the 3 biome moods | live |
| Player | player (hp, speed, crit, regen, iframes), dash, primary, the 4 combo swings, the 2 builds and their skills | live; max HP on Restart floor |
| Enemies | 14 enemies: hp, speed, radius, behaviour params, each attack (damage, telegraph, active, recovery, shape) | damage, speed, AI live; HP at next spawn |
| Bosses | 6 bosses with their attacks and phases; the 3 boss pools | live except HP (next spawn) |
| Spawning and difficulty | the spawn director (caps, intervals, per-tier HP/damage/interval, packs, mix), the 3 difficulty curves | live |
| Run scaling | per-floor enemy HP/damage, boss scaling, heal and shard carry, Deep scale and extras, boss ease | Restart floor |
| Hidden catch-up | expected power, caps, threat bonus, per-ability/item/combo weights | Restart floor |
| Arenas and Overrun | arena share, waves and sizes; Overrun multipliers, waves, shards | next arena / Overrun |
| Economy | rewards (chests, altars, prices, shards, heal orbs), shop, gamble shrine, legendary, events and event rules, curses | live (counts placed at floor start: Restart floor) |
| Build pieces | 63 items, 51 modifiers, 10 abilities (L1–L5), 16 combos, 18 stat cards, heat | live (owned pieces refresh) |
| Map generation | floor params (rooms, spawn rooms, links, spots) | Restart floor |
| Sim constants | the designer-relevant `const`s (telegraph minimum, spawn-in, boss intro and gates, fire cap, heal orb cap, slots, curse caps …) | Step 6: moved into a tuning resource first |
| Tools | the existing debug buttons (pause, step, spawn, god mode, kill boss, grant, go to arena/Overrun …) | — |

## Plan

Each step is one commit, with tests of the folders it touches; one full suite at the end (one run per wave).

1. **Tuning store.** `DevTuning`: overrides keyed by `<content path>:<property path>` (nested resources, arrays and
   dictionaries included); applied to the loaded definitions after `ContentRepository.load_all()` and before every
   compile (start, continue, every floor); saved to `user://dev_tuning.json`; Reset all; Copy changes (one line per
   change: file, field, shipped → new). Tests: an override reaches the compiled table; reset restores; save and load
   round-trip; no overrides, the content hash and the goldens don't change.
2. **The panel (F10).** A full-screen overlay in all builds: groups on the left (above), a search box, the selected
   source's fields built from its exported properties (numbers, arrays, dictionaries, nested resources), each with
   its shipped value and a reset. Buttons: Restart floor, Reset all, Copy changes. Pauses the game while open.
   The old debug buttons also appear on a Tools page; the backtick panel stays (debug builds, many e2e tests drive
   it). e2e: F10 opens it from `main.tscn`.
3. **Lighting live.** `StageView.apply_mood()` re-applies the environment, the grade, the fire and hero lights
   while playing; the lighting page edits the current biome's mood and saves per biome. Not a balance tweak (no DEV
   mark).
4. **Balance live.** At the tick boundary (SimDriver's pending commands), a changed source is recompiled and swapped
   into the running World (with the floor scaling re-applied), then the build refreshes (`refresh_build`, max HP,
   catch-up). Values fixed at spawn apply to the next spawns; the page says which. Restart floor rebuilds the floor
   from the tweaked content.
5. **DEV mark and no counting.** Any balance override: a DEV tag on screen, and the run has no save (Continue can't
   resume it). The game writes no unlocks or records yet (the profile's `unlocks` section is unused); when they come,
   they check `tuning.balance_tweaked()` the same way. e2e: a tweaked run's save is gone and DEV shows; lighting alone
   changes neither.
6. **Sim constants.** 24 designer-relevant `const`s (spawn-in, boss rise and stagger wait, phase gates and adds,
   enemy AI commit, strafe, flank, spread, Sniper relocation, Mender scan, heal-orb cap, pickup radius, fire cap,
   hit rate and trail spacing, field throw) now come from `data/tuning/sim.tres` through `World.tuning`; the old
   constants stay as the defaults and the shipped file equals them (`tests/content/test_sim_tuning.gd`), so the
   goldens don't change. Their page: "Timings, AI and caps". Not yet in: the map generation's `FloorParams` (rooms
   per floor, spawn rooms, links), engine limits (hitstop cap, input buffer, chain depth) and the few inline caps
   in curses and events.
7. **Release checklist line** (ROADMAP §0.4): added; remove or lock the panel before a public release.
