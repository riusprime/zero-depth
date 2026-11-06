# FC4: the Lance accepts nine more cards, and the Void's Mine and Big Shot are tamed (v0.9.5 Step FC4, FORM_COMBOS.md N1-N9)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc4` (cut from the worktree HEAD, then
  `claude/v095-feedback` merged); a file cannot name its own commit, the SHA is in the step report. Godot 4.7.2 stable;
  Windows 11 Pro, owner PC, several Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/lance_mods.gd` (pure, one handler per card; `LanceMods.DEFAULTS` = the data row, 22 keys). A lance
  ignores the nine cards' generic ops (`WandCompile.run` notes the id), the handlers read them from `modifier_ids`.
  - Charge (`GunForms.hold`, `Lance.orb`): Big Shot +0.3 s to fill (72 -> 90 ticks), Rapid Fire 40 % faster (72 -> 51
    ticks); both: (72 + 18) / 1.4 = 64.
  - Release (`Attacks._bolts`, `AttackContext.lance_full` set by `PlayerKit._fire_bolt`): Halo (full charge only) six
    lances every 60 degrees from the aim, each 50 %; a tap or partial charge fires one, whole. Backfire a lance
    straight behind at 50 % (skipped on a full Halo: it already has one at 180 degrees). Ricochet 1 wall bounce, full
    charge only. Big Shot x1.6 damage, ball twice as wide (`ctx.size_permille` x 2000 / 1000; the charge circle too).
    Rapid Fire x0.7 damage. Echo: each lance leaves a row; 24 ticks later a ghost lance flies the same line (the
    muzzle and angle of the release, 50 % of that lance's damage, same bounces), starts no follow-ups.
  - Flight: Homing (`ProjectileMoves.steer` -> `LanceMods.steer`) every tick turns at most 11/4096 turns (60 degrees a
    second) toward the nearest enemy within 12 m and within 60 degrees of its heading (ties keep the lower index;
    an enemy the ball overlaps is ignored). Split (`World._projectile_hits` -> `LanceMods.on_hit`): each of the first 6
    enemies a lance pierces spits two shards at +-90 degrees (3 m, stopped by a wall, 25 % of the lance's damage,
    TAG_SHRAPNEL, each enemy along the line once, the spitter excluded); the shard lands its hits at once.
  - End (`Attacks.on_projectile_end` -> `LanceMods.on_end`): Ring queues a lightning ring 0 to 2 m over 15 ticks (50 %
    of the lance's damage, each enemy once, TAG_AREA); an Echo ghost starts none.
  - Rows in `ModifierState.lm_*` (a live lance, a ghost to open, a ring growing, a shard for the view), at most 96,
    hashed only while set, listed in `WorldSnapshot`; `WorldReader.lance_rings()` / `lance_shards()`.
- Data: `data/wand/attack_slots.tres` lance row `allowed` += `halo_shot`, `gun_ring`, `gun_backfire`, `gun_ricochet`,
  `gun_homing`, `gun_echo`, `gun_big_shot`, `gun_rapid_fire`, `split_shot` and a `params` dictionary (22 keys);
  `AttackFormRow.LANCE_KEYS`; the validator checks the Lance's keys. Pierce, Mine, Orbit Rounds, Spiral, Swirl and
  Threadline stay off.
- View `lance_view.gd`: Ring's lightning ring growing (the Bomb's ring look, as the Void's); Split's shards as sparks
  racing along their lines. Echo's ghost, Halo's and Backfire's lances are drawn as any lance ball.
- `scripts/balance/forms_dps.gd`: the Lance's ten combinations; the Lance scene holds `LanceMods.hold_ticks` ticks.
- Deviations to flag: Echo's ghost is 50 % of each lance's own damage (under a full Halo that is 25 % of a whole lance);
  Backfire's lance is a secondary shot (feeds statuses at the secondary proc, as the Void's); Halo's six count against
  the shot cap (12 a volley) as any volley; Homing's reach (12 m) and cone are starting values in the row.

## The Void's two fixes (FC3 measured Mine at x7.98 single / x23.8 pack and Big Shot at x10.6 pack)

- **V9 Mine:** one void at a time. `VoidMods.held(w)`: while a Mine Void has a live void (flying or held), `PlayerKit`
  does not fire; the held void lasts 3 s (unchanged), then the next shot. Backfire + Mine still throws two (a card
  choice, not changed).
- **V6 Big Shot:** aura 1.6 -> 1.3 m, pull radius 4.5 -> 4.0 m, damage +60 % -> **+20 %** (see the numbers below: the
  pack target was missed with +30 %, so the bonus went to its floor; the tick damage is whole, 10 -> 12; +15 % would
  be 11.5 -> 11, below the floor).
- `tests/unit/sim/test_void_mods.gd` follows both: Big Shot reads 12 a tick, 1.3 m, 4.0 m, a pull test at 3.6 m off the
  path; a new test holds Mine to one void out and 2 to 3 voids in 8 s.

## Commands and raw results (all `--language en`, own `APPDATA`)

- `godot --headless --path . --editor --import --quit`: 0 ERROR lines (before the work and after the new scripts);
  `project.godot` untouched.
- `gdformat` + `gdlint` on all 24 touched `.gd`: "Success: no problems found". (`world_snapshot.gd` is 1003 lines now:
  `# gdlint: disable=max-file-lines` at its top, as other files do for the public-methods rule; `test_void_mods.gd`
  has `disable=max-public-methods`.)
- Final runs after the last code edit (each file its own process):

| Run | Tests | Passing | Asserts |
|---|---|---|---|
| tests/content | 157 | 157 | 12769 |
| tests/golden | 2 | 2 | 4 |
| tests/arch | 4 | 4 | 17719 |
| test_lance_mods (new) | 19 | 19 | 160 |
| test_void_mods | 21 | 21 | 1018 |
| test_lance | 13 | 13 | 126 |
| test_void | 17 | 17 | 738 |
| test_attack_slots | 17 | 17 | 525 |
| test_shot_rate_all_forms | 2 | 2 | 277 |
| test_offers | 7 | 7 | 316 |
| test_modifier_equivalence | 3 | 3 | 68 |
| test_world_snapshot | 15 | 15 | 6291 |
| test_lance_view | 6 | 6 | 24 |
| test_void_view | 5 | 5 | 18 |
| test_e2e_lance_halo (new) | 1 | 1 | 17 |
| test_e2e_lance_scatter | 2 | 2 | 34 |
| test_e2e_void | 1 | 1 | 16 |
| test_e2e_void_homing | 1 | 1 | 14 |

- Digests: none moved (test_modifier_equivalence and tests/golden pass unchanged). Goldens changed on purpose: none.
- Test edits that follow the approved change: `test_lance.gd` `LANCE_ON` gains the nine ids; `test_shot_rate_all_forms.gd`
  builds 30 -> 33 (the Lance row's builds 2 -> 5).
- e2e `test_e2e_lance_halo.gd` (main.tscn; altar by E and the pick panel, Halo by the dev panel's Grant clicks; floor
  enemies cleared and the hero walked back to the open start as labelled helpers): "FC4 e2e: charge 1.00; lances in
  the air at most 7; the six dummies hurt [true, true, true, true, true, true]" (six standing dummies 3 m round the hero,
  one every 60 degrees; the count is of all projectiles in the world, so the seventh was not identified).
- Not run (per the step's list): test_five_floors, test_curse_room, test_modifier_smoke, test_event_rarity,
  test_event_rooms, test_purple_rooms.

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

Orbs baseline: single 930, line 335, pack 330. Columns: single x, line x, pack x, single, line, pack damage.

```
lance + (plain)          0.998 | 5.194 | 1.055 |  928 | 1740 |  348
lance + halo_shot        0.499 | 2.597 | 0.527 |  464 |  870 |  174
lance + gun_ring         1.123 | 5.194 | 1.055 | 1044 | 1740 |  348
lance + gun_backfire     0.998 | 5.194 | 1.055 |  928 | 1740 |  348
lance + gun_ricochet     0.998 | 5.194 | 1.055 |  928 | 1740 |  348
lance + gun_homing       0.998 | 5.194 | 1.055 |  928 | 1740 |  348
lance + gun_echo         1.497 | 7.791 | 1.582 | 1392 | 2610 |  522
lance + gun_big_shot     1.385 | 6.866 | 1.394 | 1288 | 2300 |  460
lance + gun_rapid_fire   0.688 | 4.776 | 0.970 |  640 | 1600 |  320
lance + split_shot       0.998 | 5.194 | 2.073 |  928 | 1740 |  684

void + (plain)           1.011 | 4.955 | 3.091 |  940 | 1660 | 1020
void + gun_mine          1.484 | 3.045 | 4.545 | 1380 | 1020 | 1500
void + gun_big_shot      1.806 | 8.382 | 7.927 | 1680 | 2808 | 2616
```
Notes (numbers, not decisions): Halo shows x0.5 here because the scenes put every enemy in front: one of its six lances
(50 %) hits; its worth is against enemies all round the hero (the e2e). Backfire, Ricochet and Homing read as the plain
Lance in these scenes (nothing behind, no wall, the enemy already on the line). Ring reaches the single dummy; Split
shows its gain only in the pack. **Void targets:** Mine single x1.48 (target <= 2.0) and pack x4.55 (<= 6.0): met with
no change to the 3 s hold. Big Shot pack **x7.93 (target <= 6.0): NOT met** even with the damage bonus at its +20 %
floor (with +30 % it was x8.59, and before FC4 x10.57); single x1.81, line x8.38. The rest of the gap is the aura (1.3 m
against the plain 1.0 m) and the pull (4.0 m against 3.0 m) on a pack; lowering either is the owner's call.

## Not done / OWNER ONLY

- Feel and look of the halo, rings, ghosts and shards on the owner's hardware: OWNER ONLY.
- Cards' en/es descriptions still read their generic text; no strings added.
