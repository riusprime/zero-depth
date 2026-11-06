# v0.9.5 Step BH3 evidence

One hard spell each for the Foundry, the Twin Wardens, the Clockwork Judge and the Lantern Shade (BOSSES_HARD.md B6, B8,
B9, B10). Owner: "we have to modify 1 spell for each that will be hard to dodge, bosses should feel like a challeng not
just a step you go through to get to the next floor".

- Machine: the owner's PC (Windows 11, Godot 4.7.2 console build, headless, `--fixed-fps 60 --language en`), runs in
  parallel, each with its own `APPDATA`.
- Build: base `8513b32d35e80e14bb3703a36bec51fedb79699a` (branch `v095-bh3`, cut from the worktree HEAD, then merged
  `claude/v095-feedback`) plus this step's working tree. The step's own commit is the branch head.
- Import: `godot --headless --path . --editor --import --quit` ran before and after the work (disk had 94 GB free). The first
  run printed 3 ERROR lines about `editor_settings-4.7.tres` (the file the BH2 disk-full left half written, outside the
  project); the last run printed 0.
- Lint: `gdformat` then `gdlint` over every touched `.gd` (19 files): `Success: no problems found`.

## What changed, per boss (every number is data, validated by `HardRules` / `BulletPatternDefinition`; damage unchanged)

- **B6 Foundry, Furnace Waves** (`foundry_furnace_waves`). The ring (20 shots, 2 gaps, 27 degree turn) is now a WALL pattern
  with `crossing` and the new `cross_delay_seconds` 0.3: wall A marches along the aim, wall B at a right angle to it
  leaves 18 ticks after A, each wave (4 of them, 0.7 s apart, was the same). Each wall is 16 m long, shots 0.55 m apart,
  with a 2.4 m gap that shifts 3 m a wave (the Warlord's shield-wall rules). Telegraph stays 0.8 s (rule >= 0.55 s via the
  attack's new `"hard": 1` param). `BulletPatterns.wave_shots` takes a `part` (0 = wall A, 1 = wall B, -1 = both, which is
  what the Warlord's wall still gets), `cross_wave_at` gives the delayed wall's wave, `BossDodge.resolve_pattern` fires
  both. **Uncrossed quadrant:** wall A only holds x >= the body's far edge and marches +x, wall B only y >= it and marches
  +y (aim = +x), so the quadrant behind the body (x and y under 1.9 m) is never struck. Honest limit: the walls leave the
  boss, not the room's walls (the sim has no room geometry in a lab, and the aim is locked on the hero), and since the aim
  follows the hero until the lock, the quiet quadrant is behind the boss from the hero's side. The gaps are the ordinary
  answer; the quadrant is the guaranteed one.
- **B8 Twin Wardens, Crossfire** (`crossfire`, `crossfire_3`). New params `lines_follow_seconds` 1.2 and `lines_turn_dps` 60
  (compiled to `lines_ticks` 72, `lines_turn_milli` 11378). Both bodies aim at the hero when it starts; for the whole
  windup each line turns toward the hero by at most 60 degrees a second (fraction carried in the boss's points, no trig);
  the safe spot (where the gaps cross) is the crossing point of the two lines (`BossTwin.crossing_point`), after 1.2 s the
  lines hold and the fans fire along them. The lines and the spot were already drawn through the windup (`state()` "gap",
  "safe"); they now show the live line. `crossfire_3` telegraph 1.1 -> 1.2 s so the lines show the whole 1.2 s.
- **B9 Clockwork Judge, Gear Spiral** (`gear_spiral_2`, `gear_spiral_3`; phase 1 unchanged). New pattern fields
  `counter_arms` and `counter_spin_dps`: a second spiral of 2 arms turns the other way (-85 / +85 dps and +100 / -100 dps).
  Each wave fires 4 shots. Arm counts picked by measurement (below). Validation: a counter spiral must turn the opposite way,
  1..6 arms, 12 in all. Both attacks carry `"hard": 1` (telegraph 0.8 s >= 0.55).
- **B10 Lantern Shade, Lights Out** (`lights_out`, `lights_out_3`, `snuff`, `snuff_3`). `lamp_seconds` 6 -> 4 (240 ticks),
  `dark_lasts_seconds` 8 -> 9 (540 ticks, still under the 12 s cadence), `snuff` 1 -> 2: the value is now the number of lit
  lanterns each struck circle puts out (`snuff_count`; `BossShade.snuff` puts out the 2 nearest, fewer if fewer are lit).
  Note for the owner: in phase 3 the Snuff has 2 circles, so one Snuff can now put out all 4 lanterns; relighting by walking
  past a lantern is unchanged.

## Runs (raw totals)

| Batch | Tests | Result |
|---|---|---|
| New `tests/unit/sim/test_boss_hard_3.gd` (14 tests: walls and timing, the uncrossed quadrant live, lines following and locking, the hard run, spirals and their path, content rule, lantern timings, double snuff) | 14 | 14 pass, 545 asserts |
| `tests/unit/sim`: test_bosses, _2, test_boss_signatures, _signatures_2, test_readable_cause, test_boss_markers, _gates, _challenge | 124 | 124 pass, 56849 asserts |
| `tests/unit/sim`: test_boss_fights, _2, _3, test_boss_hard, _hard_2, _hard_3, test_bullet_patterns, test_final_boss, test_boss_pressure, test_twin_wardens, test_lantern_shade, test_clockwork_judge, test_boss_pace (first run) | 170 | 169 pass, 1 fail: the old Furnace ring pin in test_boss_fights_3 (updated, below) |
| After the test updates: test_boss_fights_3, test_boss_hard_3, test_twin_wardens, test_lantern_shade, presentation/test_lantern_shade_views | 66 | 66 pass, 1945 asserts |
| `tests/content` (folder; includes test_boss_pace's dodge lab) | 157 | 157 pass, 12681 asserts |
| `tests/golden` + `tests/arch` | 6 | 6 pass, 16832 asserts |
| `tests/unit/presentation`: bosses_2_views, boss_animations, boss_fight_views_3, boss_signature_views_2, boss_views, clockwork_judge_views, lantern_shade_views, twin_warden_views (first run) | 63 | 62 pass, 1 fail: test_lantern_shade_views' 8 s dark (updated, passes above) |
| `tests/e2e`: test_e2e_boss_dodge, _dodge_2, _dodge_3, test_e2e_boss_signatures_2, test_e2e_boss_strikes, test_e2e_bosses_2, test_e2e_clockwork_judge, test_e2e_lantern_shade, test_e2e_twin_wardens | 14 | 14 pass, 309 asserts |
| `test_five_floors`, `test_curse_room`, `test_modifier_smoke`, `test_event_rarity`, `scripts/ci/seams.sh`, the full suite | - | not run (the brief; GitHub runs the full suite) |

## Tests changed because a pinned number is the spell's old one (no bar lowered)

`test_lantern_shade.gd` (lantern burn 360 -> 240, dark 480 -> 540, snuff 2 invalid -> 3 invalid, the Snuff puts out the
two nearest: east and south), `test_lantern_shade_views.gd` (the dark lifts at 9 s, lanterns out at 4 s),
`test_twin_wardens.gd` (the Crossfire's spot starts on the hero, no longer 2 m off the chain; "standing on the spot" holds
the hero there until the last tick, then steps aside), `test_boss_fights_3.gd` (the Furnace ring test became a wall test).
The dodge labs (`test_boss_pace.gd`, `test_e2e_boss_dodge*.gd`, `test_e2e_lantern_shade.gd`) needed no change and passed.

## Dodge result per boss (unit labs in `test_boss_hard_3.gd`; the e2e dodge labs above pass unchanged)

- **Foundry:** the hero standing still at 6 m in front is hit within one attack (500 ticks); a hero who moves, after the
  aim locks, to the quadrant behind the body takes 0. Wall A's first wave leaves at the end of the windup (only wall A's
  shots exist then, all moving along the aim); wall B's appear 18 ticks later, at a right angle. The dash lab
  (`test_boss_pace.gd`, 6 tests, 653 asserts) still dashes `furnace_waves`.
- **Twin Wardens:** the crossing starts on the hero; a hero walking 2 m/s ends 0.6 m or less from the crossing at the lock; the
  line never turns more than 12 units (60 degrees) a tick; a hero running 9 m/s ends over 2 m from it and is hit; a hero
  at the crossing at the lock takes 0 for the whole fan; a hero at the crossing for 71 ticks then 2.2 m aside is hit.
- **Clockwork Judge:** the narrowest open arc between shot edges, measured on the ring 3/5/7/9/11 m out over every 4th tick of the
  pattern with a 0.8 m band either side: `gear_spiral_2` 2.71 / 4.78 / 6.86 / 8.93 / 11.01 m; `gear_spiral_3` 2.74 / 4.83 /
  6.92 / 9.02 / 11.11 m; every one at least 1.6 m (asserted). The 2 + 2 arms were enough, so no arm count was cut.
- **Lantern Shade:** lanterns burn out exactly 240 ticks after the dark falls; the dark lasts 540 ticks; a Snuff leaves exactly
  the two farthest lanterns burning; with fewer than two lit it puts out what is lit; walking within reach of a dead lantern
  relights it for 240 ticks.

## Not done / open

- The Foundry's walls start at the boss, not at the room's walls (see above); the owner may want a room-edge spawn.
- The Crossfire's lines follow the hero for the whole windup and lock only when the fans fire (the owner's numbers); there is
  no separate frozen moment, so the read is the line's turn rate, not a last-instant lock.
- Phase 3's Snuff (2 circles x 2 lanterns) can put out all four lanterns at once; not retuned.
- A visual pass on the two walls and the second spiral (`FireballViews` draws them as ordinary shots) was not done here.
- Full e2e, `seams.sh` and the full suite not run (the brief).
