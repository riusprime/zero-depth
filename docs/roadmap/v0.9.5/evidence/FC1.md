# FC1: the Laser accepts eleven more cards (v0.9.5 Step FC1, FORM_COMBOS.md L1-L11)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc1` (cut from the worktree HEAD `25500066`, then
  `claude/v095-feedback` merged; a file cannot name its own commit, the SHA is in the step report); Godot 4.7.2 stable;
  Windows 11 Pro, owner PC (RTX 3060), several Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26
- **Who ran it:** agent

Owner line: "we have almost all combinations disbled for new attack forms, we should have more fun interactions ... for
example homing + laser would make the laser follow the neares enemy making a smooth curve, and with pierce it would
make a smooth curve trying to hit the closest 5 enemies".

## What was built

- `src/sim/combat/laser_mods.gd` (pure, one handler per card): `LaserMods.plan` is the beam geometry (the tick's hits
  and the view's beams share it); `LaserMods.advance` (ModifierRuntime phase 6) keeps the state. `Laser.trace` calls
  `plan` when the beam carries any of the eleven cards (a plain Laser takes the old path, digests unchanged);
  `Laser.fire` deals each beam its share of the tick, each kind hitting an enemy once a tick.
- A held beam ignores these cards' generic ops (`WandCompile.run`: it only notes the id in `modifier_ids`), so Ring does
  not widen the beam to 2 m, Echo queues no Twin Cast, Big Shot adds no 1.8x, Mine and Split add no hooks.
- L1 Halo: 3 beams of 3 m at -30, 0, +30 degrees from the main beam's end heading, 40 % (past the enemy the beam ended
  on). L2 Ring: a 1.4 m circle at the tip, 50 %, TAG_AREA. L3 Backfire: 4.5 m behind, 100 %. L4 Homing: the beam's own
  aim (`lz_aim`) turns at most 120 degrees a second (dithered, 1365 units a second of 4096 a turn) toward the nearest
  enemy in reach (targets picked every 0.2 s); the path is legs of 1.5 m that each bend at most 25 degrees toward the
  current target; with Pierce, up to 5 targets, nearest first, each leg bending to the next, total path 9 m. L5
  Ricochet: reflects once off the first wall, the total stays 9 m. L6 Echo: each tick's main legs strike again 24 ticks
  later at 50 % (at most 8 ticks live). L7 Big Shot: width x2, damage x1.6 (6400 thousandths a tick), the aim follows the
  player's at 504 degrees a second (720 x 70 %; with Homing 120 x 70 %). L8 Rapid Fire: the period goes from 6 ticks
  to 3 over 120 ticks held (`ItemEffects.shot_period_ticks`), width down to 50 %. L9 Split: two 4 m beams at +-25
  degrees from the first enemy hit, 50 %, past that enemy. L10 Mine: every 60 ticks a mine at the tip (5 ticks of
  damage, 1.5 m burst when an enemy comes within 0.6 m, at most 4, lives 4 s). L11 Spiral: a triangle wave on
  `w.tick`, +-136 units (12 degrees), 30-tick period (2 Hz), no randomness.
- Data: `data/wand/attack_slots.tres` (laser row `allowed` += the 11 ids; new `params` dictionary, every number above, in
  the units its key names); `AttackFormRow.params`, `SlotTable.params`, `AttackFormRow.LASER_KEYS` (the validator's
  list, a test holds it equal to `LaserMods.DEFAULTS`); `AttackSlotsDefinition` validates the params (whole numbers
  above 0, none missing, none unknown). Orbit, Swirl and Threadline stay off.
- State: `ModifierState.lz_*` (aim, hold, targets, mines, Echo's rows), hashed and listed in `WorldSnapshot` only while
  set (a plain Laser leaves them untouched; a test holds that). Mine is its own small state (not a projectile: no cap
  cost); the view draws it with the flat ring and spark.
- View `laser_view.gd`: a growing ribbon pool (same beam shader, `wmul` width), Echo's ghost ribbons (paler), Ring's
  circle and the mines as flat rings; `fog_disabled` and the shader masks are the shader's own, unchanged.
  `WorldReader.laser_ghosts()` and `laser_mines()`.
- `scripts/balance/forms_dps.gd` also measures the Laser with eleven card combinations; `scripts/shots/laser_fc1.gd`
  renders three shots.

## Caps

A beam is no projectile (0 in `ShotCap` and the 40 a second); `test_shot_rate_all_forms` now enumerates 25 builds
(laser 5, was 2) and still reads 0 projectiles for every laser build. The extras are bounded: the path has at most 14
legs, Echo 8 ticks, Mine 4 mines; each beam kind hits an enemy at most once a tick.

## Commands and raw results (all `--language en`, own `APPDATA`)

- `godot --headless --path . --editor --import --quit`: no ERROR lines.
- `gdformat` + `gdlint` on all touched `.gd`: "Success: no problems found".
- `tests/unit/sim/test_laser_mods.gd`: 19/19 passing, 217 asserts.
- One process: test_laser_mods, test_laser, test_attack_slots, test_shot_rate_all_forms, test_offers,
  test_modifier_equivalence, test_world_snapshot, test_card_levels_clv, test_gun_heat_fill, test_items, test_items_j,
  test_player_builds, test_rewards, tests/content/test_attack_slots_validation: 14 scripts, 177 tests, 177 passing, 10119
  asserts.
- One process: test_laser_view, test_vx_looks, test_audio_director, test_e2e_laser, test_e2e_laser_homing (new),
  test_e2e_attack_slots, tests/golden/test_replay_ground_plane: 7 scripts, 44 tests, 44 passing, 1676 asserts. Then
  test_laser_view alone after adding its new test (FC1 cards drawn): 6 tests, 6 passing, 53 asserts.
- `tests/content` folder: 30 scripts, 157 tests, 157 passing. `tests/golden`: 2/2. `tests/arch`: 4/4 (the first run
  failed: the content layer used `LaserMods`; fixed with `AttackFormRow.LASER_KEYS`).
- Digests: none moved (`test_modifier_equivalence` and the replay golden pass unchanged). Goldens changed on purpose:
  none.
- Test edits that follow the approved change: `test_laser.gd` `LASER_ON` gains the 11 ids and the "a held-off card
  stops compiling" test uses Orbit and Swirl (still off) instead of Halo and Ricochet; `test_shot_rate_all_forms.gd`
  count 22 -> 25.
- e2e `test_e2e_laser_homing.gd` (main.tscn, input by `Input.parse_input_event` only; the altar take is E + pick panel,
  Homing and Pierce by the dev panel's Grant clicks as EE1 did; the floor's own enemies are cleared as a labelled test
  helper because they shove the hero): "FC1 e2e: 5 of 5 dummies hurt after 240 frames held; curve drawn as >= 3
  ribbons: true".
- Shot: `godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/laser_fc1.gd`; files
  `build/shots/v0.9.5/fc1/1_homing_pierce.jpg` (the beam bends through five dummies on a curve, six ribbons),
  2_halo_ring, 3_echo_mine (the script writes under the project's version label `v0.9.0`; copied to v0.9.5).

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

Orbs baseline (plain, no cards): single 930, line 335, pack 330.

```
form | card Lv | Twin Lv 5 | single x | line x | pack x | single dmg | line dmg | pack dmg
laser | 1 | no | 1.204 | 1.194 | 1.212 | 1120 | 400 | 400
laser + (plain) | 1 | no | 1.204 | 1.194 | 1.212 | 1120 | 400 | 400
laser + gun_pierce | 1 | no | 1.204 | 5.970 | 1.212 | 1120 | 2000 | 400
laser + gun_homing | 1 | no | 1.204 | 1.194 | 1.212 | 1120 | 400 | 400
laser + gun_homing+gun_pierce | 1 | no | 1.204 | 5.970 | 2.424 | 1120 | 2000 | 800
laser + gun_big_shot | 1 | no | 1.927 | 1.910 | 1.939 | 1792 | 640 | 640
laser + gun_rapid_fire | 1 | no | 2.409 | 2.388 | 2.424 | 2240 | 800 | 800
laser + halo_shot | 1 | no | 1.204 | 1.493 | 1.818 | 1120 | 500 | 600
laser + gun_backfire | 1 | no | 1.204 | 1.194 | 1.212 | 1120 | 400 | 400
laser + gun_echo | 1 | no | 1.806 | 1.791 | 1.818 | 1680 | 600 | 600
laser + gun_mine | 1 | no | 1.806 | 1.791 | 4.242 | 1680 | 600 | 1400
laser + split_shot+gun_pierce | 1 | no | 1.204 | 5.970 | 2.424 | 1120 | 2000 | 800
```

Homing + Pierce against plain Laser: single the same (1.204), line 5.970 vs 1.194 (Pierce's effect; Homing adds nothing
on a straight line), pack 2.424 vs 1.212 (twice: the curve reaches the arc's neighbours). Flags for the owner (numbers,
not decisions): Rapid Fire doubles the Laser's damage once ramped (2.4x orbs single: the table keeps the tick damage and
halves the tick period); Mine reaches 4.2x orbs on the pack (mines stack where the beam ends); Echo +50 % everywhere.
No target was set for these in FORM_COMBOS, so nothing was retuned.

## Not done / OWNER ONLY

- Feel and look of the curve, ghosts, ring and mines on the owner's hardware: OWNER ONLY.
- A threaded path is capped at the beam's 9 m total reach, so five enemies spread wider than that are not all reached.
- The cards' descriptions (en/es) still read their generic text; no new strings were added.
- Not run (per the step's list): test_five_floors, test_curse_room, test_modifier_smoke, test_event_rarity,
  test_event_rooms.
