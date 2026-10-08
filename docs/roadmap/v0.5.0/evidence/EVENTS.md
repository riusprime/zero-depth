# EVENTS: does v0.5.0 Step EV (event rooms, curses, threat T) pass the suite and reach the real game?

- **Status:** RUN
- **Build:** the EV worktree branch cut from `claude/lucid-fermat-9wv2tf` at `ac62796`; the runs below are of the
  code committed as `v0.5.0 Step EV: events and cursed rewards` (run at its first version, `831ef91`; this evidence
  was then folded into that commit without code changes, so its own SHA is in the log); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux (cloud container),
  screenshots under Xvfb with Vulkan on llvmpipe
- **Date:** 2026-10-08
- **Who ran it:** agent
- **Scope:** PLAN v0.5.0 R3 ("events") and R4 ("cursed rewards"); the lead's EV decisions are in
  [`../PLAN.md`](../PLAN.md) (step EV).

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
python3 scripts/audio/generate_sfx.py --check
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan -s scripts/shots/events.gd
```

## Raw output
Import (`build/evidence_import.log`): exit 0, 0 lines starting `ERROR` or `SCRIPT ERROR`.

Lint:
```
444 files would be left unchanged
Success: no problems found
```

`bash scripts/verify.sh` (tail, `build/evidence_verify.log`):
```
Scripts             145
Tests               900
Passing Tests       900
Asserts           427654
Time              819.219s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (900 passing, minimum 900)
```

Lines the EV tests print in that run:
```
    event rooms per floor over 1000 seeds: { 1: 498, 2: 502 }
    cursed chest offers: 64 of 289
    hits taken in the ambush runs: 24
    a Warden walks 0.267 m in 10 ticks, 0.307 m cursed
    ambush_cache: Fight 3 elites here / A free chest once they fall
    blood_price: 12 % less max HP for the run / Your four-slash combo and Lunge Cleave. +12% damage per level; level 3 reaches 15% farther; level 5 finishers send a shockwave.
    cleansing_font: Pay 30 shards / Lift your latest curse: Withering
    echo_mirror: Nothing but the curse / +15% damage
    overclock_vent: Overheat now: a stall / +30 % Overclock damage this floor
    scrap_heap: Pay 35 shards / Overheating explodes instead of stalling you.
    unstable_core: Lose 25 % of your max HP now / A kill splashes 100% of its excess damage onto the nearest enemy
    wandering_drone: Stay by it for 20 s; enemies come faster / +45 shards
```

The e2e through `main.tscn` (input only; the dev panel's God and Curse next chest buttons clicked with the mouse):
```
res://tests/e2e/test_e2e_events.gd
* test_take_an_event_choice_and_a_cursed_chest_card
    event: blood_price
    cursed card: Leaky Core: Overclock heat fades 100 % faster
```

Sounds (four new cues: `event_open`, `curse_gain`, `ambush_start`, `event_done`; no existing file changed):
`python3 scripts/audio/generate_sfx.py --check` (tail):
```
  same  assets/audio/manifest.json
0 difference(s)
```

Screenshots (`build/evidence_shots.log`):
```
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
events: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
events: event 'blood_price', prompt '[E / X] Inspect: Blood Price'
events: res://build/shots/v0.5.0/events/pedestal.png (frame 193, tick 712)
events: panel open true, 2 cards
events: res://build/shots/v0.5.0/events/panel.png (frame 223, tick 832)
events: cursed card 'Leaky Core: Overclock heat fades 100 % faster'
events: res://build/shots/v0.5.0/events/cursed_card.png (frame 340, tick 1300)
events: threat 1, curses [0]
events: res://build/shots/v0.5.0/events/threat.png (frame 380, tick 1460)
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Suite | all pass, ≥ the committed minimum | CLAUDE.md "Testing before a push" |
| Event rooms | 1–2 per floor, side rooms only, 1,000 seeds | PLAN R3; step brief |
| Readable cause | 0 violations, bars unchanged | step brief; `tests/unit/sim/test_readable_cause.gd` |
| Cursed chests | ≈ 25 % of chest offers (starting value) | PLAN step EV |
| Goldens | unchanged | CLAUDE.md |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Suite | 900 / 900 (was 864) | yes |
| Event rooms | 1,000 / 1,000 floors valid; 498 with one room, 502 with two (`test_event_rooms.gd`) | yes |
| Readable cause | `test_readable_cause.gd` passes unchanged; the Ambush Cache runs (4 floors, with and without the elite and speed curses) took 24 hits, 0 violations (`test_curses.gd`) | yes |
| Cursed chests | 64 of 289 chest offers over 120 seeds (22 %); always one cursed epic stat card | yes |
| Curse effects | Swift Foes: a Warden's walk ×1.15 (0.267 → 0.307 m in 10 ticks); the other five each by its own test (`test_curses.gd`) | yes |
| Goldens | `tests/golden/test_replay_ground_plane.gd` passes; no golden regenerated | yes |

## Interpretation
Event rooms, curses and threat T are in the sim, reachable from the real game (the e2e takes an event choice by
keyboard and a cursed chest card by pad) and covered by tests: every event's outcomes, each curse's effect, T
accounting and its carry, cursed-offer composition, determinism and hash inclusion. Nothing here measures balance or
M-THREAT itself: T is recorded per floor (`RunState.threat_by_floor`) and its peak (`World.threat_peak`) for the
scorecard step (SCD). Whether the events, prices and curses feel right is the owner's call after playing
(OWNER ONLY: feel, fun, balance).

## Screenshots
Shot setup (not play): the player is kept invulnerable, the next chest is cursed through the dev route's flag and
500 shards are granted before the chest; the input path is the e2e above.
- [`events_pedestal.png`](events_pedestal.png): the Blood Price pedestal lit, its name floating, the prompt.
- [`events_panel.png`](events_panel.png): the panel: "Pay in blood" (cost 12 % max HP for the run, reward Combo
  Sword level 2) and "Leave it".
- [`events_cursed_card.png`](events_cursed_card.png): a cursed chest: card 1 an epic Haste marked with Leaky Core,
  cards 2 and 3 clean; the event room's hexagon on the minimap.
- [`events_threat.png`](events_threat.png): after taking it: "Threat 1", the curse note and the curse line, top left.

## After the merge with the lead branch (`d5450d9`: SC, AB, SV, SH)
Run on the merge in this worktree (merge commit `6f2c288` plus the fix commit after it; Godot 4.7.2, Linux). What
changed for EV: event rooms never take the Overrun or shop room; Swarm Call and Marked Hunt act on SC's pack
spawner (an elite doubles the tier-scaled HP); an Ambush pack takes the tier's HP and power; shop prices go through
`Curses.price` and the shop sells a cleanse (60 shards × floor); `EventState` is in `WorldSnapshot.STATE_CLASSES`
(its tables in `LOADOUT_CLASSES`) and `threat_by_floor` is in the save payload. A snapshot array of content tables
now keeps its tables on restore (`WorldSnapshot._decode`). SH's `test_sell_a_mod_for_forty_percent_and_lose_its_combos`
picked `combo_tables[0]`, which AB made an ability combo; it now picks the first item combo.

`bash scripts/verify.sh` (tail, `build/verify_merge2.log`):
```
Tests              1012
Passing Tests      1012
Asserts           466827
Time              1647.773s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (1012 passing, minimum 947)
```

`godot --headless --path . -s scripts/checks/readable_cause.gd` (run on `6f2c288`, before the fix commit, which
changed only the snapshot restore and tests; tail, `build/readable_cause_merge.log`):
```
	"deaths_checked": 24,
	"floor_ticks": 3600,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
```

`bash scripts/ci/export_smoke.sh` (tail, `build/export_smoke_merge.log`):
```
  ok    audio cues: 86
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```
The minimum test count is now 1012.
