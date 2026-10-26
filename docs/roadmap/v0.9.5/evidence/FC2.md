# FC2: the Bomb accepts ten more cards; Rapid Fire's Laser stays fair (v0.9.5 Step FC2, FORM_COMBOS.md B1-B10)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc2` (cut from the worktree HEAD, then `claude/v095-feedback`
  merged; the SHA is in the step report); Godot 4.7.2 stable; Windows 11 Pro, owner PC, several Godot processes at once
  (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/bomb_mods.gd` (pure, one handler per card; `BombMods.DEFAULTS` = the data row). A bomb ignores the ten
  cards' generic ops (`WandCompile.run` notes the id; Split also notes its level as `bomblets:N`).
  Throw: Halo (4 bombs in a cross 3 m round the hero, 100 %, landing after 0.2 s, level adds nothing), Backfire (a bomb at
  the feet, 0.5 s fuse, 100 %), Big Shot (3.3 m, x1.6, thrown at 75 % speed, same reach), Rapid Fire (period x0.6, 1.6 m,
  damage x0.65). Landing: Ricochet (bursts 2 m further along the travel, a wall stops it), Homing (on the nearest enemy
  within 3 m of the landing point), Mine (waits; bursts at 100 % when an enemy is within 1.5 m, at most 5, the oldest
  bursts for a 6th, 12 s then burst), and after a burst Ring (lightning ring 0 to 3.5 m over 0.4 s, each enemy once, 50 %),
  Echo (same spot 0.5 s later, 50 %), Split (2/3/4 bomblets by level, 2 m out at even angles from the aim, 0.3 s fuse,
  1.2 m, 40 %). Echo, bomblets and ring hits start no follow-ups of their own.
- Rows in `ModifierState.bm_*` (at most 64; not projectiles, no shot cap touched), hashed only while set, listed in
  `WorldSnapshot`; `WorldReader.bomb_rows()`.
- Data: `data/wand/attack_slots.tres` bomb row `allowed` += the ten ids and a `params` dictionary (25 keys);
  `AttackFormRow.BOMB_KEYS`; the validator checks both forms' keys (`_keys_of`). Pierce, Orbit, Spiral, Swirl and Threadline
  stay off.
- View `bomb_view.gd`: waiting bombs (Halo, Backfire, Mine) drawn as bombs, Ring drawn as a growing lightning ring.
- Deviations to flag: Halo's four bombs land after 0.2 s (`halo_delay_ms`; the row says only "land"); Big Shot's slower
  throw keeps the 8 m reach (life unchanged); the Big Shot / Rapid Fire blasts are stored as 3300 / 1600 mm.
- FC1 follow-up: new Laser param `rapid_damage_permille` = 650; tick damage 1000 to 650 along the period ramp.

## Commands and raw results (all `--language en`, own `APPDATA`)

- `godot --headless --path . --editor --import --quit`: 0 ERROR lines (before and after).
- `gdformat` + `gdlint` on all 20 touched `.gd`: "Success: no problems found".
- Sim, one process: test_bomb_mods (new, 20 tests), test_bomb, test_laser_mods, test_laser, test_attack_slots,
  test_shot_rate_all_forms (builds 25 -> 28, bomb 5), test_offers, test_modifier_equivalence, test_world_snapshot,
  test_card_levels_clv, test_player_builds, test_rewards, test_items: 13 scripts, 178 tests, 178 passing, 10020 asserts.
- `tests/content` + `tests/golden` + `tests/arch`: 33 scripts, 163 tests; the first run had 1 failing (arch: the view used
  `BombMods`; fixed with `BombMods.KIND_NAMES` through the reader). Arch re-run with test_bomb_view, test_bomb_mods and the
  two bomb e2e: 6 scripts, 30 tests, 30 passing.
- Presentation + e2e: test_bomb_view (new test), test_e2e_bomb, test_e2e_bomb_split (new), test_e2e_attack_slots,
  test_e2e_laser, test_laser_view: 6 scripts, 15 tests, 15 passing, 155 asserts.
- Digests: none moved (test_modifier_equivalence and tests/golden pass unchanged). Goldens changed on purpose: none.
- Test edits that follow the approved change: test_bomb.gd `BOMB_ON` gains the ten ids (Ring no longer "never");
  test_laser_mods.gd Rapid Fire test asserts the damage ramp (1000, 825, 650, 650 per mille) and about 52 a second ramped.
- e2e `test_e2e_bomb_split.gd` (main.tscn; altar by E and the pick panel, Split by the dev panel's Grant clicks; floor
  enemies cleared as a labelled helper): "FC2 e2e: hurt [true, true], 3 blasts after 50 frames held" (the dummy burst on and
  the one 3.2 m past the blast, outside it, took bomblet damage; Grant gave Split Lv 1: 2 bomblets).

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

Orbs baseline: single 930, line 335, pack 330. Columns: single x, line x, pack x, single, line, pack damage.

```
laser + (plain)          1.204 | 1.194 | 1.212 | 1120 | 400 | 400
laser + gun_rapid_fire   BEFORE (FC1): 2.409 | 2.388 | 2.424 | 2240 | 800 | 800
laser + gun_rapid_fire   AFTER:        1.566 | 1.552 | 1.576 | 1456 | 520 | 520   (1.30 x plain)
bomb + (plain)           0.662 | 1.313 | 3.333 |  616 | 440 | 1100
bomb + split_shot        0.903 | 1.791 | 3.576 |  840 | 600 | 1180
bomb + gun_mine          0.662 | 1.313 | 3.333 |  616 | 440 | 1100
bomb + gun_rapid_fire    0.708 | 0.669 | 3.606 |  658 | 224 | 1190
```
Other bomb rows: halo 1.325/3.284/6.667, ring 0.994/2.299/5.000, backfire 0.662/1.970/3.333, ricochet 0.662/1.970/3.333,
homing 0.662/1.313/3.333, echo 0.994/1.970/5.000, big_shot 1.054/2.090/5.303. Notes (numbers, not decisions): Mine equals
plain here because the first enemy is within 1.5 m of the landing, so it bursts at once; Rapid Fire's line scene is half of
plain (a 1.6 m blast reaches fewer of the five on the line), single and pack are within +10 %; Halo reaches 6.7x orbs on the
pack. No target was set for these, so nothing was retuned.

## Not done / OWNER ONLY

- Feel and look of the ring, waiting bombs and bomblets on the owner's hardware: OWNER ONLY.
- Ricochet is an instant displacement of the burst (the bomb is not drawn skipping); Homing moves the burst, not the flight.
- Cards' en/es descriptions still read their generic text; no strings added.
- Not run (per the step's list): test_five_floors, test_curse_room, test_modifier_smoke, test_event_rarity, test_event_rooms.
