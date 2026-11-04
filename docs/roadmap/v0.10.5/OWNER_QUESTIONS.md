# v0.10.5 — questions and picks for the owner (overnight, 2026-11-01 → 02)

The owner, going to sleep: "Keep going until you complete all of them, if you have any questions write them down and
we go over them at the end". Then, asked about the gates: **"Pick and build"** (the lead picks the recommended
option at each G1/G2 gate and builds it as starting values; every pick is listed here to keep or change) and
**"Don't push"** (everything stays local on `claude/v0100-cleanup`).

Each entry: the step, what the lead picked and why in one line, and the question to go over. Nothing here is final
until the owner says so.

## Good morning: what happened

- **Everything in the PLAN is built and merged** (details and evidence per step in [`PROGRESS.md`](PROGRESS.md)), except
  **O4b**, which missed its targets and waits on Q9. Nothing is pushed.
- **To see first** (shots in `build/shots/v0.10.5/`): the Prism's last phase (`prism_*.jpg`), the danger bar
  (`danger_bar_*_en.png`), the Training Room (`training_room*.png`), the wand forecast (`wand_forecast.png`), loops
  (`loop2_floor_card.png`, `hub_records.png`), shards on the floor (`shards_on_the_floor.jpg`), the cracked wall
  (`cracked_wall_s15c_*.png`), the curse altar (`curse_altar_s5b.png`), the calmer walls (`walls_*`).
- **To decide first:** **Q5 performance** (18 fps at 60 enemies; a clear first fix), Q9 (the director follow-up),
  Q6–Q8 (the economy: shards pile up; floor 5).
- **To play for feel:** O3 Prism, O11 (knockback, dash-cancel, quicker finisher), O2b boss pacing, O4 director,
  O5 loop rules, O9 rule cards, O10 weaknesses, O15 duos, S12 perfect-Vent dash refund.

## Answered 2026-11-02

- **Q5:** "yes fix it": being built (sync the views once a frame, a cheaper sync).
- **Q9:** "keep it out": O4b stays unmerged.
- **Q6–Q8:** "i'll test it myself": no change until the owner's playtest.

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
| 9 | O1 | The curse room's random curse price drew only the 5 cut (plain) curses; it now falls back to the 7 trade-off curses | OK, or a different price? |
| 10 | O3 | The Prism had one phase; a last phase from 50 % HP (no gate): **Facet Lances** (6 lances from the room's edge, aim 0.45 s, lock 0.45 s, 26 dmg) and the **Shattered Kneel** (down 3 s, ×1.5 damage near her, a crack ring that bursts her core for 5 % bonus); 7 picks in evidence/O3_PRISM.md (the core burst is world damage, outside the pace cap) | Play it: cooler? Shots: build/shots/v0.10.5/prism_*.jpg |
| 11 | O4 | Struggling = HP < 40 % or kills < 50 % of the expected rate (cap × 200 ‰ per 10 s); it gets a 600 peak (was 750), a faster peak clock, a ×1.5 quiet, packs one smaller; quiets end on their drawn time | Feel it on a weak build: still crowded? The next steps would be ramping the refill after a quiet and thinning leftovers (follow-up O4b, not built) |
| 12 | O15 | Six enemy duos (O15_PAIRINGS.md): Shield wall, Minefield herd, Pin and pick, Slam and shoot, Crowd the storm, Over the wall; 20–30 % of a lead kind's packs, from the floor both are unlocked. Note: a duo's "New:" announcement is remembered by the HUD, so it may repeat on a later floor | Keep, cut or retune any duo |
| 13 | O6 | Variant C (a 190 px HP-like bar in the plate, the ×N tier kept, the tag under the plate's right end), full at tier 10, a 0.7 Hz blink, wording "The depths answer ×1.41", no tag for bosses (their HP is paced since O2b). A and B are in build/shots/v0.10.5/danger_bar_a/b_en.png | Pick another variant or change the wording? |
| 14 | O5 | Loop-only robes Ouroboros (loop 3) and Abyssal (loop 5); records; achievements; fragments ×1.5 on loop 2, ×2 on loop 3…; 5 loop rules (Quickened, Lean Mending, Elite Hunt, Shielded, Point Blank), one added a loop; **the loop HP step ×6 → ×3.5** (loop 3: ×12.25 instead of ×36) because the rules carry part of the difficulty. Shots: build/shots/v0.10.5/loop2_floor_card.png, hub_records.png | Enough reason to go further? Any rule to cut? |
| 15 | O10 | The matrix (O10_STRESS_MATRIX.md): ×1.25 / ×0.75; 7 ids (Lance, Venom, Lightning, Glaive, Wave, Laser, Fire), each strong vs 2 kinds and weak vs 2; the Ring counts as Lightning; weak+resisted cancels; the Shield Bearer's shield still blocks the Laser from the front. **Venom Core is still the best single card on 9 of 14 kinds**: nerf Venom (balance), or leave it? | Venom: nerf or leave? |
| 16 | O9 | The 7 rule cards and the 8 retired flat cards (O9_RULE_CARDS.md); Heat Shield works while Hot (not only overheated); Reflex replaces Second Wind, Scavenger replaces Magnet; Hunter's Mark and Crowd Control deferred; the gamble shrine and the Codex still use / list the retired cards | Keep the 7? Should the shrine stop raising the retired stats? |
| 17 | O17 | Layout A of 3: a door at the bottom of the hub ring leads (behind the loading cover) to a separate smaller room; the door posts, terminal and exit pad are code stand-ins (no models yet); the room uses the Ruins floor and walls, not the hub's paving; 10 picks in evidence/O17_TRAINING_ROOM.md. Shots: build/shots/v0.10.5/training_room*.png | Models for the door/terminal/pad? Hub paving? |
| 18 | O12 | Effect caps by density and the 60 % dim in hordes; enemy statuses (burn flames) stay outside the budget | Keep? Put enemy statuses in too? |
| 19 | O11 | Feel (O11_FEEL.md, from the timings in evidence/O11A_FEEL_TODAY.md): F1 hits push normal enemies back a little (Blade 0.15 m, finisher 0.45 m, bolt 0.06 m); F2 a dash cancels a Blade swing's recovery; F3 the finisher's recovery 24 → 18 ticks | Play it: better? Too much knockback? |
| 20 | O13 | Variant A (a FORECAST block in ember under the wand); the noun "Bolt" (the slot pips say "Orbs"); damage per second leaves out crits, statuses, gamble and curses; Ember Core's "on a kill: Zone" repeats inside split shots. Shot: build/shots/v0.10.5/wand_forecast.png | Readable? Change the wording? |
| 21 | O7b | Shard drops: merge within 0.5 m, at most 24 a floor (oldest merges in), pickup radius 1.2 m × pickup range (heal orbs 0.9 m), shards left on the floor are collected when you take the portal (none lost). Small violet crystals, pulled in over 0.15 s. Shot: build/shots/v0.10.5/shards_on_the_floor.jpg | Bigger crystals? Lose uncollected shards at the portal instead? |
| 11 | O4 | Struggling = HP < 40 % or kills < 50 % of the expected rate (cap × 200 ‰ per 10 s); it gets a 600 peak (was 750), a faster peak clock, a ×1.5 quiet, packs one smaller; quiets end on their drawn time | Feel it on a weak build: still crowded? Next steps would be ramping the refill after a quiet and thinning leftovers (follow-up O4b, not built) |
| 12 | O15 | Six enemy duos (O15_PAIRINGS.md): Shield wall, Minefield herd, Pin and pick, Slam and shoot, Crowd the storm, Over the wall; 20–30 % of a lead kind's packs, from the floor both are unlocked. Note: a duo's "New:" announcement is remembered by the HUD, so it may repeat on a later floor | Keep, cut or retune any duo |
| 13 | O6 | Variant C (a 190 px HP-like bar in the plate, the ×N tier kept, the tag under the plate's right end), full at tier 10, a 0.7 Hz blink, wording "The depths answer ×1.41", no tag for bosses (their HP is paced since O2b). A and B are in build/shots/v0.10.5/danger_bar_a/b_en.png | Pick another variant or change the wording? |
| 14 | O5 | Loop-only robes Ouroboros (loop 3) and Abyssal (loop 5); records; achievements; fragments ×1.5 on loop 2, ×2 on loop 3…; 5 loop rules (Quickened, Lean Mending, Elite Hunt, Shielded, Point Blank), one added a loop; **the loop HP step ×6 → ×3.5** (loop 3: ×12.25 instead of ×36) because the rules carry part of the difficulty. Shots: build/shots/v0.10.5/loop2_floor_card.png, hub_records.png | Enough reason to go further? Any rule to cut? |
| 15 | O10 | The matrix (O10_STRESS_MATRIX.md): ×1.25 / ×0.75; 7 ids (Lance, Venom, Lightning, Glaive, Wave, Laser, Fire), each strong vs 2 kinds and weak vs 2; the Ring counts as Lightning; weak+resisted cancels; the Shield Bearer's shield still blocks the Laser from the front. **Venom Core is still the best single card on 9 of 14 kinds**: nerf Venom (balance), or leave it? | Venom: nerf or leave? |
| 16 | O9 | The 7 rule cards and the 8 retired flat cards (O9_RULE_CARDS.md); Heat Shield works while Hot (not only overheated); Reflex replaces Second Wind, Scavenger replaces Magnet; Hunter's Mark and Crowd Control deferred; the gamble shrine and the Codex still use / list the retired cards | Keep the 7? Should the shrine stop raising the retired stats? |
| 17 | O17 | Layout A of 3: a door at the bottom of the hub ring leads (behind the loading cover) to a separate smaller room; the door posts, terminal and exit pad are code stand-ins (no models yet); the room uses the Ruins floor and walls, not the hub's paving; 10 picks in evidence/O17_TRAINING_ROOM.md. Shots: build/shots/v0.10.5/training_room*.png | Models for the door/terminal/pad? Hub paving? |
| 18 | O12 | Effect caps by density and the 60 % dim in hordes; enemy statuses (burn flames) stay outside the budget | Keep? Put enemy statuses in too? |
| 19 | O11 | Feel (O11_FEEL.md, from the timings in evidence/O11A_FEEL_TODAY.md): F1 hits push normal enemies back a little (Blade 0.15 m, finisher 0.45 m, bolt 0.06 m); F2 a dash cancels a Blade swing's recovery; F3 the finisher's recovery 24 → 18 ticks | Play it: better? Too much knockback? |
| 20 | O13 | Variant A (a FORECAST block in ember under the wand); the noun "Bolt" (the slot pips say "Orbs"); damage per second leaves out crits, statuses, gamble and curses; Ember Core's "on a kill: Zone" repeats inside split shots. Shot: build/shots/v0.10.5/wand_forecast.png | Readable? Change the wording? |
| 21 | O7b | Shard drops: merge within 0.5 m, at most 24 a floor (oldest merges in), pickup radius 1.2 m × pickup range (heal orbs 0.9 m), shards left on the floor are collected when you take the portal (none lost). Small violet crystals, pulled in over 0.15 s. Shot: build/shots/v0.10.5/shards_on_the_floor.jpg | Bigger crystals? Lose uncollected shards at the portal instead? |

## Questions

| # | Step | Question |
| Q9 | O4b | The director follow-up missed its targets (table in evidence/O4_DIRECTOR.md "O4b"): the weak hero's room is less crowded (alive 16.2 → 11.5) but the strong hero lost 22.5 % of its kills, because the test bot counts as "struggling" a third of the time. Not merged; branch `v0105-o4b`. Options: merge with a 900 ‰ cap, cut the cap only on low HP (not kill rate), or drop it | Which? |
| Q6 | O16 | **Shards pile up**: the bot spends only 27 % of what it earns and still buys every chest; the bank reaches ~2088 by floor 5. More things to spend on (shop stock, rerolls), higher chest prices, or fewer shards? |
| Q7 | O16 | `data/scaling/catch_up.tres` has 3 floors of entries but the run is 5 floors: floors 4–5 reuse floor 3's expected power, so the catch-up (and boss pace) stretch there (m 1.06, 1.32). Add floors 4–5 entries? **Done (88026905):** floors 4–5 entries added; floor 4 bosses 69–97 s; floor 5 bosses ~58 s, just under the 60 s target. Raise floor 5's pace to ~9000 (≈90 s)? |
| Q8 | O16 | Floor 5 is a spike: challenge ÷ power 0.31 / 0.45 / 0.43 / 0.49 / **0.69**. Ease floor 5, or is it the intended climax? |
| Q5 | **perf** | **The O12 probe measured ~16–17 fps with 60 enemies and a heavy wand on your PC** (p50 54–63 ms; render only ~14 ms; the main thread — sim and views — is the cost). v0.10.0's target was 144 fps. The lead recommends a measure-only Opus step next (`--breakdown`: where the 40+ ms go) before any fix. **Measured (evidence/PERF_Q5.md):** 0 / 20 / 60 enemies = 210 / 79 / 18 fps. Root cause: the views sync on every sim tick, not once a frame (main.gd:479); at 60 enemies a frame runs 3.6 ticks × 9.3 ms. Ranked fixes: (1) sync views once a frame, −19 ms, a presentation-contract design step; (2) halve the view sync cost, −17 ms; (3) halve AI/move, −6 ms; (4) physics interpolation off, −9 ms (trade-off). Start with (1)+(2) as the next step? |
| Q1 | tests | Three sim tests fail on the branch before O2b too: `test_deep_bite` (gets the Spanish name on your PC's locale) and two `test_ascension` loop-scaling tests (expect floor-1 enemy HP from before v0.9.5 EP3's floor-1 ease). Update their expectations? **Done** (5acaebaf: locale set to en in the test; ascension expectations derived from the EP3 data; lance scatter counts the pack burst). No game bug. |
| Q2 | O1 | `test_e2e_wand_build`: the replay was not exact with dev-granted frost_core, blade_orbit, echo_slash, ember_core, so the fixture was switched to other cards. A possible determinism bug in those cards, maybe older than O1. **Answered (D1):** not a game bug: the test helper didn't set the element-pair table; fixed |
| Q3 | O1 | Left in the code: the Bomb and Scatter form code (no live card reaches it), 28 shot/probe scripts naming removed ids. Remove them too? |
| Q4 | O1 | Coverage lost: no live card exercises the v0.5 item engines, trigger cards in a wand, or blast merging. Also: two item-visual tests (bolts change with items; Ember Edge turns the Blade orange) were deleted because O1 removed their items. **Done (1b689626):** rewritten with live cards (gun_rapid_fire, gun_ricochet, ember_core), 3/3. |
|---|---|---|

## Wave 3 overnight (2026-11-04 → 05)

Owner, 2026-11-04 night: "take into the plan to remake every single UI element into this new style even the main menu,
all UI style components have to be remade, i'll go to sleep … keep working and if you have any questions write them
down … 6 agents, 3 sonnet 3 opus at the same time". Picks made while the owner sleeps, to keep or change:

| # | Step | The lead's pick | To go over |
|---|---|---|---|
| W1 | W3-P1b | The Blade's element stacking is fixed at its causes (measured), not by a blind retune; a target still missed by > 10 % stops and waits here | — |
| W2 | W3-S10 | Bolt push halved and elites plan every 4 ticks (your answers); merged only once the golden's gun drop (82 → 59 hits) is explained | — |
