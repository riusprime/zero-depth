# FC6: the Glaive accepts eleven more cards (v0.9.5 Step FC6, FORM_COMBOS.md G1-G11)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc6` (cut from `claude/v095-feedback` at bb2affb5, which
  holds FC4's 41bff38d); a file cannot name its own commit, the SHA is in the step report. Godot 4.7.2 stable;
  Windows 11 Pro, owner PC, several Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/glaive_mods.gd` (pure, one handler per card; `GlaiveMods.DEFAULTS` = the data row, 29 keys). A disc
  ignores the eleven cards' generic ops (`WandCompile.run` notes the id in `modifier_ids`), the handlers read them.
  Twin and Swirl are untouched.
  - Throw (`Attacks._bolts`, the player's own throw only): Halo four discs at 0/90/180/270 degrees from the aim, each
    50 % (all return, as any disc); Big Shot radius x1.5, speed x0.75, damage x1.6; Rapid Fire radius x0.7, speed x1.25,
    damage x0.7 and a 27-tick period (`ItemEffects.shot_period_ticks` -> `GlaiveMods.period`); both multiply. Backfire a
    disc straight behind at 100 % (skipped under Halo: it already has one at 180 degrees, as the Lance's). Ricochet
    throws with 2 wall bounces and drops them when the disc turns home (the walls on the way back end it, as today).
    Echo: each disc leaves a row; 18 ticks later a ghost disc flies the same line (the muzzle and angle of the throw,
    50 % of that disc's damage, same bounces), and starts no follow-ups (no small discs).
  - Flight (`ProjectileMoves.steer` -> `GlaiveMods.steer` before the return rule, `steer_after` after it): Orbit flies
    one 60-tick lap at 2.5 m round the hero, then out along the aim (its life holds the lap, the turn-home clock does
    not: the disc still turns 7 m out from the lap's end). Mine: at the far point (where the return rule would turn) the
    disc stops and spins in place 72 ticks (`World._projectile_hits` -> `GlaiveMods.hold` skips its sweep), hitting the
    enemies it touches each at most once per 30 ticks (`mine_gap_ticks`), then the return rule turns it home. Homing:
    on the way out it turns toward the nearest enemy within 6 m and within 90 degrees of its heading (max 90 degrees a
    second = 17 units a tick; an overlapped enemy is ignored; the lowest index on a tie); on the way back toward the
    nearest such enemy that is not the one it chased out, else straight home.
  - Hits (`World._projectile_hits` -> `GlaiveMods.on_hit`): Split, on the disc's first hit, makes two small discs just
    past the body at +-30 degrees (30 % of the disc's damage, radius x0.7 of the disc, no return rule, pierce through,
    4 m of flight, then they end; no cards of their own), once per disc. Ring (`GlaiveMods.advance`): every enemy
    within 1 m of a live disc takes 40 % of the disc's damage, each at most once per 30 ticks per disc.
  - Bound: at most `live_max` = 8 live discs per hero (`GlaiveMods.cull` after `World._apply_spawns` and in `advance`;
    the oldest end first), rows capped at 64 (`ROWS_MAX`; a row that does not fit is not added). The shot caps
    (12 an attack, 40 a second) apply to the throw as before; Echo's ghosts and Split's small discs are bounded by the
    8-disc cap, not the shot cap (as the Lance's ghosts).
  - Rows in `ModifierState.gm_*` (a live disc, a disc to open, Ring's and Mine's per-enemy gaps), hashed only while set,
    listed in `WorldSnapshot.ADDED_SINCE_V05` (an older save loads with none); `WorldReader.glaive_rings()`.
- Data: `data/wand/attack_slots.tres` glaive row `allowed` += `halo_shot`, `gun_ring`, `gun_backfire`, `gun_ricochet`,
  `gun_homing`, `gun_echo`, `gun_big_shot`, `gun_rapid_fire`, `split_shot`, `gun_mine`, `orbit_rounds`; a `params`
  dictionary (29 keys); `AttackFormRow.GLAIVE_KEYS`; the validator checks the Glaive's keys. Pierce, Spiral and
  Threadline stay off.
- View `glaive_view.gd`: Ring's lightning ring round each disc that has one (the Bomb's ring look, as the Lance's and
  the Void's); every other card reuses the disc look. No new art.
- `scripts/balance/forms_dps.gd`: the Glaive's twelve combinations (plain + the eleven). New
  `scripts/balance/glaive_dps_scenes.gd`: the cards whose gain needs enemies in the right place, measured with the
  same harness against the plain Glaive in the same scene.
- Wand categories (not changed): Halo, Ring, Backfire (and Twin) are Pattern cards, limit 1; the other eight are
  Secondary, limit 2. So a real wand holds one of the first group and two of the second; the unit tests and the DPS
  sheet put cards in directly (`add_item` never caps).

## Deviations to flag (numbers or readings the spec left open)

- Homing: the 90-degree cone and the "overlapped enemy ignored" rule are mine (without them a disc that has just
  pierced an enemy turns back to loop round it); the way-back homing lasts at most `home_back_ms` = 1000 ms (a disc on
  the way home has no life limit, so a pursuit that cannot catch its target could circle for ever). All three are
  data (`home_cone_deg`, `home_back_ms`). At 90 degrees a second the turn radius is about 8.9 m: the unit test's enemy
  1.5 m off the line at 5.5 m is hit; a scratch probe (not kept) with enemies 1.2 m off the line at 3.5 m, and 2.5 m
  off at 5 m, saw the disc bend toward them and miss. Homing is a gentle bend, as specified.
- Ring's 40 % and the small discs' 30 % are of the disc's own damage (already x1.6 a pass), as the Lance's ring. Ring
  also rides an Echo ghost (it is the disc's own, not a follow-up); a ghost sheds no small discs.
- Mine: "the form's normal per-enemy hit rule" read as one hit per enemy per 30 ticks (`mine_gap_ticks`), the same
  gap as Ring; Ring's and Mine's gaps are kept apart. A disc that pierces the enemy right before its far point is
  left 0.02 m past it, so Mine only hits enemies that overlap the stop (ones that walk into it, or a neighbour): in
  the DPS sheet's scenes Mine alone reads x1.00 (see the table).
- Big Shot's speed x0.75 with an unchanged life of 60 ticks shortens the reach to 5.25 m out (the spec has no life
  change); Rapid Fire's x1.25 lengthens it to 8.75 m. Orbit turns 7 m out from the lap's end (9.5 m from the hero).
- Backfire under Halo adds nothing (a disc at 180 degrees exists), as the Lance's.
- Halo's centre-disc rule: with `share_permille` (the Glaive's 1600) the discs past the middle one of the fan are
  secondary shots (statuses at the secondary proc); with four discs the middle is the 90-degree disc (the same rule as
  the Lance's six).
- The Glaive's card descriptions still read their generic text; no strings added. `attacks.gd` is 1004 lines now:
  `# gdlint: disable=max-file-lines` at its top (the precedent: `world_snapshot.gd`, FC4).

## Commands and raw results (all `--language en`, own `APPDATA` per process, project.godot untouched)

- `godot --headless --path . --editor --import --quit`: 0 ERROR lines (before the work and after the new scripts).
- `gdformat` + `gdlint` on all touched `.gd` (and the two new balance/test scripts): "Success: no problems found".
- Unit/sim/presentation/content runs are `--headless --fixed-fps 60 -s addons/gut/gut_cmdln.gd -gtest=... -gexit`
  (folders: `-gdir=res://tests/<folder> -ginclude_subdirs`); the e2e run is `--headless` too (as `gut_shard.sh e2e`;
  the first e2e run without `--headless` failed on the dev panel's toggle, also for the existing Lance and Void e2e, and
  is not counted).

| Run | Tests | Passing | Asserts |
|---|---|---|---|
| tests/content | 157 | 157 | 12760 |
| tests/golden | 2 | 2 | 4 |
| tests/arch | 4 | 4 | 17808 |
| test_glaive_mods (new) | 31 | 31 | 208 |
| test_glaive, test_shot_rate_all_forms, test_glaive_view, test_glaive_mods (final, one process) | 49 | 49 | 612 |
| test_attack_slots, test_world_snapshot, test_modifier_equivalence, test_seekers, test_offers, test_lance_mods, test_void_mods (with test_glaive 10/11 and test_shot_rate 1/2 failing before the two test edits below) | 105 | 103 | 8834 of 8846 |
| test_glaive_view, test_lance_view, test_vx_looks (before the Ring view test was added) | 28 | 28 | 1348 |
| e2e: test_e2e_lance_halo, test_e2e_glaive_combos (new), test_e2e_glaive_seekers | 4 | 4 | 61 |

- Also run (one process, after the last code edit): test_gun_pool_order, test_player_builds, test_items, test_items_j,
  test_card_levels_clv, test_rewards, test_modifier_smoke, test_wand_migration, test_gun_heat_fill: 9 scripts, 133
  tests, 133 passing, 21020 asserts (the card pool, the offers and the migration with the Glaive row's new cards).
- Digests: none moved (test_modifier_equivalence and tests/golden pass unchanged). Goldens changed on purpose: none.
- Test edits that follow the approved change: `test_glaive.gd` `GLAIVE_ON` gains the eleven ids;
  `test_shot_rate_all_forms.gd` builds 33 -> 36 (the Glaive row's builds 2 -> 5); `test_glaive_view.gd` a Ring test.
  `tests/MIN_TEST_COUNT` not touched (raised from the green `verify` total of the PR).
- e2e `test_e2e_glaive_combos.gd` (main.tscn; altar by E and the pick panel, Halo and Echo by the dev panel's Grant
  clicks; floor enemies cleared and the hero walked to an open place as labelled helpers; the shoot button held with
  the mouse on a clear line): "FC6 e2e: most discs drawn 8; the four dummies hurt [true, true, true, true]" (four
  standing dummies 3 m round the hero, one every 90 degrees; 8 = four discs and their four echoes).
- Not run (per the step's list): test_five_floors, test_curse_room, test_event_rarity, test_event_rooms,
  test_purple_rooms, the seed-loop tests, `seams.sh`.

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

Orbs baseline: single 930, line 335, pack 330. Columns: single x, line x, pack x (all against the plain orbs), then
single, line, pack damage. Against the plain Glaive (640 / 1144 / 232) the ratios are in the last block.

```
glaive + (plain)          0.688 | 3.415 | 0.703 |  640 | 1144 |  232
glaive + halo_shot        0.344 | 1.707 | 0.352 |  320 |  572 |  116
glaive + gun_ring         0.946 | 4.078 | 1.494 |  880 | 1366 |  493
glaive + gun_backfire     0.688 | 3.415 | 0.703 |  640 | 1144 |  232
glaive + gun_ricochet     0.688 | 3.415 | 0.703 |  640 | 1144 |  232
glaive + gun_homing       0.688 | 3.415 | 0.703 |  640 | 1144 |  232
glaive + gun_echo         1.032 | 5.087 | 1.042 |  960 | 1704 |  344
glaive + gun_big_shot     1.032 | 4.621 | 1.018 |  960 | 1548 |  336
glaive + gun_rapid_fire   0.672 | 3.284 | 0.682 |  625 | 1100 |  225
glaive + split_shot       0.688 | 3.582 | 0.703 |  640 | 1200 |  232
glaive + gun_mine         0.688 | 3.534 | 0.679 |  640 | 1184 |  224
glaive + orbit_rounds     0.688 | 4.155 | 0.679 |  640 | 1392 |  224
```

Against the plain Glaive (computed from the damages above): Halo 0.50 / 0.50 / 0.50; Ring 1.38 / 1.19 / 2.13; Backfire,
Ricochet, Homing 1.00 / 1.00 / 1.00; Echo 1.50 / 1.49 / 1.48; Big Shot 1.50 / 1.35 / 1.45; Rapid Fire 0.98 / 0.96 /
0.97; Split 1.00 / 1.05 / 1.00; Mine 1.00 / 1.04 / 0.97; Orbit 1.00 / 1.22 / 0.97. **No single exceeds x2.0 and no
pack exceeds x6.0** (largest single x1.50, largest pack x2.13 on the sheet).

The sheet puts every enemy in front on the aim, so it cannot show Halo's other three discs, Mine's stop, Homing's bend
or Split's fork. `scripts/balance/glaive_dps_scenes.gd` (`godot --headless --path . -s scripts/balance/glaive_dps_scenes.gd`,
720 ticks, ratio against the plain Glaive in the same scene):

```
scene | cards | x vs plain Glaive | dmg | plain dmg
cross: four at 3 m, 90 degrees apart | halo_shot | 2.000 | 464 | 232
cross: four at 3 m, 90 degrees apart | gun_backfire | 2.000 | 464 | 232
cross: four at 3 m, 90 degrees apart | halo_shot+gun_echo | 1.448 | 336 | 232
cross: four at 3 m, 90 degrees apart | halo_shot+gun_echo+gun_big_shot | 4.345 | 1008 | 232
far five: a cluster at 7.4 m (the disc's far point) | gun_mine | 1.000 | 224 | 224
far five: a cluster at 7.4 m (the disc's far point) | gun_mine+gun_ring | 3.879 | 869 | 224
far five: a cluster at 7.4 m (the disc's far point) | gun_mine+gun_echo | 1.518 | 340 | 224
far five: a cluster at 7.4 m (the disc's far point) | gun_mine+gun_echo+gun_ring | 5.357 | 1200 | 224
far five: a cluster at 7.4 m (the disc's far point) | gun_mine+halo_shot | 0.250 | 56 | 224
aside: one at 5.5 m, 1.5 m off the aim | gun_homing | inf | 224 | 0
fork: one at 3 m and two on the +-30 degree lines at 5.1 m | split_shot | 1.241 | 288 | 232
pack: five on a 3 m arc at 4 m (forms_dps pack) | gun_ring+gun_echo+gun_big_shot | 3.284 | 762 | 232
pack: five on a 3 m arc at 4 m (forms_dps pack) | halo_shot+gun_echo+gun_big_shot | 1.099 | 255 | 232
pack: five on a 3 m arc at 4 m (forms_dps pack) | gun_ring+gun_mine+gun_big_shot | 2.897 | 672 | 232
```

(The card sets are legal wands: one Pattern card (Halo, Ring, Backfire) and up to two Secondary cards.) Highest pack
reading: Mine + Echo + Ring on a cluster at the stop point, x5.36 (target <= 6.0, met, close); Mine + Ring alone x3.88.
Notes (numbers, not decisions): Mine alone adds nothing against bodies it has just pierced; with Ring it adds the ring's
hits all through the 72-tick stop, and with Echo the ghost stops there too. Halo reads x2.00 against four enemies in a
cross (the plain disc hits only the one on the aim); Halo + Echo + Big Shot there x4.35. The three-card builds are
above the per-card targets' scale (those are for one card): none of them is a single-target reading.

## Not done / OWNER ONLY

- Feel and look of the halo, rings, ghosts, small discs and the stopped Mine disc on the owner's hardware: OWNER ONLY.
- Cards' en/es descriptions still read their generic text; no strings added.
