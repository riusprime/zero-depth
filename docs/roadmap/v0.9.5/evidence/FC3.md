# FC3: the Void accepts ten more cards (v0.9.5 Step FC3, FORM_COMBOS.md V1-V10)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc3` (cut from the worktree HEAD `dafddf30`, which already
  held `claude/v095-feedback`; a file cannot name its own commit, the SHA is in the step report); Godot 4.7.2 stable;
  Windows 11 Pro, owner PC, several Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/void_mods.gd` (pure, one handler per card; `VoidMods.DEFAULTS` = the data row, 31 keys). A void ignores
  the ten cards' generic ops (`WandCompile.run` notes the id; Split also notes its level as `bomblets:N`).
  - Throw (`Attacks._bolts`): Big Shot x1.6 damage, 0.7 speed, aura 1.6 m, pull 4.5 m; Rapid Fire period 0.4 s (36 to 24
    ticks), half life, aura 0.7 m (pull stays 3 m), x0.7 damage; Ricochet 64 wall bounces (the world's own wall pass
    reflects it; its life is unchanged); Orbit one extra second of life; Backfire a second void straight behind (100 %,
    one shot-cap spend).
  - Flight (`ProjectileMoves.steer` -> `VoidMods.steer`): Orbit circles the hero once (2.5 m, 60 ticks) then flies out
    along the aim; Mine stops it at the aim point (`aim_dist_cm`, kept 0.5 m inside its reach) and holds 180 ticks, the
    aura ticking; Homing every 30 ticks picks the enemy within 6 m with the most enemies within 2 m of it (a tie keeps
    the lower index) and turns toward it at most 17/4096 turns a tick (90 degrees a second).
  - End (`Attacks.on_projectile_end` -> `VoidMods.on_end`): Ring queues a lightning ring 0 to 3 m over 18 ticks (damage
    30 = 60 % of 5 aura ticks of 10, each enemy once, TAG_AREA); Echo and Split queue still voids (K_SPAWN rows opened
    by `advance` on the next tick): Echo 60 % damage, half the life, half the aura and pull radius; Split 2/3/4 minis
    (by level) 1.5 m out at even angles from the travel, 60 ticks, 40 %, aura 0.6 m, pull 1.8 m. Echo, minis and Ring
    start no follow-ups.
  - Bounds: at most 6 live voids a hero (`VoidMods.cull` after `advance` and after the spawns apply: the oldest ends
    first, its follow-ups still queue); no void pulls a boss or elite (`VoidShots.pull_permille`, unchanged); rows at
    most 64.
- `VoidShots`: the aura and pull radius are per void (`aura_of`, `VoidMods.pull_mm`); a void that is still (Mine, Echo,
  a mini) pulls toward its point.
- Rows in `ModifierState.vm_*` (a live void's state, a void to open, a ring growing), hashed only while set, listed in
  `WorldSnapshot`; `WorldReader.void_rings()`.
- Data: `data/wand/attack_slots.tres` void row `allowed` += the ten ids (Ring, Backfire, Ricochet, Homing, Echo, Big
  Shot, Rapid Fire, Split, Mine, Orbit Rounds) and a `params` dictionary (31 keys); `AttackFormRow.VOID_KEYS`; the
  validator checks the Void's keys too (`_keys_of`). Halo, Pierce, Spiral, Swirl and Threadline stay off.
- View `void_view.gd`: Ring's lightning ring growing (the Bomb's ring look). Echo's and Split's still voids, Mine's held
  void and Backfire's void are drawn as any void.
- `scripts/balance/forms_dps.gd`: the Void's eleven combinations.
- Deviations to flag: a queued follow-up opens the tick after the void ends (one tick of delay); Echo and the minis
  are still (they do not drift); Mine and the Ring/Echo/Split follow-ups of a cap-ended void still happen; Rapid
  Fire keeps the pull radius at 3 m (the row says only "aura 0.7 m").

## Commands and raw results (all `--language en`, own `APPDATA`)

- `godot --headless --path . --editor --import --quit`: 0 ERROR lines (before the work and after the new scripts).
- `gdformat` + `gdlint` on all touched `.gd`: "Success: no problems found".
- Sim batch 1 (one process, before the stale tests were fixed): test_void, test_attack_slots, test_shot_rate_all_forms,
  test_offers, test_modifier_equivalence, test_world_snapshot, test_void_mods, test_bomb, test_bomb_mods,
  test_laser_mods, test_card_levels_clv, test_player_builds, test_rewards, test_items: 14 scripts, 199 tests, 197
  passing, 2 failing (both stale expectations that follow the approved change, below), 11376 asserts passed of 11433.
- After fixing them: test_void, test_shot_rate_all_forms (builds 28 -> 30: the Void row's builds 2 -> 4), test_void_mods
  (new, 20 tests), test_void_view (new test), test_e2e_void_homing (new), test_e2e_void: 6 scripts, 46 tests, 46
  passing, 2055 asserts.
- Presentation + e2e, first run: test_bomb_view, test_e2e_void, test_e2e_void_homing, test_e2e_bomb,
  test_e2e_attack_slots (test_void_view had a parse error, fixed and run in the line above): 5 scripts, 9 tests, 9
  passing, 105 asserts.
- `tests/content` + `tests/golden` + `tests/arch`: 33 scripts, 163 tests, 163 passing, 30376 asserts (final run, after
  the last edit: see the step report).
- Digests: none moved (test_modifier_equivalence and tests/golden pass unchanged). Goldens changed on purpose: none.
- Test edits that follow the approved change: test_void.gd `VOID_ON` gains the ten ids (Ring and Backfire no longer
  "never"; the off list is Halo, Spiral, Swirl, Pierce, Threadline); test_shot_rate_all_forms.gd 28 -> 30 builds.
- e2e `test_e2e_void_homing.gd` (main.tscn; altar by E and the pick panel, Homing by the dev panel's Grant clicks; floor
  enemies cleared as a labelled helper): "FC3 e2e: the four dummies hurt [true, true, true, true], voids drawn at most
  2" (a group of 4 standing 3 m to the side of the aim line, outside a plain void's aura, took damage).

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

Orbs baseline: single 930, line 335, pack 330. Columns: single x, line x, pack x, single, line, pack damage.

```
void + (plain)           1.011 | 4.955 | 3.091 |  940 | 1660 | 1020
void + gun_homing        1.011 | 3.970 | 3.091 |  940 | 1330 | 1020
void + split_shot        1.011 | 4.955 | 3.091 |  940 | 1660 | 1020
void + gun_mine          7.978 | 16.149 | 23.818 | 7420 | 5410 | 7860
void + gun_rapid_fire    1.054 | 3.134 | 2.121 |  980 | 1050 |  700
```
Other Void rows: ring, backfire, ricochet, echo = plain (1.011 / 4.955 / 3.091: the void ends beyond the scene, and
Backfire throws behind), big_shot 2.409 / 11.176 / 10.570, orbit_rounds 1.000 / 5.463 / 3.000. Notes (numbers, not
decisions): Split, Ring and Echo show no gain in these scenes because the void ends past the enemies; Mine is 8x to 24x
the orbs here (up to 5 held voids at once each tick on the same enemies, since a void's wait is per void); Big Shot
2.4x single (x1.6 damage and a 1.6 m aura on top). No target was set for these, so nothing was retuned.

## Not done / OWNER ONLY

- Feel and look of the ring, held mines, echoes and minis on the owner's hardware: OWNER ONLY.
- Cards' en/es descriptions still read their generic text; no strings added.
- Not run (per the step's list): test_five_floors, test_curse_room, test_modifier_smoke, test_event_rarity,
  test_event_rooms, test_purple_rooms.
