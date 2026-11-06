# FC5: the Rune Explosion accepts nine more cards (v0.9.5 Step FC5, FORM_COMBOS.md R1-R9)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc5` (cut from the worktree HEAD `eec88333`, which already
  held `claude/v095-feedback`; a file cannot name its own commit, the SHA is in the step report); Godot 4.7.2 stable;
  Windows 11 Pro, owner PC, several Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/rune_mods.gd` (pure, one handler per card; `RuneMods.DEFAULTS` = the data row, 24 keys). A rune burst
  ignores the eight cards' generic ops (`WandCompile.run` only notes the id); Twin (R1) stays the form's own
  (`RuneExplosion.fire`: a second shield at 70 % radius and damage 12 ticks after; Lv 3 two).
  - At the cast (`RuneExplosion.fire`): Big Shot 5 m, x1.6, period 90 ticks; Rapid Fire 2.5 m, x0.7, period 42 ticks
    (`radius_mm`, `damage`, `period`; with both cards the later one in the wand sets radius and period, the damage
    multiplies); Homing centres the burst on the nearest enemy within 6 m (lowest index on a tie; none: on the hero, and
    it follows the hero as a plain burst does) as a fixed centre kept in a `K_BURST` row; Echo queues a second burst at
    the same place 36 ticks later at 60 % (a `K_BURST` row with `F_FIXED | F_NOFOLLOW`; its glyph is drawn while it
    waits); Mine leaves a trap (`K_MINE`) at the burst point for 240 ticks.
  - At full size (`RuneExplosion.advance` -> `on_full`): Ring holds a lightning ring for 48 ticks at the burst's full
    radius, hitting each enemy in it once more at 100 % (`K_HOLD`); Ricochet shrinks the shield back to 0 over the same
    21 ticks, hitting each enemy it passes once more at 50 % (`K_SHRINK`).
  - At each hit (`RuneExplosion._hit` -> `on_hit`): Split throws 2 shards from the enemy, outward at plus and minus 30
    degrees about the burst-centre-to-enemy direction, 25 % damage, 4 m over 24 ticks (`K_SHARD`); a shard ends on the
    first enemy it touches (not its source); at most 24 live (a shard past it is not thrown).
  - Mine: the first enemy whose edge comes within 0.6 m of the trap sets off a 2 m burst at 100 % (a fixed, no-follow
    burst); at most 4 live traps a hero (the oldest ends first).
  - Follow-ups start none: Echo's and Mine's bursts are `F_NOFOLLOW` (no ring, shrink, echo, mine or shards of their own);
    shards and traps are not bursts. Each enemy is hit at most once per burst, ring hold and shrink (`rm_hit_*`).
    Bursts alive never pass `BURSTS_MAX` 12 for follow-ups; rows at most 64. No card throws a projectile, so none
    spends the 40-shots-a-second cap (the form's rule since FC0: bursts are no projectile).
- `RuneExplosion`: the radius and damage read RuneMods, each burst has a centre (`RuneMods.centre_of`: the hero unless
  fixed), `_drop`/`_clear` forget the rows, `read()` reports the burst's centre.
- State rows `ModifierState.rm_*` (13 fields), hashed only while set (`rm_touched()`), listed through
  `RuneMods.SNAPSHOT_FIELDS`, which `WorldSnapshot._apply_object` honours beside `ADDED_SINCE_V05` (the file is at its 1000-line cap and gdformat would re-indent the whole dict), so an older save loads. Reader:
  `WorldReader.rune_effects()` ({holds, shrinks, mines, shards, glyphs}).
- Data: `data/wand/attack_slots.tres` rune_explosion row `allowed` += Ring, Ricochet, Homing, Echo, Big Shot, Rapid Fire,
  Split, Mine (Twin was already on) and a `params` dictionary (24 keys); `AttackFormRow.RUNE_KEYS`; the validator checks
  the row's keys (`_keys_of`). Halo, Backfire, Pierce, Orbit Rounds, Spiral, Swirl and Threadline stay off.
- View `rune_explosion_view.gd`: bursts pool 3 -> 6 (a fixed burst's centre), the cards' floor rings reuse the rune ring
  shader (held Ring, shrinking shield, trap, Echo glyph), Split's shards are small violet beads. No new art.
- `scripts/balance/forms_dps.gd`: the Rune Explosion's ten combinations (plain, Twin, and the eight others), NEAR scenes.
- Deviations to flag (numbers the spec did not give, or choices inside it):
  - Shard flight: 24 ticks for the 4 m (10 m/s); shard hit reach 0.3 m plus the enemy's radius; a shard ends on the first
    enemy it touches. The spec gave only 25 %, 4 m and the angles.
  - A shard past the 24-live cap is not thrown (the Void's cap ends the oldest; the spec did not say which here).
  - Distances use the enemy's edge (`enemies_near`): the Mine trigger 0.6 m and Homing's 6 m target test centres; Mine's 2 m
    burst reaches an enemy whose edge is within 2 m (the area stat scales it like the 3.5 m).
  - Ring holds at the hero's place when full (it does not follow the hero); with a Homing target it holds on the target.
  - Big Shot and Rapid Fire together: the later card sets radius and period, the damage multiplies (x1.12).
  - Echo and Mine follow the first burst of a cast only (not Twin's later one).
  - The shrink starts counting at its second tick (its first tick is the full-size tick the burst already hit on).
  - Twin's numbers stay constants in `RuneExplosion` (FC0), not row params.

## Commands and raw results (all `--language en`, own `APPDATA`)

- `godot --headless --path . --editor --import --quit`: 0 ERROR lines.
- `gdformat` + `gdlint` on all touched `.gd`: "Success: no problems found" (final whole-tree lint: see the step report).
- New unit tests (`tests/unit/sim/test_rune_mods.gd`, 20 tests: bits and skipped generic ops, the data and key lists, the
  row's allowed list, one test a card with its numbers, the Split 24 cap, the Mine 4 cap, no projectile, once per ring
  and shrink, determinism, snapshot round trip and hash, an older save without the rows) and the view test
  (`test_rune_explosion_view.gd`, one new test).
- Batch (one process): test_rune_mods, test_rune_explosion, test_attack_slots, test_modifier_equivalence, test_offers,
  test_shot_rate_all_forms, test_wand_compile, test_world_snapshot, test_rune_explosion_view, test_e2e_rune_combos,
  test_e2e_attack_slots: 11 scripts, 103 tests, 102 passing, 1 failing, 8111 of 8112 asserts. The failure was
  test_shot_rate_all_forms' stale build count (30; the Rune Explosion row now takes Ring as a Pattern, 31). After the
  edit: test_shot_rate_all_forms alone 1 script, 2 tests, 2 passing, 261 asserts.
- `tests/content` + `tests/golden` + `tests/arch`: 33 scripts, 163 tests, 163 passing, 30424 asserts.
- Digests: none moved (tests/golden and test_modifier_equivalence pass unchanged). Goldens changed on purpose: none.
- Test edits that follow the approved change: test_rune_explosion.gd `allowed` list (Twin, the eight cards, the five
  elements); test_shot_rate_all_forms.gd 30 -> 31 builds.
- e2e `test_e2e_rune_combos.gd` (main.tscn; altar by E and the pick panel, Big Shot and Split by the dev panel's Grant
  clicks; floor enemies cleared as a labelled helper): "FC5 e2e: the dummies (4.6 m, +30, -30) hurt [true, true, true],
  shards drawn at most 2" (the first dummy sits past a plain burst's 3.5 m, the other two beyond even Big Shot's reach:
  only the shards can hurt them).

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

NEAR scenes (single at 2.5 m; line five at 1 to 3 m; pack five on a 2.5 m arc). Orbs baseline there: single 935, line
330, pack 335. Columns: single x, line x, pack x (against the orbs), then single, line, pack damage; the last two columns
are the ratio of single and pack damage to plain Rune Explosion (468 single, 810 pack), computed by hand from the damage.

```
rune_explosion (near) + (plain)          | 0.501 | 2.455 | 2.418 |  468 |  810 |  810 | 1.00 | 1.00
rune_explosion (near) + gun_twin         | 0.848 | 3.873 | 4.164 |  793 | 1278 | 1395 | 1.69 | 1.72
rune_explosion (near) + gun_ring         | 0.982 | 4.909 | 4.836 |  918 | 1620 | 1620 | 1.96 | 2.00
rune_explosion (near) + gun_ricochet     | 0.741 | 3.682 | 3.627 |  693 | 1215 | 1215 | 1.48 | 1.50
rune_explosion (near) + gun_homing       | 0.501 | 2.455 | 2.418 |  468 |  810 |  810 | 1.00 | 1.00
rune_explosion (near) + gun_echo         | 0.795 | 3.988 | 3.896 |  743 | 1316 | 1305 | 1.59 | 1.61
rune_explosion (near) + gun_big_shot     | 0.558 | 2.636 | 2.597 |  522 |  870 |  870 | 1.12 | 1.07
rune_explosion (near) + gun_rapid_fire   | 0.556 | 2.245 | 2.716 |  520 |  741 |  910 | 1.11 | 1.12
rune_explosion (near) + split_shot       | 0.501 | 3.545 | 2.418 |  468 | 1170 |  810 | 1.00 | 1.00
rune_explosion (near) + gun_mine         | 0.501 | 3.927 | 2.418 |  468 | 1296 |  810 | 1.00 | 1.00
```
Ratios vs plain Rune Explosion: none is above x2.0 single (highest Ring 1.96) or x6.0 pack (highest Ring 2.00), so nothing
was retuned. Notes (numbers, not decisions): the harness puts the dummies back each tick and the hero never moves, so
Homing (a burst on a standing enemy hits the same), Split's shards and Mine's trap add nothing in the single and pack
scenes (Split and Mine show in the line scene: 1170 and 1296 against 810, x1.44 and x1.60); the rows of Ring and Echo
show their extra hits; the numbers say nothing about a moving pack.

## Not done / OWNER ONLY

- Feel and look of the held ring, shrinking shield, shards, glyph and traps on the owner's hardware: OWNER ONLY.
- Cards' en/es descriptions still read their generic text; no strings added.
- Not run (per the step's list): test_five_floors, test_curse_room, test_modifier_smoke, test_event_rarity,
  test_event_rooms, test_purple_rooms, seams.sh, the full suite.

## Final re-run after moving the snapshot list (one process)

test_rune_mods, test_world_snapshot, test_rune_explosion, test_modifier_equivalence, tests/golden, tests/arch: 7 scripts,
59 tests, 59 passing, 24511 asserts. Digests unmoved. The `tests/content` run above (33 scripts, 163 tests) was before this
two-line move and is not re-run.
