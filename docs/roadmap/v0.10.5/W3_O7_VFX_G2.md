# v0.10.5 W3-O7 — G2: the purple enemy bolt and the Lance ball (F6, F16)

Owner, 2026-11-04: "Purple enemy bolts: the recently changed projectiles feel visually underwhelming compared with
fireballs." "Lance: projectile animation looks like a generic ball and feels worse than the available VFX pack
alternatives." The fireballs (F4: kept, the reference) are the bar.

**Decision: Lance: B, the element javelin (owner, 2026-11-04: first A, then "lance should not be fireball it should be option B").** **Bolt: A, the violet fireball** (owner, 2026-11-04, after round 2).

**Status: G2, waiting on the owner's pick. Today's looks stay the default.** Nothing below changes the game until the
lead sets the pick.

## Which bolts are "purple"

The Twin Wardens' Crossfire (floor 4): one twin fires `warden_amber_ember`, drawn since v0.10.0 VX4 by the pack's
`fire_ball_04` (a fireball), the other `warden_violet_ember` (`data/bosses/twin_wardens.tres` `twin_look`), drawn by
VX4 with the pack's `mprojectile_basic_vfx_03`: a small violet puff with a stub of a trail. In the same volley the
violet shots sit beside real fireballs, which is the comparison the owner made (`bolt_now.png`). VX4 (2026-10-31) is
the "recent change". Two other violet looks exist, both bosses' and not in this G2: the Nemesis's `nemesis_bolt`
(pack javelin) and the Lantern Shade's `shade_wisp` (pack flare orb). The picked look can be given to them later with
one row each in `CandidateLooks.BOLT_LOOKS`.

## How to pick

`src/presentation/world_view/candidate_looks.gd`: `const BOLT := &""` and `const LANCE := &""` (today's). Set one to
`&"a"`, `&"b"` or `&"c"`. FireballViews, FireballPack's prefill and HeroPulseViews read it (one hook line each). Every
candidate is a row of `data/vfx/pack_fx_w3o7.tres`, so the session warm-up (PackFxSessionWarm, PackFx.warm_ids) and
a floor's pending warm-up compile it with the other pack effects; a picked bolt also gets FireballPack's prefilled
pool (no first-volley instancing).

## Shots

`build/shots/v0.10.5/w3o7/` (not tracked), from the game camera in the real game view (Ruins, Effects High):

- `bolt_now.png`, `bolt_a.png`, `bolt_b.png`, `bolt_c.png`: three violet embers in flight beside two amber
  fireballs (the reference), the Crossfire's size (0.2 m).
- `lance_now.png`, `lance_a.png`, `lance_b.png`, `lance_c.png`: the plain Lance (the data's Gun + `gun_lance`) at full
  charge (left half), then its ball 12 ticks after the release (right half). The charge circle is the same in all four
  (only the ball changes).

```
godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/w3o7_shots.gd
```
Run once at `34bdd4f4` on the owner's PC; it printed the eight paths above.

## The purple bolt

**Now.** The pack's `mprojectile_basic_vfx_03` (Magic Projectiles), recoloured to the look's lilac and violet: 3 meshes,
no particles. Small and dim next to the amber fireball.

**A — a violet fireball. ← recommended.** The fire pack's `fire_ball_04` (the amber twin's own scene) rebuilt as
`assets/vfx_zd/tinted_fire/tinted_fire_ball.tscn` with three shaders adapted from the pack's (`flame_01`,
`fire_ball_03`, the sparks' material) so its red and yellow come from PackFx's colours: a molten violet ball, a long
violet flame trail, violet sparks. The two twins' volleys then read as one family in two colours, and it is the look the
owner already likes. Cost: the same as each amber shot today (2 particle emitters, 52 particles, 1 sphere that casts a
shadow), against 3 meshes and no particles now; the Crossfire's volley stays within the `enemy_shot` cap (128 at High).
The flame is unshaded and unfogged so violet keeps its hue on the warm floors.

**B — the pack's violet javelin.** `mprojectile_javelin_vfx_03` (Magic Projectiles) at 0.8 (VX4's javelins draw at
0.5): a pale lilac comet with a bright head and a long streak. No particles (3 meshes, as now). Sharper and faster
looking, but thinner than the fireball beside it.

**C — the pack's flare orb.** `magic_orb_flare_vfx_03` (Magic Orbs) with its star "Flare" left out (it ignores the
node's scale): a violet core inside a spiky crackling ring. No particles (2 meshes drawn). Reads as arcane, the
clearest apart from the fireballs, but it has no trail, so its direction reads less well in a dense volley.

## The Lance ball

**Now.** The pack's big orb of the element (`vx2_big_<element>`, Magic Orbs `magic_orb_big`): a large bright sphere in
a wide flame-like aura. This is the "generic ball".

**A — a plasma fireball in the element's colours. ← recommended.** The same recoloured `fire_ball_04`
(`w3o7_lance_a`), 2.6 × the ball's radius, its flame and rim the element's deep tone, its light the element's hot
centre: for the plain Lance a blue molten ball with a blue flame trail behind it, which shows the direction and the
speed the big orb doesn't. One ball at a time, so the cost (52 particles, 1 sphere) does not matter.

**B — the pack's javelin of the element.** `vx2_jav_<element>` (already in the VX2 table; no new row), 5 × the radius:
a long glowing lance-shaped streak. It fits the name, no particles; it reads as a beam more than a charged ball, so the
charge's growth shows less.

**C — the pack's flare orb with its star flare.** `magic_orb_flare_vfx_02` (`w3o7_lance_c`), 1.8 × the radius: a
crackling ring round a white core, the flare kept (one at a time, so its fixed size is no clutter). Closest to "a
charged energy ball", but it has no trail, like today's.

## Assets and provenance

All candidates use the owner's Binbun VFX packs already installed under `assets/BinbunVFX/` (Fire, Magic Orbs,
Magic Projectiles; licence in `assets/BinbunVFX/manifest.json`). The `newVFX/` zips for these packs
(`GodotMagicOrbsVFX.zip`, `FireVFX.zip`, `GreenExtra.zip`) list the same scene names as the installed packs
(`unzip -l`, names only, contents not compared), so no zip was extracted and no new vendor file was copied.
New in the project, our own in the pack's style (as VX6-VX8's `assets/vfx_zd/`):
`assets/vfx_zd/tinted_fire/` — `tinted_fire_ball.tscn` (fire_ball_04's structure, its noise textures and
`sparks.tscn` referenced from the pack, not copied), `tinted_flame.gdshader` (from `flame_01`), `tinted_ball.gdshader`
(from `fire_ball_03`), `tinted_sparks.gdshader` (the sparks' emissive trail), `tinted_fire.gd` (takes PackFx's three
colours, as the pack's `VFXController` does).

## Tests (owner PC, Windows, `34bdd4f4`'s tree)

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<13 presentation files> -gexit
```
Files: test_w3o7_candidates (new), test_vx4_shots, test_pack_fx, test_pack_fx_session_warm, test_first_use_warm,
test_shader_warmup, test_lance_view, test_vx_looks, test_vx2_forms, test_gun_pulse, test_enemy_fireball_views,
test_ember_stone, test_vx7_gaps.
```
Scripts              13
Tests               133
Passing Tests       133
Asserts           18301
```
(Then test_w3o7_candidates' one orphan was fixed and the file re-run alone: `Tests 6, Passing Tests 6, Asserts 108`,
no orphans.)

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch -ginclude_subdirs -gexit
Scripts 2, Tests 4, Passing Tests 4, Asserts 19382
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Scripts 31, Tests 166, Passing Tests 166, Asserts 12805
```
Lint: `gdformat --check` and `gdlint` clean on the six touched scripts.

Feel in motion, and whether A beats the javelin in a real Crossfire: OWNER ONLY. Frame time with a full violet
Crossfire on candidate A: NOT YET RUN.

## Round 2 (W3-O7b): the owner's new packs

Owner, 2026-11-04: "before choosing i'd like to see comparisons with new assets from the premade pack … that I added."
Same switch (`CandidateLooks.BOLT := &"d"` … `&"g"`), same table (`data/vfx/pack_fx_w3o7.tres`, four `enemy_shot` rows,
so the session warm-up and the floor's prefill take them as round 1's). The default stays today's look.

**What the `newVFX/` zips hold.** Every zip was listed (`unzip -l`); the eleven attack and pickup packs were extracted,
each into its own folder outside the repo, and compared file by file with `assets/BinbunVFX/`. The packs already
installed in VX0 (Fire, Beam, Ice, Magic Orbs, GreenExtra = Magic Projectiles, Impact, Magic Area, Muzzle Flash,
Poison, Smoke) have **the same effect scenes byte for byte**; the only differences are the shared shaders (VX0 inlined
their `#include`s), Godot re-save order in shared noise/gradient `.tres` files, and each pack's demo scene (not
installed). So there is no newer version of any installed effect. The zips not installed are not projectiles: Loot
(floating and ground pickup glows), Portal, Hologram, Card, Glass UI, Grass, Skies, Transitions, UltimateToon (toon
surface materials) and magic-circles (floor circles). Round 2 therefore draws on the owner's installed packs' effects
that were never tried for the bolt (Ice, Poison, the Magic Projectiles wave). No vendor file was copied and the asset
manifest is unchanged.

**Shots.** `build/shots/v0.10.5/w3o7b/` (not tracked): `bolt_now.png`, `bolt_a.png` … `bolt_g.png` (re-rendered with
round 1's framing: three violet embers beside two amber fireballs, Ruins, Effects High), `round1/` (round 1's four
files copied for side by side), and **`bolt_compare.png`**: every candidate's middle, labelled, in one grid.

```
godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/w3o7_shots.gd -- --round2
```
Run at `a7fdcbeb` + this step's changes on the owner's PC; it printed the nine paths above.

**D — the Ice pack's shard, in violet. ← recommended of round 2.** `ice_shard_vfx_02` (GodotIceVFX) at 0.4: an
amethyst crystal head with a long violet mist trail. Cost: 1 mesh, 2 particle emitters (24 + 32 = 56 particles), about
A's. The trail is as long as the fireball's, so the volley reads as one family of two kinds (flame, crystal) and the
direction is clear; the head is a sharp shape the round-1 looks don't have.

**E — the Ice pack's ball, in violet.** `ice_ball_vfx_01` (GodotIceVFX) at 0.35: a pale glassy violet orb with a wide
mist plume. Cost: 2 meshes, 1 emitter (32 particles). The plume is much wider and softer than the fireball's flame:
in a dense Crossfire it would smear into a violet haze.

**F — the Magic Projectiles wave.** `mprojectile_wave_vfx_03` (GreenExtra) at 0.5: a lilac head with short curled
wave ribbons behind. Cost: 4 meshes, no particles. Close to today's look in size and brightness; it does not answer
"underwhelming".

**G — the Poison pack's bubble, in violet.** `poison_bubble_vfx_01` (PoisonVFX) at 0.4, its Pop and Splats left out:
a dark wobbling violet bubble, no trail. Cost: 1 mesh drawn, no particles. Dim against the warm floor and no direction;
not recommended.

Overall, A (the violet fireball) stays the round-1 recommendation; D is the strongest new option if the owner wants
the violet twin to read as a different element from the amber one.

Tests (owner PC, Windows, `a7fdcbeb` + this step):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<round 1's 13 presentation files> -gexit
Scripts 13, Tests 133, Passing Tests 133, Asserts 18326, Orphans 6
```
(The 6 orphans are `BarChunks` nodes, 2 each in three files (test_shader_warmup, test_enemy_fireball_views and one more), code
this step does not touch; test_w3o7_candidates alone: `Tests 6, Passing Tests 6, Asserts 128`, no orphans.)
```
godot ... -gdir=res://tests/arch -ginclude_subdirs -gexit      Scripts 2, Tests 4, Passing Tests 4, Asserts 19395
godot ... -gdir=res://tests/content -ginclude_subdirs -gexit   Scripts 31, Tests 166, Passing Tests 166, Asserts 12813
```
Lint: `gdformat --check` and `gdlint` clean on candidate_looks.gd and w3o7_shots.gd.
Feel in motion: OWNER ONLY. Frame time with a full Crossfire on D: NOT YET RUN.
