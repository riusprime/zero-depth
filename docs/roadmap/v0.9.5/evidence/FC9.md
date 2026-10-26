# FC9: the Wisps accept the Gun's cards (v0.9.5 Step FC9, FORM_COMBOS.md P1-P6)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc9` (cut from `claude/v095-feedback` at 39d7a110, which
  holds FC4, FC5, FC6 and FC8); the SHA is in the step report. Godot 4.7.2 stable; Windows 11 Pro, owner PC, several
  Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/wisp_mods.gd` (pure; `WispMods.DEFAULTS` = the data row, 10 keys). Five cards are the wisps' own;
  `WandCompile.run` notes their ids in `modifier_ids` and skips their generic ops. The other eight compile onto the
  Wisps spec as on the Orbs and ride each wisp's shot (a wisp's shot launches that very spec).
  - P1 Twin: a fourth wisp (`WispMods.count`; the wisps stay evenly spaced).
  - P2 Halo: 6 wisps, each shot at 60 % (half-up rounding, at least 1). Halo with Twin: 7 wisps at 60 %.
  - P3 Ring: a wisp's shot that hits rings at its hit point: the enemies within 1 m (area stat on the radius, plus their
    bodies) other than the one struck take the shot's damage, each once per ring. Drawn with the Void's/Glaive's
    lightning ring (`WorldReader.wisp_rings()`, grown over `ring_ms` = 300 ms like the Void's).
  - P4 Pierce, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Spiral: not handled in `WispMods`; they compile onto
    the spec and act on a wisp's shot through the orbs' own per-card code (pierce, bounces, homing, spiral, radius,
    damage, the Split hook). **The one generalisation:** Echo. `Attacks.launch` only queued the repeat for a shot that
    was not a repeat, and a wisp's shot is marked a repeat (so no Ascension charge or Backfire). A new
    `AttackContext.wisp` flag (set in `Wisps._fire`) opens Echo's repeat to it; the queued ghost is an ordinary
    repeat (no `wisp` flag), so it does not echo again.
  - P5 Mine: each wisp drops a mine every 120 ticks (staggered over the 2 s like its shots, `Wisps.wait`). The mine is the
    Mine card's own: `WandCompile._wisp_mine` runs the card's ops on a still bolt (speed 0, life 1) and so builds
    `mine_ticks` 240 and the card's zone hook; the bolt hangs on the Wisps spec as a hook with the new trigger
    `AttackSpec.Trigger.ON_WISP` (appended to the enum; no moment fires it), launched through `Attacks.run_hook` at the
    wisp shot's damage. At most 6 live wisp mines a hero: `WispMods.cull` (from `World._apply_spawns`, like the Glaive's
    and Wave's) ends the oldest first, as a mine ends (its zone fires).
  - P6 Orbit: circle radius 3.5 m (`Wisps.pos` reads `WispMods.radius_m`); each wisp hurts the enemies within 0.4 m
    of it for 50 % of a wisp shot's damage, each enemy at most once per 30 ticks per wisp (`WispMods.touch`).
  - 40-shots-a-second cap: the wisp shots spend it exactly as before (they launch through `_bolts`, root false).
    Echo's ghosts, Split's children and the mines are follow-ups outside the per-second cap, as on the orbs.
- State rows in `ModifierState` (`pm_*`; the prefix was free): `pm_ring_at/born` (the rings the view draws) and
  `pm_hit_wisp/actor/until` (Orbit's gaps). Hashed only while set; listed in `WispMods.SNAPSHOT_FIELDS` (one `if`
  beside RuneMods'/WaveMods' in `WorldSnapshot._apply_object`; an older save loads with none). The mine bound needs no
  rows (it counts live mine projectiles by spec key); the drop clock is the world tick.
- Data: `data/wand/attack_slots.tres` wisps row `allowed` += Twin, Halo, Ring, Pierce, Ricochet, Homing, Echo, Big Shot,
  Rapid Fire, Split, Spiral, Mine, Orbit Rounds (the elements and Shared Bleed stay); `params` (10 keys);
  `AttackFormRow.WISP_KEYS`; one line in `attack_slots_definition.gd::_keys_of`. Backfire, Swirl and Threadline stay off.
- `Wisps`: `is_wisp_shot` is now exactly a plain repeat-marked orb of a Wisps spec (not an Echo ghost, which is secondary
  too; not a Split child or a mine, which have specs of their own); `angle()` renamed `turn()` (the arch lint forbids a
  `.angle(` call in `src/sim`); `shot_damage()` factored out of `_fire`.
- View: `WispsView` draws up to 8 wisps (was 6) at the sim's places and radius, and the lightning rings. The mines and
  Split children are ordinary projectiles drawn as the orbs'. No new art, no new strings.

## Deviations to flag (readings the spec left open)

- **Ring** reads "each enemy once per ring" as: the shot hits what it hits, and the ring adds one hit on every other
  enemy within 1 m of the hit point (the struck one is not hit twice). The ring is instant; only its drawing grows.
  A Pierce shot rings at each enemy it pierces. An Echo ghost and a Split child do not ring.
- **Rapid Fire** gives a wisp's shot its radius and damage factors, but the wisps' rhythm does not change with attack
  speed (the clock's stagger), so the card's rate bonus does nothing for them; its table gain comes from the hero's own orbs.
- **Echo's ghost** is queued by the existing `queue_repeat`, which does not carry the wisp shot's smaller size or its
  extra pierce: the ghost is a full-size orb at the Echo card's share of the wisp shot's damage.
- **Mine**: the mine is a still bolt at the wisp (0.5 m out along the wisp's heading, from the generic bolt gap), at the
  wisp shot's damage; the card's own zone then follows at the card's 120 % share. Cull ends the oldest mine "as a mine
  ends", so its zone fires. Mines spend the shot cap (they launch through `_bolts`) but the 6 live bound is tighter.
- **Orbit** touch radius is 0.4 m from the wisp's centre (plus the enemy's body); the spec did not give one. It hits
  under `Attacks.land` with the wisps' spec, so Split and the other on-hit cards act on a touch too.
- Halo's 60 % is applied to every wisp-made hit (shots, Ring, mine, Orbit); at 4 per shot the rounded share is 2, so six
  wisps at 2 equal three at 4 (see the table: Halo reads 1.00 against plain Wisps at this scale).
- `test_shot_rate_all_forms.gd` build count: **37 -> 40** (the Wisps row now allows Twin, Halo and Ring as Patterns and
  Spiral as the Secondary: 4 builds, was 1; the cap test passes on all of them). `test_wisps.gd` `WISPS_ON` gained the
  thirteen ids.

## Commands and raw results (all `--language en`, own `APPDATA` per process, project.godot untouched)

- `godot --headless --path . --editor --import --quit`: no ERROR lines (only the GUT class-cache lines).
- `gdformat` + `gdlint` on all touched `.gd`: "Success: no problems found".

| Run | Tests | Passing | Asserts |
|---|---|---|---|
| test_wisp_mods (new), test_wisps, test_attack_slots, test_shot_rate_all_forms, test_wave_wisps_view, e2e test_e2e_wisp_combos (new) | 66 | 66 | 2593 |
| tests/golden + tests/arch + tests/content (33 scripts) | 163 | 163 | 30829 |
| test_world_snapshot, test_modifier_equivalence | 18 | 18 | 6359 |

- An earlier run of the same files, before the `.angle(` rename and the build-count edit, failed exactly two things, both
  fixed: `tests/arch` (`wisp_mods.gd` called `Wisps.angle(`, forbidden in `src/sim`) and `test_shot_rate_all_forms`
  (build count 40 expected 37). No digest moved: `tests/golden` and `test_modifier_equivalence` pass unchanged.
  Goldens changed on purpose: none.
- e2e: "FC9 e2e: most wisps drawn 6; the dummy lost 76 of 5000" (the Wisps from the altar; Halo and Pierce by the dev
  panel's Grant clicks as labelled helpers; the hero only walks, the wisps shoot a dummy 4 m out on their own).
- Not run: test_five_floors, test_curse_room, the seed-loop tests, `seams.sh`, the full suite.

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

Orbs baseline: single 930, line 335, pack 330. Plain Wisps (orbs plus the wisps): 1490 / 603 / 534 (1.60 / 1.80 / 1.62 of
the orbs).

```
wisps + (plain)          1.602 | 1.800 | 1.618 | 1490 |  603 |  534
wisps + gun_twin         1.804 | 2.134 | 1.812 | 1678 |  715 |  598
wisps + halo_shot        1.602 | 1.830 | 1.612 | 1490 |  613 |  532
wisps + gun_ring         1.602 | 2.003 | 2.248 | 1490 |  671 |  742
wisps + gun_pierce       1.602 | 5.869 | 1.618 | 1490 | 1966 |  534
wisps + gun_ricochet     1.602 | 1.800 | 1.618 | 1490 |  603 |  534
wisps + gun_homing       1.602 | 2.099 | 1.836 | 1490 |  703 |  606
wisps + gun_echo         2.503 | 2.693 | 2.521 | 2328 |  902 |  832
wisps + gun_big_shot     2.863 | 3.445 | 2.909 | 2663 | 1154 |  960
wisps + gun_rapid_fire   1.897 | 2.015 | 1.918 | 1764 |  675 |  633
wisps + split_shot       1.602 | 1.884 | 1.642 | 1490 |  631 |  542
wisps + gun_spiral       1.733 | 1.884 | 2.006 | 1612 |  631 |  662
wisps + gun_mine         1.602 | 1.848 | 1.618 | 1490 |  619 |  534
wisps + orbit_rounds     1.671 | 1.752 | 2.164 | 1554 |  587 |  714
```
(columns: x the orbs single | line | pack, then damage single | line | pack.)

Against the plain Wisps (single / line / pack), computed from the damage columns:

| Card | single | line | pack |
|---|---|---|---|
| Twin | 1.13 | 1.19 | 1.12 |
| Halo | 1.00 | 1.02 | 1.00 |
| Ring | 1.00 | 1.11 | 1.39 |
| Pierce | 1.00 | 3.26 | 1.00 |
| Ricochet | 1.00 | 1.00 | 1.00 |
| Homing | 1.00 | 1.17 | 1.14 |
| Echo | 1.56 | 1.50 | 1.56 |
| Big Shot | 1.79 | 1.91 | 1.80 |
| Rapid Fire | 1.18 | 1.12 | 1.19 |
| Split | 1.00 | 1.05 | 1.02 |
| Spiral | 1.08 | 1.05 | 1.24 |
| Mine | 1.00 | 1.03 | 1.00 |
| Orbit | 1.04 | 0.97 | 1.34 |

**No single exceeds x2.0 and no pack exceeds x6.0 against the plain Wisps** (the largest single is Big Shot at 1.79, the
largest pack Big Shot at 1.80). Pierce reads 3.26 on the line (no line limit was set).
The sheet's scene cannot show Ricochet (no wall) or Homing's bend.

## Not done / OWNER ONLY

- Feel and look of seven wisps, the 3.5 m circle, the rings at the hit points, the mines hanging by the wisps and Echo's
  full-size ghost on the owner's hardware: OWNER ONLY.
- Cards' en/es descriptions still read their generic text; no strings added.
