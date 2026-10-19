# v0.8.0 perf and graphics (O86, O87): evidence

Each step keeps its own section (FS, FV, GX) so the branches merge cleanly.

## FV

**Owner lines.**
- O86: "Two files of new feedback to reduce fps and upgrade graphics … I'll do the fps test on my own machine you
  don't need to run them".
- O87: "the main problem is that when a visual op build hits a horde of enemies the game lags, so we are trying to fix
  how the fps drops when a lot of enemies are being hit with explosions fires and multiple attacks at the same time".

The source is `feedback/2026-10-19_perf_and_wand_math.md` Part 3, which was written against old `main`. I re-checked
each item against `claude/perf-graphics-v080` at `d2ae864`.

**Build:** branch `v080-fv` from `d2ae864`. The code under test is this step's commit (amended from a local WIP), including the probe, status and
Charger changes. Godot `4.7.2.stable.official.ed1daf0bf`, headless, on a cloud machine with 4 CPUs.

### What was already done (skipped)
- **The explosion build's frame budget (PF):** the first 12 bursts of a frame draw in full, nearby ones merge after
  that, the next ones are thinned, and none are drawn past 32. `BurstBudget` keeps at most 32 bursts alive and the
  sim caps player shots at 256. Part 3's "Twin + Explosive" burst case was largely covered by this; FV adds the light
  merge on top.
- **Shocked enemies:** they already asked for no light (`_lightning(..., lit = false)`).
- **Frosted enemies:** they never had a light.
- **Decals, glow and damage numbers:** left alone, as the brief said. The probe shows `DamageNumbers` at 0.09 ms per
  tick, so it is not a hot spot.

### What changed (presentation only; no sim, data or golden change)
1. **Merged lights** (`VfxCore._light` → `_light_merged`, `LIGHT_MERGE_M` = 2.5 m):
   - Every element's field, ring, line and burst now joins a light of the same colour within 2.5 m. This was already
     the fire patches' rule. Only the exact same colour merges: warm fire, explosions and burning enemies merge with
     each other, while cold storm, ice, venom, blood and void each stay separate.
   - A lone effect's light is unchanged.
   - Each merge brightens the shared light by 1.08x, now capped at `LIGHT_MERGE_BOOST_MAX` (1.3, a starting value)
     times the brightest light in the group. Before, the boost had no limit: 40 burning enemies in one spot would have
     reached about 1.08^39, roughly 20x. Fire with up to three merges looks the same as before.
   - `_light_merged` now honours `_lights_off`. Before, a burst PF had thinned could still ask for a light through
     the merged path.
2. **Status lights budgeted** (`_light_status`, `_flush_status_lights`):
   - A burning enemy's light is gathered over the frame and laid in at its end, brightest first, with ties broken by
     place (x, then z).
   - Each one merges within 2.5 m. At most `STATUS_LIGHTS_MAX` (4, a starting value) new lights come from statuses;
     the rest are dropped.
3. **Pressure thinning** (`VfxCore._thin`, `PRESSURE` = 0.7, a starting value):
   - Once a pool is 70 % full, or the frame has used 70 % of `MAX_SPRITES`, an effect halves (rounding up) its
     explosion debris, smoke and sparks, its lightning-end sparks and embers, and its frost crystals (fields, rings,
     lines, bursts and frosted enemies) with their sparks and mist.
   - The blast, flash, bolts and flames are kept.
   - It reads only this frame's counts, in the callers' fixed draw order.
4. **O87 per-enemy fixes the horde probe pointed at:**
   - `StatusVisuals`: under the effects layer, each enemy with a status no longer builds its ~15 hidden box, prism and
     shell meshes (the layer draws embers, drips, crystals, sparks and the shell). The shock pips and guard orbs are
     built the first time they show.
   - `ChargerAvatar`: the body and leg meshes (geometry only; every colour is a per-instance material) are built once
     and shared, as the Warden's already were. Before, every respawned Charger rebuilt about 20 SurfaceTool meshes.
5. **The horde probe** (`scripts/checks/perf_probe.gd --horde[=N]`):
   - Setup: 110 live Chargers chase the hero and are topped back up (at most 8 a tick, at fixed spiral spots). The
     build is Twin, Split, Explosive, Cinder Shot, Static Chain, Ember Core and Wildfire, all at level 5. The hero
     can't be hurt and the aim turns once every 256 ticks.
   - Output: sim/sync/frame plus the per-view sync breakdown (`WorldViewRoot.profile_sync`, a plain call in the game),
     and per-tick counts.
   - **Probe fix:** the probe added a crowd avatar to its process list again every tick ActorViews turned it back on,
     so each avatar ran once per tick it had been near. The first horde run read `frame_ms` 567 ms avg because of this.
     The probe now rebuilds its list each tick (see "Probe bug" below).
   - The probe's `sync_ms` no longer includes the horde's top-up.

### Commands and raw results

**Tests (lint first):**
```
gdformat --check src scripts tests && gdlint src scripts tests
→ gdlint: Success: no problems found
→ gdformat: "1 file would be reformatted" = src/presentation/world_view/boss_door_view.gd, untouched by FV (already so at d2ae864)

godot --headless --path . --editor --import --quit            → exit 0

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<tests/unit/presentation/>test_vfx_pressure.gd,
  test_vfx_budget.gd,test_vfx_layer.gd,test_status_visuals.gd,test_vfx_interpolation.gd,test_attack_visuals.gd,
  test_attack_visuals_2.gd,test_hit_impact.gd,test_attack_forms.gd -gexit
→ Scripts 9, Tests 101, Passing Tests 101, Asserts 19122, Orphans 3, Time 91.024s

(after the StatusVisuals and ChargerAvatar changes)
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<tests/unit/presentation/>test_charger_avatar.gd,
  test_status_visuals.gd,test_vfx_layer.gd,test_damage_flash.gd,test_boss_views.gd,test_melee_strikes.gd,
  test_windup_tells.gd,test_hit_impact.gd,test_vfx_pressure.gd,test_vfx_budget.gd -gexit
→ Scripts 10, Tests 85, Passing Tests 85, Asserts 3365, Orphans 4, Time 39.011s
```

**Horde probe:**
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde --seconds=10 --tag=<tag>
```
- "before" is `d2ae864`'s `vfx_core.gd` and `vfx_layer.gd`, copied in for the run, with the fixed probe.
- "after" is FV.
- Both runs grant all 7 cards ("ok"). The sim's counts match exactly, so the sim was untouched: projectiles 20.887,
  events 13.060, hits 2.547, damage 3.173, kills 0.375, status_applies 4.440, damage 10794 over 10 s.

| metric (avg / p95 / max) | before | after |
|---|---|---|
| lights_asked (light requests a frame) | 39.560 / 65 / 72 | **7.618 / 11 / 11** |
| lights_merged | — | 27.655 / 43 / 45 |
| status_lights_asked / dropped | — | 27.768 / 53 / 57 ; 4.287 / 17 / 28 |
| lights_on | 9.860 / 10 / 10 | 7.523 / 10 / 10 |
| sprites_drawn | 550.503 / 780 / 902 | 550.503 / 780 / 902 |
| pieces_thinned | — | 0 / 0 / 0 (no pool reached 70 % in this build) |
| status_drawn (enemies with a status) | 27.807 / 53 / 57 | 27.807 / 53 / 57 |
| flashing / damage_numbers | 3.323 / 2.403 | 3.323 / 2.403 |
| sim_ms | 4.760 / 9.589 / 19.658 | 4.749 / 9.740 / 16.244 |
| sync_ms | 9.735 / 21.195 / 51.196 | 8.147 / 13.902 / 25.384 |
| frame_ms (CPU only, headless) | 8.553 / 15.878 / 31.896 | 8.642 / 12.620 / 16.824 |
| total_ms | 23.049 / 40.778 / 77.503 | 21.538 / 31.726 / 51.246 |

The ms rows are one run each on a busy 4-CPU machine. They rank the hot spots and are not measurements.
**The frame target: NOT YET RUN (owner hardware).**

**Ranking, raw (ms per tick, avg):**
```
before                                   after
frame cost by node:                      frame cost by node:
  ChargerAvatar      4.572                 ChargerAvatar      4.546
  AttackFormView     3.107                 AttackFormView     3.220
  PlayerAvatar       0.180                 PlayerAvatar       0.185
  HitFeel            0.118                 HitFeel            0.116
  BarChunks          0.112                 HeroPulseViews     0.107
  HeroPulseViews     0.107                 BarChunks          0.106
  DamageNumbers      0.089                 DamageNumbers      0.088
sync cost by view:                       sync cost by view:
  actors             4.181                 actors             3.158
  status_fx          1.343                 status_fx          0.784
  item_fx            0.739                 item_fx            0.738
  attack_forms       0.437                 attack_forms       0.425
  spikes             0.380                 spikes             0.385
  telegraphs         0.324                 telegraphs         0.320
  hit_feel           0.260                 hit_feel           0.250
```

### What the probe says is left (not changed; proposals)
1. **The sim:** 4.7 ms avg, 9.7 ms p95. I didn't change it (it would change goldens), and I didn't time inside it.
   PF's earlier phase timer put about 95 % of a Twin tick in `_projectile_hits`. Proposed next step: a probe-only
   phase timer on the horde, then a spatial grid for the projectile and explosion queries over N enemies. The
   outcomes stay the same; only the query order is a hash risk to check.
2. **`ChargerAvatar` animation:** 4.5 ms for 110 avatars, about 41 µs each, CPU only. ActorViews already stops
   animating avatars past `ANIMATE_RADIUS_M`. Proposal for the owner, since it changes the look: past the nearest
   ~40 enemies, animate at half rate (every other frame).
3. **`AttackFormView`:** 3.2 ms. This is the effects layer's frame (sprites laid out, lights, decals); the sprite
   count is unchanged.
4. **The GPU** is not in a headless frame: the fill rate of the additive sprites and the lights. Most of FV's light
   savings land there (39.6 → 7.6 light requests a frame; at most 10 lights are on at any time, but far fewer now
   compete). The owner's PC run shows that. Command for the owner:
   `godot --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde --seconds=10` (without `--headless` the
   wall time includes the draw), and `build/perf/perf_probe_horde.txt`.

### Probe bug (found here)
- `perf_probe._adopt` appended every node that was processing on each tick. ActorViews turns each near crowd avatar
  back on every sync (its off-screen LOD), so a near avatar was appended again every tick and ran N times by tick N.
- The first horde run read `frame_ms` 567.029 avg, with ChargerAvatar at 562.938 ms. The fixed probe reads 8.553 on
  the same code.
- The fix: the probe turns every node it took over back on before each sync, lets ActorViews turn the far crowd off,
  and runs each processing node once a tick.
- PF's dummy-only runs may have been affected only if dummies carry `enemy_avatar`. They were not re-run here.
