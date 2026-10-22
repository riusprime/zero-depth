# v0.9.0 AF1: the Lance and Scatter forms (evidence)

Owner rows: Q7 ("F5 Lance, F6 Scatter, F7 Glaive"; "Lance replaces the Charge card … retired through `migration.tres`")
in [`../PLAN.md`](../PLAN.md); forms F5 and F6 in [`../ATTACK_FORMS.md`](../ATTACK_FORMS.md); the pattern of
[`LASER_BOMB.md`](LASER_BOMB.md) and [`VOID.md`](VOID.md). Branch `v090-af1`, cut from `a4a7590d`; the step's commit
is the one that adds this file. Machine: the owner's PC (Windows 11, Git Bash, i7-10700K, RTX 3060), Godot 4.7.2; GUT
jobs at most two at a time, each with its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit
-gtest=<files>` (or `-gdir=<dir> -ginclude_subdirs`). Lint: `gdformat --check` + `gdlint` on every touched `.gd` (clean).

## What was built

- **Lance** (`gun_lance`; Lance / Lanza, "Hold to charge, release a piercing line." / "Mantén para cargar, suelta una
  línea perforante."): Rare, Gun only, slot Form. Its modifier makes the Gun's shot a BEAM spec with `lance` 1 that
  charges through the Charge card's rule (`GunForms.hold`, `World.mx.hold_t`, no new state): `hold_seconds` 1.2,
  `hold_permille` 5000 (+250 a level). Holding Shoot charges; a full charge **waits** for the release (the Charge card
  fired by itself at full). The release fires one line (`Lance.fire`) from the hero along the aim, 10.8 m (as far as an
  orb flies) × 0.25 m, stopped only by a wall, one full hit on every enemy it crosses (statuses and hooks per enemy);
  damage = one orb hit (5) × 1 for a tap up to × 5 at 1.2 s, linear. Then 0.4 s before the next charge (attack speed at
  half its bonus). No projectile. Twin: 2 lines (3 at Lv 5) at its share. Row: Twin + the five elements.
- **Scatter** (`gun_scatter`; Scatter / Metralla, "A cone of pellets, brutal up close." / "Un cono de perdigones,
  brutal de cerca."): Rare, Gun only, slot Form. The Gun's own bolt runner with `count` 6, `spread` 25°, every 0.55 s,
  20 m/s for 0.25 s (5 m), radius 0.12 m, `share_permille` 1000 (+50 a level), `pellets` 1 (the view's marker). The
  pellets past the centre one are secondary (statuses at the secondary proc: the "lower chance"). Row: Twin, Backfire +
  the five elements. Caps: Twin Lv 5 (18) merges to 12 an attack; 40 a second holds.
- **Charge retired**: `gun_charge` added to `data/wand/migration.tres` (gun_into `gun_lance`, blade_into "" = refunded
  as shards); Ascension's row, which led to Charge, now leads to the Lance. Charge left the Orbs row (the content
  validator refuses a retired card in a row). Its item and modifier stay so old saves resolve.
- **Views**: `LanceView` (a muzzle glow growing with the charge, pulsing once full; a dashed aim line along the sim's
  own trace while charging, solid when full; a release flash along the whole line, wider for a bigger charge, fading
  in 14 ticks, with the element's VfxLayer accent and sparks); `ScatterView` (each pellet a hot slug stretched along its
  flight; each volley a muzzle cone as wide as the spread, fading in 9 ticks). Element looks from `BeamLooks`. Pellets
  are left out of the pulses and the bolt layer; the Charge card's swelling orb is not drawn for the Lance.
- **Sound**: no new wav. `scripts/audio/generate_sfx.py` needs numpy, which this PC's Python 3.14 doesn't have, and I
  did not install it. The Scatter plays the existing `skill_scatter_blast` cue, the Lance's release `bolt_fire`.
  Placeholder sounds of their own: NOT YET MADE.
- `scripts/checks/perf_probe.gd` gained `--release=N` (Shoot let go one tick every N ticks; the Lance fires on the
  release).

## Damage (single target against the orbs, `test_lance.gd` / `test_scatter.gd`, same harness as test_void)

Raw `gut.p` lines:

```
AF1 Lance one target 4 m, full charge (72 ticks), 28 s: 425 dmg in 17 hits; orbs 930 in 186; ratio 0.457
AF1 Lance one target 4 m, half charge (36 ticks), 28 s: 420 dmg in 28 hits; orbs 930 in 186; ratio 0.452
AF1 Lance one target 4 m, tap charge (1 ticks), 28 s: 335 dmg in 67 hits; orbs 930 in 186; ratio 0.360
AF1 Lance five in a line 2-8 m, full charge, 10 s: lance 750, orbs 335, ratio 2.239
AF1 Scatter pellets landing from one volley at 1.2 / 3 / 4.5 / 6 m: { 1.2: 6, 3.0: 4, 4.5: 2, 6.0: 0 }
AF1 Scatter one target 1.5 m, 28 s: 1530 dmg in 306 hits; orbs (1.5 m) 930 in 186; ratio 1.645
AF1 Scatter one target 3.0 m, 28 s: 1020 dmg in 204 hits; orbs (1.5 m) 930 in 186; ratio 1.097
AF1 Scatter one target 4.5 m, 28 s: 510 dmg in 102 hits; orbs (1.5 m) 930 in 186; ratio 0.548
AF1 Scatter venom feeds in 10 s point blank: scatter 66 (114 pellet hits), orbs 67
AF1 Scatter + Twin Lv 5 + Backfire: most launched in any 60 ticks 24; per volley [12, 12, 12, 12, 12, 12, 12, 12]; behind 114 of 228
```

(The Lance lines were measured again after its level bonus moved onto `hold_permille`: the same four lines.)

**For the owner:** with the docs' numbers read literally (× 1 = one orb hit, × 5 at 1.2 s), the Lance's single-target
DPS is **0.46 ×** the orbs at full charge; it pays off on a line (2.24 × the orbs on five in a row). The docs give no
DPS target for it, so nothing was tuned toward one. The 0.4 s wait after a release is my starting value (below 0.3 s
tapping would beat charging). The Scatter is **1.65 ×** the orbs point blank, 1.10 × at 3 m, 0.55 × at 4.5 m, none past
5 m. Integer damage: the Scatter's +5 % a level rounds away at Lv 2 (5 per pellet), gives 6 from Lv 3.

## Tests (raw summary lines)

- Sim set (19 files: test_attack_slots, test_wand_migration, test_shot_cap, test_laser, test_void, test_bomb,
  test_modifier_smoke, test_world_snapshot, test_state_hasher, test_gun_pool, test_gun_pool_order, test_mr_modifiers,
  test_player_builds, test_rewards, test_items, test_wand_shared, test_mx4_modifiers, test_lance, test_scatter):
  `Tests 265 / Passing Tests 263 / Failing Tests 2` (test_items and test_gun_pool_order still counted Charge in the Gun
  pool; fixed), then those two files re-run: `Tests 31 / Passing Tests 31 / Asserts 576`.
- `-gdir=res://tests/content -ginclude_subdirs`: `Tests 140 / Passing Tests 140 / Asserts 10421`.
- test_layering, test_sim_purity, test_old_saves, test_gun_looks, test_laser_view, test_void_view, test_bomb_view,
  test_lance_view, test_scatter_view: `Tests 36 / Passing Tests 36 / Asserts 13927`.
- e2e `test_e2e_lance_scatter.gd` + `test_e2e_gun_pool.gd` (moved from Charge to Twin + the Lance):
  `AF1 e2e Lance: charge 1.00 when let go; damage to the row at 3 / 5 / 7 m [25, 25, 25]`,
  `AF1 e2e Scatter: near (2 m) took 120, far (7 m) took 0; most pellets drawn 6, cones 1`; gun_pool re-run after the
  level change: `Tests 1 / Passing Tests 1 / Asserts 11`.
- `test_e2e_old_save.gd`: `Tests 1 / Passing Tests 1 / Asserts 12`.
- After moving the Lance's level bonus: test_lance, test_wand_migration, test_lance_view, test_modifier_validation,
  test_item_validation re-run: `Tests 46 / Passing Tests 46 / Asserts 3689`.

E2e note: `E2e.mouse_button` sends a button event with no position, which the game reads as the cursor at the
top-left corner; the Lance e2e lets go with the cursor's position set (a real release carries it).

## Shots

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/lance_scatter.gd` (RTX 3060) →
`build/shots/v0.8.0/af1/`, copied by hand to [`af1_shots/`](af1_shots/):

```
lance_scatter: res://build/shots/v0.8.0/af1/1_lance_charged.jpg (tick 80, lance aims 1 charge 1.0 flashes 0, pellets 0 cones 0)
lance_scatter: res://build/shots/v0.8.0/af1/2_lance_release.jpg (tick 82, lance aims 0 charge 0.0 flashes 1, pellets 0 cones 0)
lance_scatter: res://build/shots/v0.8.0/af1/3_scatter_cone.jpg (tick 4, lance aims 0 charge 0.0 flashes 0, pellets 6 cones 1)
```

## Perf (one horde probe per form, headless: CPU side only)

`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde=60 --cards=gun_lance,gun_twin
--level=5 --seconds=10 --release=97` and `... --cards=gun_scatter,gun_twin --level=5 --seconds=10` (avg / p95 / max):

```
== lance
sim_ms            2.598     4.450     6.954
sync_ms           4.762     6.530    17.980
total_ms          9.964    12.455    27.467
projectiles       0.000     0.000     0.000
verdict: avg 9.96 ms per tick+frame against 12.0 ms -> within
== scatter
sim_ms            2.834     5.126     7.463
sync_ms           4.901     6.943    15.163
total_ms         10.535    14.559    23.056
projectiles       1.292    12.000    12.000
verdict: avg 10.54 ms per tick+frame against 12.0 ms -> within
```

Both within the 12 ms average; the p95 (12.5, 14.6) and the worst ticks are over it, one run each. GPU frame time:
NOT YET RUN (owner hardware).

## Goldens

None changed (no golden file touched; the new spec fields hash only when not 0).

## Not run here

The full suite (GitHub runs it); the seams (the lead's).

---

# v0.9.0 AF1b: the Lance becomes a charged energy ball (evidence)

Owner row AF1b in [`../PLAN.md`](../PLAN.md) "Owner decisions" ("could the charge attack be the same as the original
ball but it creates a circle in front of the player … moves the player back like a cadence weapon … like a lowkey
haduoken"; "Pierces all", "A small step", "Grows with charge"), with the AF1 row (a full charge about 1.0× the orbs on
one target). Branch `v090-af1b`, cut from `d4dd1e91`; the step's commit is the one that adds this section. Machine: the
owner's PC (Windows 11, Git Bash, i7-10700K, RTX 3060), Godot 4.7.2; one Godot process at a time, own `APPDATA`.

## What changed

- **The ball** (`data/modifiers/gun_lance.tres`): the BEAM form, `reach_m` and `radius_m` ops are gone, so the Lance is
  the Gun's own bolt (the orb's speed, life and look); `pierce` 999 (`Lance.PIERCE_ALL`: every enemy once, a wall
  ends it); `hold_permille` 5000 → **11600** (+580 a level, 5 % of the full charge). The release (`PlayerKit._fire_bolt`)
  sizes the ball × 1 on a tap → × 2 at full (`Lance.size_permille`; the hit radius is the projectile's radius). Twin:
  the bolt runner's lanes (2 side by side, 3 fanned at Lv 5) at its share. Caps: ShotCap as for any shot.
- **The recoil** (`Lance.on_release`, `Lance.recoil`): 0.5 m × the charge fraction against the aim over 6 ticks, added
  to the walk in `World._move_and_collide` so walls resolve it. New state `World.mx.recoil_t`, `recoil_step`
  (WorldSnapshot STATE_CLASSES; hashed only while it runs).
- **The look** (`LanceView`): the dashed aim line and muzzle glow are replaced by a swirling circle in front of the hero
  where the sim's ball sits (`WorldReader.lance_orb`): arcs turning both ways and motes spiralling inward in the
  element's colours, growing with the ball, brighter and faster with the charge, pulsing full. A release is a ring
  burst at the muzzle with sparks and a light, and a camera kick back along the aim (0.12 m at full, `IsoRig.kick`;
  none with shake off). The ball in flight is the orb's bolt look scaled by its radius (× 2 at full).
- **Sound** (placeholders, `scripts/audio/generate_sfx.py`): `lance_charge` (1.37 s rising hum, played once a charge
  passes 10 %) and `lance_release` (0.52 s whoosh, zap and thump, on the LANCE event); the ball's spawn no longer plays
  `bolt_fire`. Rendered with the numpy venv into a scratch copy; only the two wavs and their manifest rows taken
  (the scratch render's other rows differ by the numpy version and were not taken); credits rebuilt (106 files).
- **Card text**: "Hold to charge, release a piercing energy ball." / "Mantén para cargar, suelta una bola de energía
  perforante." (`.translation` files re-imported).

## Damage, size, recoil (`test_lance.gd`, raw `gut.p` lines)

```
    AF1b Lance ball radius: tap 0.203, half 0.300, full 0.400 (orb 0.200)
    AF1b Lance recoil (aim +x, from 0,0): tap 0.0069 m, half 0.2500 m, full 0.5000 m
    AF1b Lance recoil against a wall 0.5 m behind: hero x -0.1500 (radius 0.35)
    AF1b Lance one target 4 m, full charge (72 ticks), 28 s: 928 dmg in 16 hits; orbs 930 in 186; ratio 0.998
    AF1b Lance one target 4 m, half charge (36 ticks), 28 s: 837 dmg in 27 hits; orbs 930 in 186; ratio 0.900
    AF1b Lance one target 4 m, tap charge (1 ticks), 28 s: 335 dmg in 67 hits; orbs 930 in 186; ratio 0.360
    AF1b Lance five in a line 2-8 m, full charge, 10 s: lance 1740, orbs 335, ratio 5.194
```

Full 0.998× (asserted 0.9–1.1), full > half > tap; five in a line 5.19×. A first run at 11000 measured full 0.946× (55
a hit); 11600 (58 a hit) is the value kept.

## Tests (raw summary lines)

`bash af1b_gt.sh <job> -gtest=<files>` = `APPDATA=<own> godot --headless --fixed-fps 60 --path . -s
addons/gut/gut_cmdln.gd -gexit -gtest=<files>`. Lint: `gdformat --check src scripts tests` → "1172 files would be left
unchanged"; `gdlint src scripts tests` → "Success: no problems found".

test_lance, test_lance_view, test_attack_slots, test_wand_migration, test_shot_cap, test_scatter, test_scatter_view,
test_modifier_smoke, test_modifier_smoke_mx4, test_old_saves, test_world_snapshot, test_state_hasher, test_layering,
test_sim_purity, test_audio_director:
```
Tests               131
Passing Tests       131
Asserts           67892
Time              1332.902s
```
`-gdir=res://tests/content -ginclude_subdirs`:
```
Tests               140
Passing Tests       140
Asserts           10452
Time              41.052s
```
test_e2e_lance_scatter, test_e2e_gun_pool, test_e2e_old_save (re-run after the circle's final look):
```
    AF1b e2e Lance: charge 1.00 when let go; circle 1.64 m; damage to the row at 3 / 5 / 7 m [58, 58, 58]; pushed back 0.500 m
Tests                 4
Passing Tests         4
Asserts              54
Time              34.715s
```
test_lance_view after the circle's final look: `Tests 5, Passing Tests 5, Asserts 20`.

## Shots

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/lance_scatter.gd` (RTX 3060) →
`build/shots/v0.8.0/af1/`, the two Lance shots copied by hand to [`af1b_shots/`](af1b_shots/):

```
lance_scatter: res://build/shots/v0.8.0/af1/1_lance_charged.jpg (tick 80, lance circle true size 1.64 charge 1.0 bursts 0 ball r 0.0 hero x 0.0, pellets 0 cones 0)
lance_scatter: res://build/shots/v0.8.0/af1/2_lance_ball.jpg (tick 85, lance circle false size 1.64 charge 0.0 bursts 1 ball r 0.4 hero x -0.42, pellets 0 cones 0)
```

## Perf (one horde probe, headless: CPU side only)

`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde=60 --cards=gun_lance,gun_twin
--level=5 --seconds=10 --release=97` (avg / p95 / max):

```
sim_ms            2.208     3.770     5.921
sync_ms           3.859     5.360     9.146
frame_ms          2.145     2.670     4.603
total_ms          8.212    10.757    15.988
projectiles       1.282     3.000     3.000
verdict: avg 8.21 ms per tick+frame against 12.0 ms -> within
```

One run. GPU frame time: NOT YET RUN (owner hardware).

## Goldens

None changed (no golden file touched; the recoil hashes only while it runs).

## Not run here

The full suite (GitHub runs it); the seams (the lead's). Owner feel of the circle, the push back and the sounds: OWNER
ONLY.
