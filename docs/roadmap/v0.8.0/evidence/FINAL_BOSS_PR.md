# FINAL_BOSS_PR: is the Prism's second phase fair (owner O84)?

- **Status:** RUN (sim, content, presentation, e2e checks and renders); whether it now feels fair, "not easy to dodge"
  and how long she takes in play: **OWNER ONLY**
- **Build:** step commit `db59d85` (`v0.8.0 Step PR`, branch `v080-pr` from `717ea47`); the runs marked "merged" on
  `1851e7c` (that commit merged with `origin/claude/lucid-fermat-9wv2tf` at `6f0de2c`, N19); the "before" pace on an
  export of `717ea47`. Godot `4.7.2.stable.official.ed1daf0bf`; a shared 4-CPU Linux cloud container (headless;
  renders on software Vulkan, llvmpipe, under xvfb), not the owner's hardware
- **Date:** 2026-10-18
- **Who ran it:** agent

Owner (PLAN O84, verbatim in [`../FINAL_BOSS.md`](../FINAL_BOSS.md) "PR"): the cross 15 % slower; the small balls in
a predictable pattern, 3 patterns, dodgeable but not easy; never all 3 spells at once, rotate; never small balls and
lasers at the same time.

## What "the 3 spells" are (read from the code before PR)
`src/sim/ai/boss_prism.gd` at `717ea47`: every Prism attack was a `cross` (`cross_ring`, `cross_spiral`,
`cross_flower`, `cross_weave`, a weighted random pick), and in one Cross `resolve` ran the beams (spin 5.0 s), `_orbs`
(a pattern from a shard every 1.6 s, aimed at the player) and `_bolts` (an aimed bolt every 1.1 s over spin **and**
window) on the same ticks. So the three spells are **the Cross (lasers)**, **the orbs** (`crown_orb`, 0.2 m, 2.6-3.0
m/s: the small balls) and **the fast bolts** (`crown_bolt`, a long spear, 22 m/s after a 0.4 s aim line: O17's "quick,
fast attacks"). The lead's reading: the bolts are not small balls, so they keep their aim line; they now fire only in
the window (owner's call: D60 (1)).

## One cycle now (from `test_her_spells_rotate_one_at_a_time_and_never_overlap`)
Spell starts, seconds into the phase: `cross_ring` 2.02, `crown_ring` 10.55, `cross_spiral` 18.62, `crown_spiral`
27.2, `cross_flower` 35.12, `crown_flower` 43.65, `cross_ring` 52.02 (a rotation: 50.0 s).
- **Cross** (8.5 s): 1.0 s aim lines → 5.0 s of four beams turning (a quarter in 2.824 s at full HP, 1.412 s at none,
  reversing after 3.529 s) → 2.5 s window, beams out, shield down: bolts aim 0.3 s and 1.4 s in (0.4 s lines).
- **Orb spell** (7.9-8.4 s): next only once her last bolt is gone; 0.8 s telegraph (shielded) → the waves from her
  centre at 0° plus the pattern's turn → shielded until the last orb's life ends (its waves + 4.33 s) → 0.5 s open.
- **Next Cross** only once no orb of hers is left.

## The gaps (hero 0.35 m radius, 0.7 m wide, runs 6 m/s; orbs 0.2 m; "corridor" = chord between neighbouring orbs
less an orb's width, at 4 m from her: `BulletPatternDefinition.GAP_CHECK_M`)
| Spell | Pattern | Gaps a wave | Corridor at 4 m | Hero widths | Between gaps | The dodge |
|---|---|---|---|---|---|---|
| `crown_ring` | RING, 32 less 4 gaps of 2, 4 waves 0.8 s apart, every other one +33.75° | 4 | 1.92 m | 2.75 | 11.25° apart: 0.38 m, no slipping through | step 1.10 m in 0.43 s: 2.55 m/s |
| `crown_spiral` | SPIRAL, 10 arms, 16 waves 0.15 s apart, 45°/s, reversing at 1.2 s | 10 | 2.07 m | 2.96 | along an arm 0.45 m centre to centre: solid | walk round with the arms: 3.14 m/s at 4 m |
| `crown_flower` | FLOWER, 4 petals of 64 cut under 500, 4 waves 0.9 s apart, each +33.75° | 4 | 1.92 m | 2.75 | 5.625° apart: solid | step 1.10 m in 0.41 s: 2.66 m/s |
"The step": the least turn from a clear spot of one wave to one of the next at 4 m, over the time between the
first wave's orbs leaving the hero's line and the next one's reaching it (wave gap less 2 × 0.55 m / the slowest orb).
Every next wave forces a step (none overlaps), each under half the run speed. A ball crosses the hero's line in
1.1 m / 3.0 m/s = 0.37 s (a flower's slowest, 2.27 m/s: 0.48 s).

## Commands and raw output
Sim, on `1851e7c` (merged):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/unit/sim/test_prism.gd,res://tests/unit/sim/test_final_pace.gd
    PR rotation: 2997 ticks (50.0 s), open 549 ticks (0.183; compiled 0.180)
    PR gaps crown_ring: 4 gaps, corridor 1.92 m at 4.0 m (2.75 hero widths), 24 orbs a wave
    PR step crown_ring: 1.10 m in 0.43 s between waves: 2.55 m/s (run 6.0 m/s)
    PR gaps crown_spiral: 10 gaps, corridor 2.07 m at 4.0 m (2.96 hero widths), 10 orbs a wave
    PR spiral: the arms sweep 3.14 m/s at 4.0 m (run 6.0)
    PR gaps crown_flower: 4 gaps, corridor 1.92 m at 4.0 m (2.75 hero widths), 44 orbs a wave
    PR step crown_flower: 1.10 m in 0.41 s between waves: 2.66 m/s (run 6.0 m/s)
    PR cross: 7.11 -> 6.05 units a tick at full HP (0.851)
    PR order: [&"cross_ring", &"crown_ring", &"cross_spiral", &"crown_spiral", &"cross_flower", &"crown_flower", &"cross_ring", &"crown_ring", &"cross_spiral", &"crown_spiral", &"cross_flower", &"crown_flower", &"cross_ring", &"crown_ring", &"cross_spiral", &"crown_spiral", &"cross_flower", &"crown_flower", &"cross_ring"]
    PR starts (s): [2.02, 10.55, 18.62, 27.2, 35.12, 43.65, 52.02, 60.55, 68.62, 77.15, 85.07, 93.6, 101.97, 110.5, 118.57, 127.1, 135.02, 143.62, 151.98]
    N2 pace base blade: won=true, bodies (s) [133.1, 98.5, 130.2], [max HP, measured dps] [[3573, 29], [630, 28], [3502, 28]], hits taken 103
    N2 pace strong blade: won=true, bodies (s) [87.5, 73.4, 123.7], [max HP, measured dps] [[15804, 263], [2021, 187], [11229, 187]], hits taken 40
    N2 pace absurd gun (Chain Blast + Split + Spread Lv 5, loop 3): won=true, bodies (s) [60.7, 71.1, 84.8], [max HP, measured dps] [[14484, 241], [2856, 264], [15867, 264]], hits taken 37
    N2 pace absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3): won=true, bodies (s) [63.5, 81.8, 102.9], [max HP, measured dps] [[15732, 262], [4739, 438], [26331, 438]], hits taken 41
    N2 shots crown_ring: at most 96 hostile shots alive, 0 cap events
    N2 shots crown_spiral: at most 158 hostile shots alive, 0 cap events
    N2 shots crown_flower: at most 176 hostile shots alive, 0 cap events
Tests                41
Passing Tests        41
Asserts           13820
Time              121.745s
```
Before PR (`test_final_pace.gd` on an export of `717ea47`, same command, that file only):
```
    N2 pace base blade: won=true, bodies (s) [133.1, 89.4, 132.1], [max HP, measured dps] [[3573, 29], [1029, 28], [3502, 28]], hits taken 131
    N2 pace strong blade: won=true, bodies (s) [87.5, 76.4, 108.5], [max HP, measured dps] [[15804, 263], [3301, 187], [11229, 187]], hits taken 71
    N2 pace absurd gun (Chain Blast + Split + Spread Lv 5, loop 3): won=true, bodies (s) [60.7, 73.0, 86.0], [max HP, measured dps] [[14484, 241], [4664, 264], [15867, 264]], hits taken 70
    N2 pace absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3): won=true, bodies (s) [63.5, 76.6, 92.6], [max HP, measured dps] [[15732, 262], [7741, 438], [26331, 438]], hits taken 64
Tests                14
Passing Tests        14
Time              84.957s
```
**Phase 2's length** (the middle number): base 89.4 → 98.5 s (+9.1 s, +10 %), strong 76.4 → 73.4, absurd gun 73.0 →
71.1, absurd blade 76.6 → 81.8. No target was changed (60 s floor, 185 s ceiling, as before). The base build's +10 %
is reported, not tuned away: her HP there is 630, near the 600 floor `dps_hp_min`. "Hits taken" is the scripted bot
over the whole fight (it is healed every tick; not a measure of the owner's play).

Content, arch, golden, debug on the step's tree before the merge (`db59d85`'s files):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/debug -ginclude_subdirs
Tests               156
Passing Tests       156
Time              40.887s
```
Presentation (`test_prism_views, test_final_boss_views, test_boss_fights_2_views, test_health_bars,
test_attack_visuals, test_boss_animations, test_fx_textures`), before the merge: `Tests 73, Passing Tests 73, Time
56.832s` (a first run failed 1: the new `pattern` clip's "spin" did not end at rest; fixed).
E2e (`test_e2e_prism, test_e2e_final_boss, test_e2e_nemesis, test_e2e_ascension`), before the merge: `Tests 7,
Passing Tests 7, Time 205.068s`. `test_e2e_prism` now also drives past the window: the orb spell's orbs fly with no
Cross, no beam and no aim line drawn.
`tests/unit/sim` folder, before the merge: the run was stopped by its 90 min background limit after 89 of 121 files,
no failure in them; the other 32 files (the stopped `test_readable_cause` among them), merged: **NOT YET FINISHED** at hand-back (13 files passed, no failure; the run was still in `test_starglow_patches.gd`). The 18 files after it are unrun here: GitHub runs them.
Lint: `gdformat --check src scripts tests` (1034 files unchanged), `gdlint src scripts tests` (no problems),
`bash scripts/ci/gut_shard.sh --check` (`gut_shard: ok (370 test files in 6 shards)`).

**Finished after hand-back (2026-10-18, same tree as `7e4479c`):** the 32 remaining `tests/unit/sim` files ran to the end: `Scripts 32`, `Tests 295`, `Passing Tests 295`, `Time 2443.494s`. With the first run's 89 files, all 121 files in the folder passed; nothing is left unrun.

## Shots (game camera, the real view)
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/prism_pr.gd -- <n>
prism_pr: res://build/shots/v0.8.0/pr/1_orb_ring_mid_flight.jpg (tick 298, active tick 130, orbs in the air 70, beams 0)
prism_pr: res://build/shots/v0.8.0/pr/2_orb_spiral_mid_flight.jpg (tick 288, active tick 120, orbs in the air 139, beams 0)
prism_pr: res://build/shots/v0.8.0/pr/3_orb_flower_mid_flight.jpg (tick 308, active tick 140, orbs in the air 131, beams 0)
prism_pr: res://build/shots/v0.8.0/pr/4_slower_cross_turning.jpg (tick 292, active tick 112, orbs in the air 0, beams 4)
```
Copied by hand to [`pr_shots/`](pr_shots/): [ring](pr_shots/1_orb_ring_mid_flight.jpg),
[spiral](pr_shots/2_orb_spiral_mid_flight.jpg), [flower](pr_shots/3_orb_flower_mid_flight.jpg),
[the slower Cross](pr_shots/4_slower_cross_turning.jpg). The hero is held still and invulnerable for the renders.

## Tests changed
- New in `tests/unit/sim/test_prism.gd`: `test_the_cross_turns_15_percent_slower`,
  `test_the_three_orb_patterns_are_dodgeable_but_not_easy`, `test_her_spells_rotate_one_at_a_time_and_never_overlap`
  (every tick of three rotations: no shot of hers while a beam is aimed or burns; orbs only in an orb spell, never with
  bolts; the fixed order), `test_the_bolts_fire_only_in_the_window`, `test_the_orbs_fly_from_her_centre_at_a_fixed_angle`.
- Rewritten for the old behaviour: `test_the_prism_is_a_skill_phase_in_data` (no `cross_weave`, the rotation),
  `test_a_whole_cycle_is_open_only_in_its_window` → `..._rotation_is_open_about_its_window_share` (0.294 → 0.180),
  `test_the_orbs_fly_from_her_orbiting_shards` and `test_every_orb_pattern_leaves_a_gap` (replaced), the window test's
  "the next Cross follows" (now the ring spell), the HP formula's 1929 → 1181 (× 0.180), the orbs' death line.
- `test_final_pace.gd`: `prism_bolt_fan` out of the N2 dodge list; the shot caps over the three orb spells.
- `test_boss_validation.gd`: + orbs on a Cross, `aim_degrees` range and owner, a rotation listing a spell twice.
- `test_bullet_pattern_validation.gd` (13 arms is out of range now, 1..12), `test_boss_pace.gd` (82 → 83 classed
  attacks), `test_dev_prism.gd` (the new F10 values), `test_prism_views.gd` (the bolt line and flare over the window),
  `test_e2e_prism.gd` (the orb spell after the window).
