# v0.9.0 VP: Void becomes a projectile form; the floor black hole goes (evidence)

Owner rows: C §6.4, §8 (verbatim in the PLAN), C54–C58, C70, Q10 "No pull on them", Q14 in [`../PLAN.md`](../PLAN.md);
form F4 in [`../ATTACK_FORMS.md`](../ATTACK_FORMS.md); the framework in [`ATTACK_SLOTS.md`](ATTACK_SLOTS.md) and the
pattern of [`LASER_BOMB.md`](LASER_BOMB.md). Branch `v090-vp`, cut from `897725f7`. Machine: the owner's PC (Windows 11,
Git Bash, i7-10700K, RTX 3060), Godot 4.7.2; GUT jobs in parallel, each with its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit
-gtest=<files>` (or `-gdir=<dir> -ginclude_subdirs`). Lint: `gdformat --check` + `gdlint` on every touched `.gd` (clean).

## What was removed

- **The floor black hole** (v0.8.0 P2, O24): `src/sim/combat/black_holes.gd`, `src/presentation/world_view/
  black_hole_views.gd` (and its wiring in `world_view_root.gd`), `WorldReader.black_holes`, the two rolls in
  `attacks.gd` (a slash's first landing, a projectile's end), `ModifierRuntime`'s advance, `ModifierState.hole_*`
  (state, hash), the snapshot's `hole_*` fields, `AttackSpec.hole_permille` / `hole_damage_permille`, the op fields
  `hole_chance_permille` / `hole_damage_permille`, the `hole_*` tuning (`wand.tres`, `WandDefinition`, `WandTable`,
  `WandCompiler`), the black-hole shots in `scripts/shots/ascension.gd`, and their tests (`test_black_holes.gd`,
  `test_black_hole_views.gd`, the old `test_e2e_void.gd`, the S6 test in `test_wand_shared.gd`).
- **The card** `gravity_well` (the old Void, an Element) is retired through `data/wand/migration.tres`: never offered
  on either weapon, kept in the data so old saves and item indices resolve (its modifier keeps only its void element
  tag, so the dev panel can still grant it harmlessly). Its row in the Orbs compatibility list is gone.

## What was built

- **Card.** `gun_void` (Void / Vacío, "Throw black holes that tug at foes." / "Lanza agujeros negros que atraen."):
  Rare, Gun only, slot Form. Its modifier (`data/modifiers/gun_void.tres`) keeps the Gun's shot a bolt and makes it a
  Void shot: one every 0.6 s, 9.72 m/s (0.6 × the orbs' 16.2), for 1.11 s (as far as an orb, 10.8 m), radius 0.3 m;
  `void_aura_mm` 1000, `void_tick_seconds` 0.2, `void_pull_mm` 3000, `void_pull_mmps` 1000; damage × 2.0 (+0.1 a
  level): **each aura hit is 10** (2 × an orb hit).
- **Compatibility row** (`data/wand/attack_slots.tres`, F4): Twin and the five elements on; Halo, Ring, Backfire,
  Spiral, Swirl and every Secondary off.
- **Sim** (`src/sim/combat/void_shots.gd`, `VoidShots`). The shot passes through bodies (World's projectile pass
  skips them for a Void shot); a wall or the end of its flight ends it. Tick phase 6: each Void shot's aura hits every
  enemy within 1.0 m (centre to the enemy's edge; the area stat scales it) the tick it comes in, then every 0.2 s while
  it stays (a wait per shot and enemy, `ModifierState.void_*`, hashed only while one waits, snapshotted as an added
  field). Then the pull: each enemy within 3 m of a shot steps toward the shot's path (the line it flies along, never a
  point), `1 m/s × (1 − distance / (3 m + its radius))`; the pulls of every shot on one enemy add and the sum is capped
  at the strongest one's top step (no stacking); a separation push (the pull never draws an enemy toward a neighbour
  within 0.3 m of its edge, and pushes them apart as they close). Heavies (radius ≥ 0.5 m: Shield Bearer, Warden,
  Splitter) half; bosses, elites (`Curses.is_elite`) and enemies still spawning in none. The AI is untouched.
- **View** (`src/presentation/world_view/attack_forms/void_view.gd`, `VoidView`): per shot a travelling lensing sphere:
  a black core; a camera-facing lens that bends the picture behind it (the screen texture pulled toward the core) with
  a bright violet bent-light ring (the owner's `void_lens` PNG when installed in `assets/textures/vfx/`, else the
  code ring); swirling violet dust arms; a trail of three fading dust puffs behind it along its flight; a faint ring on
  the ground at its aura's reach. The enemies it pulls lean into it (`ActorViews._lean`, from `WorldReader.void_leans`,
  the same `VoidShots.steps` the tick applies). HeroPulseViews and AttackFormView leave Void shots to it.
- **Sound.** `void_hum` (new placeholder, 0.42 s low warping hum; recipe `s_void_hum` in `generate_sfx.py`, rendered
  by the real generator in the 3.11 venv into a scratch copy, only `void_hum.wav` and its manifest entry taken, so no
  other sound moved) replaces the orb's `bolt_fire` on a Void run. `data/credits/licences.tres` rebuilt (102 → 103).

## Rules decided (simplest reading; listed for the owner)

| Question | Rule |
|---|---|
| Migration of a held old Void | The table's rule: on a Gun run it becomes the Void form card in its place at **Lv 1** (as every retired card; a Void already held levels up by 1; if the wand already has a Form, AS's trim keeps the leftmost and refunds the other); on a Blade run (the form is Gun only) it is **refunded as shards** at the shop's salvage price. The Blade loses Void from its pool. |
| An old snapshot holding black holes | Restores; the `hole_*` fields are ignored (the holes are dropped), the rest restores exactly. |
| Aura damage | Each hit 2 × an orb hit (10). A shot passing straight through a standing enemy hits it twice (in, then 0.2 s later), 20 per 0.6 s = the orbs' 5 per 0.15 s. |
| "5 ticks a second" | Per enemy and shot: the first hit as it comes in, then every 0.2 s while it stays in. |
| Elements per tick (LZ's rule) | Each aura tick of a shot is its own root (as the Laser's ticks); the feeding share is the aura's tick over the Gun's orb period, 12 / 9 → every hit feeds. On one target that is 5 a second at most, under the orbs' 6.7 (measured below: 33 feeds in 10 s, orbs 66). |
| Pull falloff | Linear from 1 m/s at the shot's centre to 0 at 3 m past the enemy's edge; stops 0.15 m from the path. |
| Heavy | A body of radius 0.5 m or more. |
| Elite | Today's elite (`Curses.is_elite`); the ELITES.md archetypes, when built, should count too. |
| Attack speed | Counts whole (Q10 names no reduction, unlike Q8/Q9). |
| Twin | 2 shots side by side at Lv 1–4, 3 fanned at Lv 5, each at Twin's share (Lv 1: 6 a hit). Each shot hits on its own; the pull is capped per enemy however many overlap. |
| Card text (Q14) | "Void" / "Vacío", "Throw black holes that tug at foes." / "Lanza agujeros negros que atraen."; no numbers. The retired card's strings stay (dev panel only). |

## Tests (raw summary lines; final code)

| Run | Summary |
|---|---|
| sim: test_void (17), test_wand, test_combos, test_attack_slots, test_shot_cap, test_laser, test_bomb, test_wand_migration, test_mx4_modifiers, test_wand_shared, test_items, test_rewards, test_player_builds, test_loot_pacing | `Tests 207 / Passing Tests 207 / Asserts 6487` (a first run had 2 failures: the rare and Gun card lists in test_rewards / test_player_builds lacked `gun_void`; fixed, both files `Tests 41 / Passing Tests 41`, then the whole list re-run as above) |
| test_modifier_smoke (the every-card soak) | `Tests 8 / Passing Tests 8 / Asserts 13334` (after its modifier count went 97 → 98) |
| goldens + arch + old saves: tests/golden/test_replay_ground_plane, test_modifier_equivalence, test_state_hasher, test_world_snapshot, tests/arch/test_layering, test_sim_purity, tests/unit/application/test_old_saves | `Tests 37 / Passing Tests 37 / Asserts 19689` (**no golden moved**) |
| tests/content (whole folder) | `Tests 138 / Passing Tests 136 / Failing Tests 2` (the item and modifier counts, 109 → 110 and 97 → 98); after the fix, test_item_validation + test_modifier_validation `Tests 15 / Passing Tests 15 / Asserts 1169` |
| presentation: test_void_view (4), test_bomb_view, test_laser_view, test_wand_cast_view, test_attack_forms_live, test_audio_director, test_card_frames, test_attack_slot_views | `Tests 50 / Passing Tests 50 / Asserts 6245` |
| e2e: test_e2e_void (new), test_e2e_laser, test_e2e_bomb, test_e2e_attack_slots, test_e2e_old_save | `Tests 5 / Passing Tests 5 / Asserts 73` |

The lines the tests print (`gut.p`):
- `VP one target 4 m out, 10 s held: void 340 dmg in 34 hits, orbs 330 dmg in 66 hits, ratio 1.030`; 3, 6 and 8 m out:
  `ratio 1.000` each. **Single-target DPS ratio ≈ 1.0–1.03 × the orbs** (aura hit 10).
- `VP pull: 0.147 m over one pass, top 0.0071 m a tick` (an enemy 2 m off the path; the cap is 0.0167 m a tick).
- `VP crowd of 10 pulled for 10 s: closest pair 0.895 m (bodies touch at 0.70)`.
- `VP pull in one pass: a 0.35 m body 0.147 m, a 0.55 m heavy 0.069 m`.
- `VP venom feeds in 10 s on one target: void 33 (33 aura hits), orbs 66`.
- e2e (the altar's Void card, right click held 150 frames at a group 5 m out): `VP e2e: on-path dummy hp 4940 / 5000;
  the side ones drifted 0.49 m and 0.49 m toward the path in 150 frames` (they stood 1.9 m off it).

`test_e2e_old_save` and `test_old_saves` pass on this base (ATTACK_SLOTS.md listed them failing on `b6a780b0`).

## Shots

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/void_shots.gd` (RTX 3060) →
`build/shots/v0.8.0/vp/`, copied by hand to [`vp_shots/`](vp_shots/): `1_void_flight` (a Void shot in flight through a
loose group of five dummies, tick 52; the probe printed "voids 1, leaning 3"), `2_void_close` (the same, camera 5.5),
`3_void_twin_fire` (Twin + Fire, two shots; "voids 2, leaning 4").

## Not run here

- Perf probe (`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde=60
  --cards=gun_void,gun_twin --level=5 --seconds=10`, the owner's PC, i7-10700K, headless: CPU side only, one run each,
  nothing else running). The legal build tops out at **6** Void shots alive (Twin Lv 5: 3 every 0.6 s, 1.1 s each), not
  10; 10 at once was not measured. Void: `sim_ms avg 3.705 p95 6.531 max 11.886`, `sync_ms avg 6.210 p95 8.409 max
  18.856`, `total_ms avg 13.529 p95 18.273 max 28.884`, `projectiles max 6`, verdict "OVER" the probe's 12 ms. The
  same horde with the orbs (`--cards=gun_twin`): `sim_ms avg 3.039 max 7.955`, `sync_ms avg 5.315 max 9.741`,
  `total_ms avg 11.620 max 17.550`, "within". So the Void adds about 0.7 ms sim and 0.9 ms view sync a tick on average
  (the view's share is mostly ActorViews' lean, `actors` 3.04 vs 2.19 ms, which re-runs `VoidShots.steps`), and this
  run had one higher worst tick. Frame time on the GPU: NOT YET RUN (owner hardware, not headless).
- test_frozen_shore / test_starfall / test_deep_bite (Spanish-locale sensitive) were not run: this step doesn't touch
  them.
