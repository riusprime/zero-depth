# v0.10.5 — questions and picks for the owner (overnight, 2026-11-01 → 02)

The owner, going to sleep: "Keep going until you complete all of them, if you have any questions write them down and
we go over them at the end". Then, asked about the gates: **"Pick and build"** (the lead picks the recommended
option at each G1/G2 gate and builds it as starting values; every pick is listed here to keep or change) and
**"Don't push"** (everything stays local on `claude/v0100-cleanup`).

Each entry: the step, what the lead picked and why in one line, and the question to go over. Nothing here is final
until the owner says so.

## Picks made overnight

| # | Step | The lead's pick | To go over |
|---|---|---|---|
| 1 | O18 Lore | The 9 lines in O18_LORE.md, written by the lead; a Lore page in the Codex; 4 open from the start, 5 unlock when met | Keep, edit or cut any line (en and es) |
| 2 | O18 Lore | Runes' entry unlocks on the first boss kill or a solved rune puzzle (there is no rune-fragment event) | OK, or add a fragment event? |
| 3 | S15d | Cracked walls 1000 / 350 / 750 ‰ per floor → 11.5 / 28.5 / 31 % (floor 1 capped by free dead ends) | OK? |
| 4 | S7 | An extra altar can exceed the 2-altar cap (a floor can show 3 altars) | OK, or keep the cap at 2? |
| 5 | O7 split | Shards: O7a caps the per-kill shard tier at the floor's peak (Sonnet); O7b makes shards real pickups lying on the floor like heal orbs (Opus, later) | OK? |
| 6 | O7a | Kill shards hold after max(the floor's peak, 3 min): floors 2+ peak at 30 s, so a pure peak cap would have frozen them at once | OK, or another minimum? |
| 7 | O14 | Floor shapes: floor 2's first Lockdown is an Elite one near the main path's middle; floor 3's room before the boss door spawns nothing while you stand in it | OK? |
| 8 | O2b | Boss HP grows in line with your power (cap 3× expected), read at the boss door; floors 4–5 and loops reuse floor 3's pace (not measured); 11 picks in evidence/O2B_BOSS_PACE.md | OK? Especially pick 8: **threat T no longer raises boss HP**, only its damage cap |

## Questions

| # | Step | Question |
| Q1 | tests | Three sim tests fail on the branch before O2b too: `test_deep_bite` (gets the Spanish name on your PC's locale) and two `test_ascension` loop-scaling tests (expect floor-1 enemy HP from before v0.9.5 EP3's floor-1 ease). Update their expectations? (lead: yes, as direct fixes) |
|---|---|---|
