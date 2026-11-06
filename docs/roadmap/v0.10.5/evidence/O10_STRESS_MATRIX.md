# v0.10.5 O10 evidence: the stress matrix

- **Build:** branch `v0105-o10`, measured on the working tree over `67cc462f` (the matrix docs commit), with the
  O10 code uncommitted. The code commit follows this file.
- **Machine:** the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2, headless. No timing is claimed.
- **Matrix and rule:** [`../O10_STRESS_MATRIX.md`](../O10_STRESS_MATRIX.md).

## Time to kill, before and after

Command (the script writes `build/matchup_ttk.txt`, pasted below by hand):

```
APPDATA=$(mktemp -d) godot --headless --path . -s scripts/checks/matchup_ttk.gd -- seconds=20 hp=400
```

Each cell is the time to kill a 400-HP copy of the kind, in seconds ("-": not dead in 20 s), with the damage a second
on it in brackets. The hero stands still with the Gun and one card at level 1 (bolt: no card). "Before" clears every
kind's `weak_to` and `resists` on that world. Raw output:

```
matchup_ttk: 14 kinds x 8 forms, 20 s a fight, target HP 400, 60 Hz headless
determinism: MATCH

== before (matchups off): time to kill s (dps on the target) ==
kind | weak / resists | bolt | gun_laser | gun_lance | gun_wave | gun_glaive | ember_core | storm_core | venom_core
charger | gun_lance / venom | 11.88 (33.7) | 10.52 (38.0) | 12.02 (33.3) | 10.83 (36.9) | 10.52 (38.0) | 8.13 (49.2) | 11.88 (33.7) | 6.68 (59.9)
warden | venom / storm | 16.27 (24.6) | 13.02 (30.7) | 14.02 (28.5) | 12.63 (31.7) | 18.17 (22.0) | 9.17 (43.6) | 16.27 (24.6) | 7.67 (52.2)
needle | gun_glaive / gun_wave | - (13.3) | 10.52 (38.0) | - (15.4) | 11.48 (34.8) | - (13.2) | 11.67 (34.3) | - (13.3) | 8.70 (46.0)
hatchling | ember / gun_lance | 11.88 (33.7) | 10.52 (38.0) | 12.02 (33.3) | 10.83 (36.9) | 8.43 (47.4) | 8.13 (49.2) | 11.88 (33.7) | 6.68 (59.9)
arc_caster | gun_lance / storm | - (16.8) | 10.52 (38.0) | 17.47 (22.9) | 11.62 (34.4) | - (11.4) | 11.20 (35.7) | - (16.8) | 8.70 (46.0)
bomb_drone | ember / venom | 12.13 (33.0) | 10.52 (38.0) | 13.42 (29.8) | 11.45 (34.9) | - (15.5) | 8.20 (48.8) | 12.13 (33.0) | 7.02 (57.0)
swarmer | gun_wave / gun_laser | 11.88 (33.7) | 10.52 (38.0) | 12.02 (33.3) | 10.83 (36.9) | 12.32 (32.5) | 7.98 (50.1) | 11.88 (33.7) | 6.68 (59.9)
splitter | venom / gun_glaive | 11.88 (33.7) | 10.52 (38.0) | 12.02 (33.3) | 10.83 (36.9) | 17.47 (22.9) | 8.13 (49.2) | 11.88 (33.7) | 6.67 (60.0)
splitling | gun_wave / gun_lance | 11.88 (33.7) | 10.52 (38.0) | 12.02 (33.3) | 10.83 (36.9) | 9.45 (42.3) | 8.13 (49.2) | 11.88 (33.7) | 6.68 (59.9)
shield_bearer | gun_laser / gun_glaive | - (0.0) | - (0.0) | - (0.0) | - (0.0) | - (10.7) | - (0.0) | - (0.0) | - (0.0)
mender | storm / ember | - (1.1) | 10.52 (38.0) | - (9.3) | 11.63 (34.4) | - (1.4) | - (3.9) | - (1.1) | - (4.7)
mine_layer | gun_glaive / ember | 12.12 (33.0) | 10.52 (38.0) | 12.33 (32.4) | 11.45 (34.9) | - (12.9) | 8.20 (48.8) | 12.12 (33.0) | 7.02 (57.0)
sniper | gun_laser / gun_wave | - (11.4) | - (15.9) | - (9.8) | - (12.6) | - (2.4) | 13.12 (30.5) | - (11.4) | 9.70 (41.2)
lens_drone | storm / gun_laser | - (19.3) | 10.52 (38.0) | 12.35 (32.4) | 11.47 (34.9) | - (15.1) | 8.20 (48.8) | - (19.3) | 7.03 (56.9)

== after (matchups on): time to kill s (dps on the target) ==
kind | weak / resists | bolt | gun_laser | gun_lance | gun_wave | gun_glaive | ember_core | storm_core | venom_core
charger | gun_lance / venom | 11.88 (33.7) | 10.52 (38.0) | 9.02 (44.4) | 10.83 (36.9) | 10.52 (38.0) | 8.13 (49.2) | 11.88 (33.7) | 9.68 (41.3)
warden | venom / storm | 16.27 (24.6) | 13.02 (30.7) | 14.02 (28.5) | 12.63 (31.7) | 18.17 (22.0) | 9.17 (43.6) | - (18.6) | 6.17 (64.9)
needle | gun_glaive / gun_wave | - (13.3) | 10.52 (38.0) | - (15.4) | 14.17 (28.2) | - (16.4) | 11.67 (34.3) | - (13.3) | 8.70 (46.0)
hatchling | ember / gun_lance | 11.88 (33.7) | 10.52 (38.0) | 16.02 (25.0) | 10.83 (36.9) | 8.43 (47.4) | 6.68 (59.9) | 11.88 (33.7) | 6.68 (59.9)
arc_caster | gun_lance / storm | - (16.8) | 10.52 (38.0) | 14.47 (27.6) | 11.62 (34.4) | - (11.4) | 11.20 (35.7) | - (10.4) | 8.70 (46.0)
bomb_drone | ember / venom | 12.13 (33.0) | 10.52 (38.0) | 13.42 (29.8) | 11.45 (34.9) | - (15.5) | 6.87 (58.3) | 12.13 (33.0) | 9.87 (40.5)
swarmer | gun_wave / gun_laser | 11.88 (33.7) | 13.62 (29.4) | 12.02 (33.3) | 8.13 (49.2) | 12.32 (32.5) | 7.98 (50.1) | 11.88 (33.7) | 6.68 (59.9)
splitter | venom / gun_glaive | 11.88 (33.7) | 10.52 (38.0) | 12.02 (33.3) | 10.83 (36.9) | - (16.7) | 8.13 (49.2) | 11.88 (33.7) | 5.67 (70.6)
splitling | gun_wave / gun_lance | 11.88 (33.7) | 10.52 (38.0) | 16.02 (25.0) | 8.13 (49.2) | 9.45 (42.3) | 8.13 (49.2) | 11.88 (33.7) | 6.68 (59.9)
shield_bearer | gun_laser / gun_glaive | - (0.0) | - (0.0) | - (0.0) | - (0.0) | - (7.9) | - (0.0) | - (0.0) | - (0.0)
mender | storm / ember | - (1.1) | 10.52 (38.0) | - (9.3) | 11.63 (34.4) | - (1.4) | - (2.8) | - (1.4) | - (4.7)
mine_layer | gun_glaive / ember | 12.12 (33.0) | 10.52 (38.0) | 12.33 (32.4) | 11.45 (34.9) | - (16.0) | 12.12 (33.0) | 12.12 (33.0) | 7.02 (57.0)
sniper | gun_laser / gun_wave | - (11.4) | - (19.4) | - (9.8) | - (9.3) | - (2.4) | 13.12 (30.5) | - (11.4) | 9.70 (41.2)
lens_drone | storm / gun_laser | - (19.3) | 13.62 (29.4) | 12.35 (32.4) | 11.47 (34.9) | - (15.1) | 8.20 (48.8) | 14.08 (28.4) | 7.03 (56.9)

== before: best and worst form per kind (by dps on the target) ==
charger: best venom_core (59.9), worst gun_lance (33.3)
warden: best venom_core (52.2), worst gun_glaive (22.0)
needle: best venom_core (46.0), worst gun_glaive (13.2)
hatchling: best venom_core (59.9), worst gun_lance (33.3)
arc_caster: best venom_core (46.0), worst gun_glaive (11.4)
bomb_drone: best venom_core (57.0), worst gun_glaive (15.5)
swarmer: best venom_core (59.9), worst gun_glaive (32.5)
splitter: best venom_core (60.0), worst gun_glaive (22.9)
splitling: best venom_core (59.9), worst gun_lance (33.3)
shield_bearer: best gun_glaive (10.7), worst bolt (0.0)
mender: best gun_laser (38.0), worst bolt (1.1)
mine_layer: best venom_core (57.0), worst gun_glaive (12.9)
sniper: best venom_core (41.2), worst gun_glaive (2.4)
lens_drone: best venom_core (56.9), worst gun_glaive (15.1)
form | best on | worst on (of 14 kinds)
bolt | 0 | 2
gun_laser | 1 | 0
gun_lance | 0 | 3
gun_wave | 0 | 0
gun_glaive | 1 | 9
ember_core | 0 | 0
storm_core | 0 | 0
venom_core | 12 | 0
before: a form best on every kind: none; a form worst on every kind: none

== after: best and worst form per kind (by dps on the target) ==
charger: best ember_core (49.2), worst bolt (33.7)
warden: best venom_core (64.9), worst storm_core (18.6)
needle: best venom_core (46.0), worst bolt (13.3)
hatchling: best ember_core (59.9), worst gun_lance (25.0)
arc_caster: best venom_core (46.0), worst storm_core (10.4)
bomb_drone: best ember_core (58.3), worst gun_glaive (15.5)
swarmer: best venom_core (59.9), worst gun_laser (29.4)
splitter: best venom_core (70.6), worst gun_glaive (16.7)
splitling: best venom_core (59.9), worst gun_lance (25.0)
shield_bearer: best gun_glaive (7.9), worst bolt (0.0)
mender: best gun_laser (38.0), worst bolt (1.1)
mine_layer: best venom_core (57.0), worst gun_glaive (16.0)
sniper: best venom_core (41.2), worst gun_glaive (2.4)
lens_drone: best venom_core (56.9), worst gun_glaive (15.1)
form | best on | worst on (of 14 kinds)
bolt | 0 | 4
gun_laser | 1 | 1
gun_lance | 0 | 2
gun_wave | 0 | 0
gun_glaive | 1 | 5
ember_core | 3 | 0
storm_core | 0 | 2
venom_core | 9 | 0
after: a form best on every kind: none; a form worst on every kind: none

== after / before dps, per mille ==
kind | bolt | gun_laser | gun_lance | gun_wave | gun_glaive | ember_core | storm_core | venom_core
charger | 1000 | 1000 | 1333 | 1000 | 1000 | 1000 | 1000 | 690
warden | 1000 | 1000 | 1000 | 1000 | 1000 | 1000 | 756 | 1243
needle | 1000 | 1000 | 1000 | 811 | 1239 | 1000 | 1000 | 1000
hatchling | 1000 | 1000 | 750 | 1000 | 1000 | 1217 | 1000 | 1000
arc_caster | 1000 | 1000 | 1207 | 1000 | 1000 | 1000 | 619 | 1000
bomb_drone | 1000 | 1000 | 1000 | 1000 | 1000 | 1194 | 1000 | 711
swarmer | 1000 | 772 | 1000 | 1332 | 1000 | 1000 | 1000 | 1000
splitter | 1000 | 1000 | 1000 | 1000 | 729 | 1000 | 1000 | 1176
splitling | 1000 | 1000 | 750 | 1332 | 1000 | 1000 | 1000 | 1000
shield_bearer | - | - | - | - | 738 | - | - | -
mender | 1000 | 1000 | 1000 | 1000 | 1000 | 714 | 1217 | 1000
mine_layer | 1000 | 1000 | 1000 | 1000 | 1240 | 677 | 1000 | 1000
sniper | 1000 | 1223 | 1000 | 737 | 1000 | 1000 | 1000 | 1000
lens_drone | 1000 | 772 | 1000 | 1000 | 1000 | 1000 | 1472 | 1000
```

## Reading it

- **The matchups do what they say.** In the after/before table, every weak pair is above 1000 and every resisted
  pair is below 1000. Every other cell with damage is exactly 1000 ("-": no damage either way).
  - Weak pairs read 1176-1472, not 1250: the kill comes earlier, or a status interacts. Lens Drone × Lightning is
    1472.
  - Resisted pairs read 619-811.
- **No form is best against every kind, and none is worst against every kind** (the script's last summary line,
  before and after).
  - Venom: best on 12 of 14 kinds before, 9 after. At level 1, in this fight, Venom Core is the strongest single card
    against most kinds. That is a card-balance finding, outside O10's scope.
  - Fire: best on 0 kinds before, 3 after (Charger, Hatchling, Bomb Drone).
  - Glaive: worst on 9 kinds before, 5 after.
  - Lance: worst on 3 kinds before, 2 after.
- **What the bot can't show.** It stands still and shoots the nearest body from the front.
  - The Shield Bearer blocks every frontal hit. Only the Glaive's return reaches it, so its Laser weakness doesn't
    show here.
  - The Mender and Sniper keep their distance, so most forms barely reach them in 20 s. Their matchups show only in
    the ratios.
  - Each fight is one enemy alone. The room mixes (packs, a Sniper behind Swarmers) are not measured.

## Tests

Lint, whole tree:

```
gdformat --check src scripts tests   ->  1548 files would be left unchanged
gdlint src scripts tests             ->  Success: no problems found
```

GUT (headless, `--fixed-fps 60`, each run with its own `APPDATA`):

| Run | Files | Result |
|---|---|---|
| `-gtest=` test_matchups, test_matchup_views | the new tests | 13/13 passed, 156 asserts |
| `-gtest=` test_enemies, test_blade_damage_taken, and the two above (before a test fix) | | 26/29; the 3 failures were a test bug: the Sniper's 30 HP capped the hits. Fixed (the test sets 1000 HP) and re-run green above |
| `-gtest=` test_damage, test_element_levels_venom_bleed, test_laser, test_laser_mods, test_world_snapshot, test_codex, test_codex_lore, test_codex_view, test_build_views, test_hit_impact, test_status_visuals, test_e2e_codex, test_e2e_damage_soak | damage, DoT, Laser, snapshot, Codex, damage numbers | 113/114. `test_e2e_damage_soak` failed `[2] expected to equal [0]: no orphan nodes` in that batch |
| `-gtest=res://tests/e2e/test_e2e_damage_soak.gd` alone | | 1/1 passed, 14 asserts. The orphans came from the tests run before it in the same process. Not investigated further |
| `-gdir=res://tests/content,res://tests/golden` | content validation, locale, codex content, the replay golden | 168/168 passed, 12450 asserts |
| `-gdir=res://tests/arch` | the sim purity lint | 4/4 passed, 18877 asserts |

**Goldens moved: none.** The replay golden (`tests/golden/test_replay_ground_plane.gd`) passed unchanged, so its fight
meets no weak or resisted pair.

## Picks for the owner

The six picks in [`../O10_STRESS_MATRIX.md`](../O10_STRESS_MATRIX.md) "Picks for the owner": the 14 rows, ×1.25 /
×0.75, only seven ids, the Ring counting as Lightning, the Shield Bearer's shield still blocking the Laser from the
front, and both-ways hits cancelling. Also from the numbers above:

7. **Venom Core at level 1 out-damages the other single cards against most kinds** (best on 9 of 14 even with the
   matchups). The rule cards step may change this; O10 doesn't retune it.
8. **OWNER ONLY:** whether the bigger red-pink weak number and the smaller grey resisted number read in play.
