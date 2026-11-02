# O3_PRISM: the Prism's last phase (owner L6)

- **Status:** RUN (sim, content, presentation, golden, arch, e2e, pace probe, two shots). Whether it feels better ("cooler
  while he's down", not a "boring pattern"): **OWNER ONLY**
- **Build:** branch `v0105-o3` from `bdb2ec79`; the step commit's SHA is in PROGRESS (a commit cannot name itself).
  Godot `4.7.2.stable.official.ed1daf0bf`, the owner's PC (i7-10700K, RTX 3060, Windows 11; tests headless, shots on
  the GPU off screen)
- **Date:** 2026-11-02
- **Who ran it:** agent

Design note and picks: [`../O3_PRISM.md`](../O3_PRISM.md). Owner (2026-11-01): "The prism feels better, we still have
to work on the last phase"; "Needs something cooler while he's down and not on the dodging pattern"; "Boring
pattern"; overnight: "Pick and build".

## What was built
- **Her last phase** (`data/final_boss/prism.tres` `P_1`, threshold 500): from 50 % HP her rotation is `cross_ring`,
  `crown_spiral`, `facet_lances`, `prism_kneel`, `cross_flower`, `crown_flower`. A rotation body opens no phase gate
  (`BossGates.begin`): no pause, no adds; the HP floor at 50 % lifts the next tick.
- **Facet Lances** (`BossPrismLast`, move `lances`): 0.8 s gather (shielded); 6 lances 0.35 s apart, each from a rim
  spot 9 m out (135° apart, the first on your side) through you: tracks 0.45 s, holds locked 0.45 s (27 ticks, the
  minimum is 24), strikes 0.15 s as a 0.9 m lane to the wall, 26 damage (medium: 4 hits), once per lance; shielded
  throughout; death line `CAUSE_PRISM_LANCE` (en, es).
- **The Shattered Kneel** (move `kneel`): 0.6 s fall, 3.0 s down (open, nothing fired), 0.6 s rise. Hits from within
  the weak point's 2.5 m of her edge deal ×1.5 (`TAG_EXPOSED`); the crack fills at 8 % of her max HP lost; then her
  core bursts for 5 % of her max HP (the world's own hit, so the pace bucket does not eat it) and she rises at once.
- **The view** (`PrismLastViews`, inside `PrismViews`): violet facets at the rim; tracking lines (chevrons), locked
  laser lines with the lane burning faintly on the floor, the striking beam (the pack's beam) and an impact (the
  pack's); the kneel's white-gold core swelling with the crack, a ring of 16 crack shards lighting one by one, a gold
  ring at the core's reach, the pack's light pillar while she is down, and on the burst the pack's shatter and shock
  pulse plus a fading flash. Her clips `lances` and `kneel` (PrismClips); audio cues (laser, slam).
- **Reachable:** the Playground's Spawn tab "The Prism's last phase" (`FinalPrismLast`; `UI_PG_FINAL_PRISM_LAST` en,
  es) jumps the fight to the Prism just under 50 % HP; in a run she gets there by being hit.
- Every number is a **starting value (owner, 2026-11-01)**.

## The phase's length (the pace probe, before and after)
`tests/unit/sim/test_final_pace.gd` (N2's scripted BladeRun fights; the hero is healed every tick). The Prism is the
middle body. Before = `bdb2ec79`, after = this step's tree, same machine, same command:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/unit/sim/test_final_pace.gd
```
Before:
```
    N2 pace base blade: won=true, bodies (s, the Fallen's less its interphases) [99.5, 112.4, 142.4], [max HP, measured dps] [[2849, 18], [1121, 35], [3908, 35]], hits taken 108; the Fallen's raw time and interphase time (s) [174.4, 32.0]
    N2 pace strong blade: won=true, bodies (s, the Fallen's less its interphases) [69.8, 72.2, 125.4], [max HP, measured dps] [[6088, 86], [2310, 134], [8049, 134]], hits taken 85; the Fallen's raw time and interphase time (s) [157.4, 32.0]
    N2 pace absurd gun (Chain Blast + Split + Spread Lv 5, loop 3): won=true, bodies (s, the Fallen's less its interphases) [84.4, 70.5, 83.7], [max HP, measured dps] [[3172, 40], [1019, 50], [3551, 50]], hits taken 95; the Fallen's raw time and interphase time (s) [115.7, 32.0]
    N2 pace absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3): won=true, bodies (s, the Fallen's less its interphases) [47.5, 62.3, 99.1], [max HP, measured dps] [[5081, 103], [2539, 194], [8848, 194]], hits taken 58; the Fallen's raw time and interphase time (s) [131.1, 32.0]
Tests                16
Passing Tests        16
Time              153.869s
```
After:
```
    N2 pace base blade: won=true, bodies (s, the Fallen's less its interphases) [99.5, 111.9, 143.9], [max HP, measured dps] [[2849, 18], [1121, 35], [3908, 35]], hits taken 106; the Fallen's raw time and interphase time (s) [175.9, 32.0]
    N2 pace strong blade: won=true, bodies (s, the Fallen's less its interphases) [69.8, 78.1, 118.9], [max HP, measured dps] [[6088, 86], [2310, 134], [8049, 134]], hits taken 90; the Fallen's raw time and interphase time (s) [150.9, 32.0]
    N2 pace absurd gun (Chain Blast + Split + Spread Lv 5, loop 3): won=true, bodies (s, the Fallen's less its interphases) [84.4, 66.5, 84.3], [max HP, measured dps] [[3172, 40], [1019, 50], [3551, 50]], hits taken 93; the Fallen's raw time and interphase time (s) [116.3, 32.0]
    N2 pace absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3): won=true, bodies (s, the Fallen's less its interphases) [47.5, 59.7, 84.6], [max HP, measured dps] [[5081, 103], [2539, 194], [8848, 194]], hits taken 63; the Fallen's raw time and interphase time (s) [116.6, 32.0]
Tests                16
Passing Tests        16
Time              159.362s
```
| Build | The Prism before (s) | After (s) | Change |
|---|---|---|---|
| base blade | 112.4 | 111.9 | -0.5 |
| strong blade | 72.2 | 78.1 | +5.9 |
| absurd gun | 70.5 | 66.5 | -4.0 |
| absurd blade | 62.3 | 59.7 | -2.6 |

All inside the pace rule's band: 60 .. 180 s a body at loop 1 (base, strong); the absurd builds fight at loop 3, where
the floor is eased by `FinalPace.ease_permille` (1000 - 120 × 2 loops = 760: 45.6 s), so 59.7 s is in band. The rate
cap counts only the player's hits; the core's burst is the world's own (owner 0), so it is not capped (pick 6). The
Colossus's times are identical; the Fallen's move with the hero's state as it arrives.

## Tests
Her last phase, the views, the touched content and the e2e (after the fixes below):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/content/test_boss_pace.gd,res://tests/unit/presentation/test_boss_animations.gd,res://tests/unit/application/test_playground.gd,res://tests/unit/presentation/test_boss_challenge_parity.gd,res://tests/unit/presentation/test_vx5_bosses_views.gd,res://tests/unit/sim/test_boss_challenge.gd,res://tests/unit/sim/test_boss_gates.gd,res://tests/unit/sim/test_bosses.gd,res://tests/unit/sim/test_final_boss.gd,res://tests/unit/sim/test_prism.gd,res://tests/unit/sim/test_prism_last.gd,res://tests/unit/presentation/test_prism_views.gd,res://tests/unit/presentation/test_final_boss_views.gd,res://tests/unit/presentation/test_boss_challenge_views.gd,res://tests/unit/application/test_final_achievements.gd
Scripts              15
Tests               196
Passing Tests       196
Asserts           18651
Time              130.352s
```
After the arch fix below, `test_prism_views.gd` and `test_prism_last.gd` again: `Tests 20, Passing Tests 20`.
The last phase's order, printed by `test_the_last_phase_starts_at_half_hp_with_no_gate`:
```
    O3 last-phase order: [&"cross_ring", &"crown_spiral", &"facet_lances", &"prism_kneel", &"cross_flower", &"crown_flower", &"cross_ring"]
```
The first run of `-gdir=res://tests/content -ginclude_subdirs` with the boss files (37 scripts, 246 tests) had 2
failures, fixed and re-run above: `test_boss_pace` (the kneel never hits, so it joins the unclassed list; the classed
count 110 → 111 with `facet_lances`) and `test_boss_animations` (the kneel clip's `spin` ended at 0.25, now 0):
```
    [Failed]:  prism prism_kneel: classed
    [Failed]:  [112] expected to equal [110]:  every classed attack of the six bosses and the final boss's three bodies (...)
    [Failed]:  [0.25000000000000000000] expected to equal [0.0] +/- [0.001]:  prism kneel ends at rest
Tests               246
Passing Tests       244
Failing Tests         2
```
Goldens and the dev panel (`-gdir=res://tests/golden,res://tests/unit/debug -ginclude_subdirs`):
```
Scripts               6
Tests                18
Passing Tests        18
```
**Goldens moved: none.**

Arch (`-gdir=res://tests/arch -ginclude_subdirs`): the first run failed on the view naming `BossPrismLast`
(presentation may not name the sim); it now reads `WorldReader.LANCE_*`. Then:
```
Tests                 4
Passing Tests         4
```
E2e (`-gtest=res://tests/e2e/test_e2e_prism_last.gd,res://tests/e2e/test_e2e_prism.gd,res://tests/e2e/test_e2e_final_boss.gd`):
```
* test_the_prisms_last_phase_from_the_playground
    O3 e2e: frames 1545, lost in the lances 0, in the kneel 182
* test_the_prism_from_the_playground_jump
* test_the_ascension_portal_walks_into_the_final_boss_and_beats_it
Tests                 3
Passing Tests         3
Time              114.746s
```
Lint: `gdformat --check src scripts tests` → `1527 files would be left unchanged`; `gdlint src scripts tests` →
`Success: no problems found`.

## Shots (`scripts/shots/prism_o3.gd`, the GPU, off screen)
```
godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000 -s scripts/shots/prism_o3.gd
prism_o3: res://build/shots/v0.10.5/o3/1_facet_lances_telegraph.jpg (tick 227, active tick 58, lances [[0, 2], [1, 1], [2, 0]], kneel {  }, drawn: lines 2 strikes 1 facets 5 core false crack lit 0)
prism_o3: res://build/shots/v0.10.5/o3/2_shattered_kneel_core_open.jpg (tick 227, active tick 70, lances [], kneel { "stage": 1, "progress": 388, "crack": 600, "burst_tick": -1, "range": 4.61999988555908 }, drawn: lines 0 strikes 0 facets 0 core true crack lit 9)
```
1. The lances: lance 0 striking (the tall beam through the hero toward her), lance 1 locked (bright line, its lane on
   the floor), lance 2 tracking (thin line); five violet facets waiting at the rim; the bar reads "Invulnerable".
2. The kneel: she is low, her core a gold flare in a light pillar, the gold reach ring round her, 9 of 16 crack shards
   lit (60 %), the hero inside the reach.

Not tracked (`build/`). How it looks and feels in motion: **OWNER ONLY**.

## Picks for the owner (keep or change)
1. **Pattern: Facet Lances** (over Scissor Beams and Refraction): six tracked-then-locked lanes from all round the room.
2. **Down-moment: the Shattered Kneel** (over a counter-hit and breakable facets): she falls, her core opens, the crack
   bursts for bonus damage and she rises.
3. **Her last phase starts at 50 % HP**, and the lances and the kneel replace `crown_ring` in it.
4. **No phase gate for her** (no 1 s pause, no adds) when the last phase starts.
5. **Numbers:** lances 6, 0.35 s apart, track 0.45 s, lock 0.45 s, strike 0.15 s, 0.9 m wide, rim 9 m, 135° apart, 26
   damage; kneel 0.6 s fall, 3.0 s down, 0.6 s rise, core ×1.5 within 2.5 m of her edge, crack at 8 % of her max HP,
   burst 5 %.
6. **The burst is the world's own damage** (the pace bucket does not cap it: at most 5 % of her HP a kneel, once a
   rotation). Alternative: count it as the player's hit (capped).
7. A Playground button, "The Prism's last phase" (Spawn tab), for testing.
