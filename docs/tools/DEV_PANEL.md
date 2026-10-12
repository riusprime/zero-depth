# Dev panel (lighting and balance tuning in the running game)

Status: **owner decisions recorded; PLAN below is a draft until the knob inventory is in.** Not built yet.

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

## Plan (draft)

Written after the knob inventory: every balance table and constant, where the sim reads it, and whether an edit
applies live or at spawn.
