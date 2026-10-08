# v0.5.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Owner decisions (2026-10-07)
- "skip the rule, keep going to v0.5.0" (ROADMAP §0.3 waived once).
- The 40–50 card pool moves here and is built now; counted **per build** (owner pick: "Per build").

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| CP | Five new stat cards that force choices (Glass Cannon, Onrush, Overkill, Hoarder, Fast Hands) and four ability mods (Cluster Payload, Overclocked Drone, Razor Orbit, Afterimage), offered only with their ability; pool per build Blade 50 / Gun 48 (58 in all); no dead cards over 300 seeds per build ([`evidence/CARD_POOL.md`](evidence/CARD_POOL.md)) | `2f7951f`, merge `1dbd7fb` |
| EV | 1–2 event rooms per floor (a lit pedestal, a panel of costed choices and "Leave it"; eight events), six curses (each +1 threat T) on 25 % of chest offers and on some event choices, a cleanse (the Cleansing Font, and a hook for shops), T on the HUD, in the pause menu and the recap ([`evidence/EVENTS.md`](evidence/EVENTS.md)) | `v0.5.0 Step EV` commit |

## Goldens changed on purpose
- none

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Card pool count: per build or whole game | 2026-10-07 | "Per build" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.
- EV (lead, for the owner): curses are fixed drawbacks, not CONTENT_SCHEMA §7's T-indexed `ThreatModifier` tables
  (still unbuilt); the elite rule (+100 % HP, a crown) is EV's own until SC sets a shared one; Echo Mirror repeats
  the stat raised most and Wandering Drone is a defence (PLAN, step EV). The three new streams are sub-streams
  (`map:event`, `loot:event`, `ai:elite`), like `ai:enemy`; EI-05's named list is unchanged: confirm or amend.

## Blockers
- none

## History
- 2026-10-08 — EV built on `ac62796` (events, curses, threat T); goldens unchanged; evidence in
  [`evidence/EVENTS.md`](evidence/EVENTS.md).
- 2026-10-07 — CP built (on v0.4.0 BS) and merged on top of v0.4.0 EN + BO: 864 tests pass; goldens unchanged. The
  brief's "≈8 stat cards + ≈6–8 mods" would have overshot 50 per build; CP added 5 + 4 to fit. Owner: count per
  build. PLAN written for the rest of v0.5.0.
