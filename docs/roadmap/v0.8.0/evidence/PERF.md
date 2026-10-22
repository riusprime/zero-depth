# PERF: does the Gun's level-5 Spread + Split + Explosive build fit a 60 fps frame's CPU budget? (v0.8.0 PF, owner O9)

Owner O9 (verbatim in [`../PLAN.md`](../PLAN.md)): "You have a split and the other power that makes the attack divide
when you hit an enemy. And they explode after it, and that causes hell of a lag. Like it goes, the game goes two, FPS.
find a way of balancing with these animations so the game doesn't have lag a lot. And I feel like the the visuals are
great with these images, but maybe we can stop applying some effects so it doesn't cause some lag."

- **Status:** RUN (agent, headless CPU side). The owner's fps on their PC: **OWNER ONLY**.
- **Build:** before `68383c3` on `claude/lucid-fermat-9wv2tf` plus only the probe (`scripts/checks/perf_probe.gd`)
  and a counter-only patch to `vfx_core.gd` / `vfx_layer.gd` (`sprites_asked`, `bursts_asked`, `lights_asked()`:
  counts, no behaviour change), so the before numbers have the same counters; after: the code of the `v0.8.0 Step PF`
  commit on branch `v080-pf` (the runs were made on that tree before it was committed; only these docs were written
  after them). Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18.44 (cloud container, 4 cores, no GPU).
- **Date:** 2026-10-14
- **Who ran it:** agent

## What the probe does
`scripts/checks/perf_probe.gd` builds the Playground's World (`PlaygroundScenario.build`: the one 4 x 4 room, the
Gun build, the first biome of the run, the biome's real look so the VfxLayer is on), grants `gun_spread`,
`split_shot` and `shared_explosive` at level 5 (and `gun_twin` with `--twin`), places 6 endless dummies 4-7 m in
front of the hero, holds Shoot at them for 10 s after 60 warm-up ticks, and times every tick:
- `sim_ms`: `PlaygroundApi.apply_pending()` (the dummies' refill) + `World.step`;
- `sync_ms`: `WorldViewRoot.sync()` (every view reading the tick);
- `frame_ms`: every `_process` of the view's nodes, called by the probe once per tick (it turns their own processing
  off and calls them itself, so each is timed; `--fixed-fps 60` makes one frame one tick);
- `total_ms`: the three added: one 60 Hz tick and one frame of CPU work.

**Headless has no GPU:** `frame_ms` is the CPU side only (laying out the MultiMesh buffers, lights and decals); the
GPU's draw cost is not in it. The HUD, audio and the ink pass are not in the probe. The container's timings vary by
about ±15 % run to run, so each variant ran three times.

## Command
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --twin
```
(each three times, before and after; the probe also writes `build/perf/perf_probe_<base|twin>.txt`)

## Raw output: before (run 1 of each)
```
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, 6 dummies, 10 s held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            2.638     6.551    10.461
sync_ms           4.467    10.279    14.390
frame_ms         20.694    32.602    55.454
total_ms         27.799    48.500    67.310
projectiles     110.962   253.000   264.000
launches          8.533    24.000    32.000
events           27.495    77.000    99.000
bursts_asked    236.972   256.000   256.000
sprites_asked  4997.307  5637.000  5637.000
sprites_drawn   984.747   995.000   995.000
lights_asked    230.145   256.000   256.000
lights_on        10.000    10.000    10.000
decals           22.457    23.000    23.000
form_effects    241.602   256.000   256.000
form_meshes     349.565   645.000   660.000
frame cost by node (ms per tick, avg):
  AttackFormView             20.305
  PlayerAvatar                0.200
  DamageNumbers               0.043
  HeatVisuals                 0.042
  BossChallengeView           0.017
  StageKit                    0.013
  IsoRig                      0.010
  FireballViews               0.007
  TelegraphViews              0.007
  ActorViews                  0.005
  HordeVisuals                0.005
  BlinkFlash                  0.004
verdict: avg 27.80 ms per tick+frame against 12.0 ms -> OVER
```
```
perf_probe: gun + gun_spread, split_shot, shared_explosive, gun_twin, level 5, 6 dummies, 10 s held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            5.193    15.594    22.729
sync_ms           8.422    21.661    31.942
frame_ms         22.702    37.900    48.926
total_ms         36.318    68.575   102.588
projectiles     263.883   770.000   874.000
launches         19.092    60.000    96.000
events           62.317   250.000   256.000
bursts_asked    246.627   256.000   256.000
sprites_asked  5196.862  5637.000  5637.000
sprites_drawn   981.050   995.000   995.000
lights_asked    246.608   256.000   256.000
lights_on        10.000    10.000    10.000
decals           22.333    23.000    23.000
form_effects    255.688   256.000   256.000
form_meshes     411.662   793.000   799.000
frame cost by node (ms per tick, avg):
  AttackFormView             22.312
  PlayerAvatar                0.204
  DamageNumbers               0.042
  HeatVisuals                 0.042
  BossChallengeView           0.015
  StageKit                    0.013
  IsoRig                      0.010
  TelegraphViews              0.007
  HordeVisuals                0.005
  ActorViews                  0.005
  AbilityVisuals              0.004
  BlinkFlash                  0.004
verdict: avg 36.32 ms per tick+frame against 12.0 ms -> OVER
```

## Raw output: after (run 1 of each)
```
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, 6 dummies, 10 s held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            2.431     6.712    14.253
sync_ms           3.086     7.654    18.996
frame_ms          3.444     6.834    14.932
total_ms          8.961    20.102    38.547
projectiles     104.532   237.000   250.000
launches          8.097    24.000    32.000
events           26.260    77.000    99.000
shots_capped      0.033     0.000     1.000
bursts_asked     30.920    32.000    32.000
bursts_drawn     26.773    32.000    32.000
sprites_asked   379.860   449.000   449.000
sprites_drawn   368.180   417.000   417.000
lights_asked     12.000    12.000    12.000
lights_on        10.000    10.000    10.000
decals           20.677    22.000    22.000
form_effects     35.352    43.000    47.000
form_meshes     249.840   473.000   487.000
frame cost by node (ms per tick, avg):
  AttackFormView              3.127
  PlayerAvatar                0.173
  DamageNumbers               0.036
  HeatVisuals                 0.033
  BossChallengeView           0.011
  StageKit                    0.010
  IsoRig                      0.006
  TelegraphViews              0.005
  ActorViews                  0.005
  HordeVisuals                0.004
  AbilityVisuals              0.003
  BlinkFlash                  0.003
verdict: avg 8.96 ms per tick+frame against 12.0 ms -> within
```
```
perf_probe: gun + gun_spread, split_shot, shared_explosive, gun_twin, level 5, 6 dummies, 10 s held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            2.412     7.986    19.024
sync_ms           2.940     6.298    10.738
frame_ms          3.049     5.164     7.455
total_ms          8.401    18.600    32.794
projectiles     113.220   252.000   256.000
launches          8.505    30.000    42.000
events           28.045   125.000   222.000
shots_capped      0.217     1.000     1.000
bursts_asked     29.442    32.000    32.000
bursts_drawn     21.648    26.000    28.000
sprites_asked   331.560   395.000   413.000
sprites_drawn   329.102   381.000   393.000
lights_asked     11.862    12.000    12.000
lights_on         9.962    10.000    10.000
decals           20.820    24.000    24.000
form_effects     33.952    43.000    49.000
form_meshes     220.905   487.000   496.000
frame cost by node (ms per tick, avg):
  AttackFormView              2.728
  PlayerAvatar                0.176
  DamageNumbers               0.036
  HeatVisuals                 0.032
  BossChallengeView           0.011
  StageKit                    0.010
  IsoRig                      0.007
  TelegraphViews              0.005
  ActorViews                  0.004
  HordeVisuals                0.004
  BlinkFlash                  0.004
  AbilityVisuals              0.003
verdict: avg 8.40 ms per tick+frame against 12.0 ms -> within
```

## All six runs per side (avg / p95 / max, ms; copied from the same runs' output)
| Run | sim | sync | frame | total |
|---|---|---|---|---|
| before base 1 | 2.638 / 6.551 / 10.461 | 4.467 / 10.279 / 14.390 | 20.694 / 32.602 / 55.454 | 27.799 / 48.500 / 67.310 |
| before base 2 | 2.802 / 6.988 / 14.078 | 4.674 / 9.841 / 17.898 | 21.287 / 32.255 / 60.393 | 28.762 / 46.610 / 74.215 |
| before base 3 | 2.555 / 6.482 / 12.966 | 4.233 / 9.228 / 20.804 | 19.274 / 30.380 / 37.069 | 26.062 / 42.405 / 56.550 |
| before twin 1 | 5.193 / 15.594 / 22.729 | 8.422 / 21.661 / 31.942 | 22.702 / 37.900 / 48.926 | 36.318 / 68.575 / 102.588 |
| before twin 2 | 4.986 / 14.224 / 27.387 | 8.188 / 21.750 / 29.640 | 21.732 / 35.415 / 47.898 | 34.906 / 67.065 / 91.593 |
| before twin 3 | 5.176 / 15.011 / 26.388 | 8.331 / 22.285 / 30.465 | 23.036 / 35.819 / 45.178 | 36.543 / 70.720 / 94.473 |
| after base 1 | 2.431 / 6.712 / 14.253 | 3.086 / 7.654 / 18.996 | 3.444 / 6.834 / 14.932 | 8.961 / 20.102 / 38.547 |
| after base 2 | 2.466 / 6.139 / 11.480 | 3.191 / 6.639 / 10.785 | 3.710 / 6.064 / 8.964 | 9.366 / 18.096 / 23.492 |
| after base 3 | 2.328 / 5.868 / 11.865 | 2.894 / 5.824 / 8.881 | 3.301 / 5.562 / 8.696 | 8.523 / 16.470 / 24.178 |
| after twin 1 | 2.412 / 7.986 / 19.024 | 2.940 / 6.298 / 10.738 | 3.049 / 5.164 / 7.455 | 8.401 / 18.600 / 32.794 |
| after twin 2 | 2.486 / 8.194 / 16.389 | 3.080 / 6.823 / 15.378 | 3.117 / 5.704 / 6.776 | 8.683 / 18.798 / 29.175 |
| after twin 3 | 2.320 / 7.649 / 17.544 | 2.775 / 6.157 / 10.333 | 2.887 / 5.276 / 8.579 | 7.983 / 17.035 / 28.624 |

## Where the time went (before)
- **The explosions' drawing:** `AttackFormView`'s frame was 20-22 ms of the 26-37 ms. Every explosion lived 70 ticks
  as a VfxLayer burst (fireball, debris, smoke, sparks, a light request, a scorch), so 237-247 bursts were alive a
  frame, asking for ~5,000 sprites, of which the pools could show 995: about 80 % of the work was laid out and dropped.
  256 light requests were sorted for 10 lights.
- **Composing looks per blast and per bolt** in `AttackFormView.sync`: each explosion composed its spec's look again,
  each bolt formatted a cache key string.
- **The sim (twin):** 264 player projectiles alive on average, 874 at most; `_projectile_hits` (each bolt's sweep, its
  hits and its ON_END explosions) was ~95 % of the sim's tick. A probe-only phase timer (not committed) gave, per tick
  on average: the whole projectile phase 4.27 ms, of which ON_END (the explosions and their hits) 1.52 ms and the
  bolts' hits 0.76 ms; the rest is the sweep over the live bolts.

## What changed
Presentation (keeps the look for a few explosions; thins only under load):
- `VfxLayer.burst`: the first `BURST_FULL` (12) bursts of a frame draw exactly as before, each with its light; past
  them a burst within 1.2 m of one already drawn is merged (not drawn), the rest draw at 30 % density with no light of
  their own, and past `BURST_MAX` (32) none is drawn. The canvas draws the newest effects first, so fresh blasts keep
  their full look and older smoke thins.
- `BurstBudget` (new): at most 32 VfxLayer bursts alive; with 12 or more alive, a new one within 1.2 m and 12 ticks of
  a live one merges into it; past 32 the oldest goes. Below 12 nothing changes.
- `AttackFormCanvas`: at most `LIVE_BOLTS_MAX` (96) live bolts get the element rim and trail a frame; the rest fly as
  their plain dart (ActorViews draws every projectile as before).
- `AttackFormView`: looks cached by spec key (the digest and tier checked once a sync); the explosions reuse the
  cached look instead of composing one each.

Sim (the probe showed the sim is a real cost with Twin: 5 ms average, 15 ms p95):
- `SimTuning.player_shots_max` = 256 (`data/tuning/sim.tres`): the player's projectiles alive at once. A bolt past it
  is not launched and the tick's first such bolt leaves one LIMIT event (`player_shot_cap`). Counted at the tick's
  first player bolt (alive + queued) plus the bolts launched since; `World.shot_tick` / `shot_count` are per-tick,
  not hashed, and listed in `WorldSnapshot.ADDED_SINCE_V05` (an older save restores). Below the cap nothing changes;
  no golden changed. In the base build the cap bound on 3.3 % of ticks (`shots_capped` 0.033), with Twin on 21.7 %.

## Target bands
| Metric | Target | Source |
|---|---|---|
| sim + sync + frame, per tick | under ~12 ms combined ("60 fps worth of CPU") | PLAN row O9 / step PF; the lead's brief |

## Result
| Metric | Before (3 runs) | After (3 runs) | In band? |
|---|---|---|---|
| total avg, base | 26.06-28.76 ms | 8.52-9.37 ms | yes |
| total avg, twin | 34.91-36.54 ms | 7.98-8.68 ms | yes |
| total p95, base | 42.41-48.50 ms | 16.47-20.10 ms | **no** |
| total p95, twin | 67.07-70.72 ms | 17.04-18.80 ms | **no** |
| VfxLayer sprites asked a frame (avg, run 1) | 4,997 / 5,197 | 380 / 332 | — |
| light requests a frame (avg, run 1) | 230 / 247 | 12 / 12 | — |

## Interpretation
- The average tick + frame is now 8-9.4 ms on this container with both builds (it was 26-37 ms): about a third, and
  under the 12 ms budget. The explosions' drawing went from 20-22 ms to about 3 ms.
- **The p95 is still over the target** (16.5-20.1 ms): the ticks where a volley lands (the sim's hits and ON_END
  blasts, then the views reading ~100-200 events) cost 2-3 times the average. On those frames the game can still
  hitch: Godot runs up to 4 ticks in the next frame (`max_physics_steps_per_frame`), so the game slows briefly rather
  than skipping. This is reported as missed; the target was not widened.
- What it doesn't prove: the GPU's cost (no GPU here: fill rate of the additive sprites, the lights and decals on the
  owner's card), the HUD and audio, and fps on the owner's PC. **Owner's fps with this build on their PC: OWNER
  ONLY.**
- The owner's call (OWNER ONLY): whether the thinned look under load still reads well, and whether 256 player shots
  at once is the right cap for gameplay (data: `data/tuning/sim.tres`, `player_shots_max`).

# PF2: the Blade Storm build (v0.8.0 PF2, owner O9, direct fix)

After BL, Blade Storm on the Blade combo was over the budget (BLADE.md: 26.6 ms avg; the lead: 23.5 ms avg, p95 39.0).
Adding `split_wave` to `once_per_line` changed nothing (the lead's try): Split Wave only rides Wave's crescents
(`target = wave`), not Blade Storm's blades.

- **Status:** RUN (agent, headless CPU side). The owner's fps and the feel: **OWNER ONLY**.
- **Build:** before = `62b9ff7` (`claude/lucid-fermat-9wv2tf`), run from an untouched copy of that tree
  (`git archive`, imported); after = the tree of the `v0.8.0 Step PF2` commit on branch `v080-pf2` (the runs were
  made on that tree before it was committed; only these docs were written after them). Godot
  `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 cloud container, 4 cores, no GPU. **The container was shared:**
  three to four other Godot processes ran at the same time (1-minute load average 2.7-6.0 during the evidence runs,
  logged per run below), so timings move by ±10 % or more run to run; before and after were run alternately.
- **Date:** 2026-10-14. **Who ran it:** agent.

## Command
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --weapon=blade --cards=double_slash,blade_storm,echo_slash,split_wave,trigger_on_hit,shared_explosive --tag=blade_storm
```
six times each side (alternating), and one to three times each side for the other PF / BL probes (commands in
BLADE.md). The probe's new `alive_capped` row (after only) is 1 on a tick where a capped throw was cut short.

## Where the time went (before; temporary probe-only timers and counters, not committed)
Per tick on average, the Blade Storm build against the same build without Blade Storm (one run each, loaded
container, so the milliseconds are rough; the counts are exact):
- **Sim:** Blade Storm launches 0.26 times a tick: **every** slash throws its 6 blades at level 5, and Double Slash's
  5 repeats are slashes too, so one swing throws 36 returning blades; ~75 were in flight (103 player projectiles in
  all, against 26). A returning blade passes each dummy on the way out and on the way back, and each of those hits
  cast On Hit's small slash (On Hit's depth-2 casts: 6.6 a tick against 1.3), each hitting 3-4 dummies:
  `Damage.hit` 43.9 a tick against 23.6. The projectile phase was ~4.6 ms of the sim's ~6.5 (3.5 ms of it the
  bolts' hits and what they cast).
- **Sync:** `BladeFormView.sync` 4.7-4.9 ms: every Blade Storm blade inherits the slash's arc width, so it is drawn as
  a crescent; 99 crescents a tick, each 84 ImmediateMesh vertices rebuilt (3.8 ms), plus 24 ghost slashes (0.9 ms).
- **Frame:** `AttackFormView` 7.8-8.7 ms: at its 1,024-mesh cap every frame, 229 of 256 effects (the casts' slashes).
- Not the cause: Split Wave (its damage and launches are the same with and without Blade Storm), Explosive (1.85
  blasts a tick either way), the launch queue (no LIMIT), the 256-shot cap (never bound).

## What changed
Sim (data; deterministic; nothing stored per tick, so no `WorldSnapshot` field):
- **Cast-free line** (`WandTable.cast_free_lines`, data `blade_storm` in `data/wand/wand.tres`): a spec whose lineage
  holds Blade Storm takes no trigger cut, so a Blade Storm blade's hits cast no trigger's spell (B6's line rule, for
  the triggers). The slash, Wave's crescents and everything else still cast (B3's double cast unchanged).
- **A cap of its own** (`AttackSpec.alive_max`, op field `alive_max`, hashed only when set;
  `data/modifiers/blade_storm.tres`: 36 = one level-5 Double Slash swing, 6 slashes × 6 blades): a throw that would
  pass 36 Blade Storm blades alive and queued throws the ones that fit and leaves one LIMIT event
  (`attack_alive_cap`). Blade Storm alone at level 5 keeps at most 18 in flight, so the cap binds only with a repeat
  card (36.2 % of this probe's ticks had a cut throw).

Presentation (the same look, cheaper):
- `BladeFormView`: crescents and ghost slashes are MultiMesh instances of baked shapes (`BakedMeshPools`; the same
  14-segment band, colours and height; a ghost's shape includes its age in ticks).
- `AttackFormCanvas._draw_form`: once the frame's 1,024 form meshes are spent, an effect that draws only meshes (no
  particles of its own, no VfxLayer element, not a bomb) is skipped instead of laid out for nothing.

## Raw output: before (run 1)
```
grant double_slash L5 -> ok
grant blade_storm L5 -> ok
grant echo_slash L5 -> ok
grant split_wave L5 -> ok
grant trigger_on_hit L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: blade + double_slash, blade_storm, echo_slash, split_wave, trigger_on_hit, shared_explosive, level 5, 6 dummies, 10 s of Primary pressed (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            6.470    16.811    33.808
sync_ms           9.387    15.102    27.560
frame_ms          8.306    12.289    15.591
total_ms         24.163    38.564    59.654
projectiles     103.343   155.000   202.000
launches         12.643    37.000    47.000
events          118.613   263.000   424.000
shots_capped      0.000     0.000     0.000
bursts_asked     10.462    13.000    15.000
bursts_drawn     10.352    12.000    12.000
sprites_asked   231.942   269.000   269.000
sprites_drawn   231.942   269.000   269.000
lights_asked     10.352    12.000    12.000
lights_on         9.027    10.000    10.000
decals            1.760     3.000     3.000
form_effects    229.270   256.000   256.000
form_meshes    1023.932  1024.000  1024.000
frame cost by node (ms per tick, avg):
  AttackFormView              7.847
  PlayerAvatar                0.198
  KitView                     0.057
  DamageNumbers               0.047
  HitFeel                     0.026
  BossChallengeView           0.016
  StageKit                    0.014
  IsoRig                      0.012
  TelegraphViews              0.010
  ActorViews                  0.008
  HeatVisuals                 0.008
  HordeVisuals                0.006
damage: 136911 over 10.0 s -> 13691.1 per s (2281.8 per s per dummy; DpsTally overall 13691.1)
  trigger_on_hit                47135   34.4 %
  split_wave                    36024   26.3 %
  shared_explosive              20899   15.3 %
  blade_storm                   15103   11.0 %
  echo_slash                     9374    6.8 %
  twin_arc                       6344    4.6 %
  basic                          2032    1.5 %
verdict: avg 24.16 ms per tick+frame against 12.0 ms -> OVER
```

## Raw output: after (run 1)
```
grant double_slash L5 -> ok
grant blade_storm L5 -> ok
grant echo_slash L5 -> ok
grant split_wave L5 -> ok
grant trigger_on_hit L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: blade + double_slash, blade_storm, echo_slash, split_wave, trigger_on_hit, shared_explosive, level 5, 6 dummies, 10 s of Primary pressed (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            4.216    12.002    17.691
sync_ms           3.897     6.751    11.493
frame_ms          4.838     7.526    10.072
total_ms         12.950    23.765    35.206
projectiles      60.003   103.000   140.000
launches          7.210    23.000    39.000
events           76.095   175.000   276.000
shots_capped      0.000     0.000     0.000
alive_capped      0.362     1.000     1.000
bursts_asked     12.997    16.000    21.000
bursts_drawn     11.793    12.000    12.000
sprites_asked   243.853   254.000   260.000
sprites_drawn   243.853   254.000   260.000
lights_asked     11.427    12.000    12.000
lights_on         9.900    10.000    10.000
decals            1.757     3.000     3.000
form_effects    102.275   147.000   180.000
form_meshes     808.467  1024.000  1024.000
frame cost by node (ms per tick, avg):
  AttackFormView              4.411
  PlayerAvatar                0.187
  KitView                     0.056
  DamageNumbers               0.043
  HitFeel                     0.022
  BossChallengeView           0.015
  StageKit                    0.013
  IsoRig                      0.011
  TelegraphViews              0.010
  HeatVisuals                 0.008
  ActorViews                  0.008
  ItemVisuals                 0.005
damage: 109991 over 10.0 s -> 10999.1 per s (1833.2 per s per dummy; DpsTally overall 10999.1)
  split_wave                    36161   32.9 %
  trigger_on_hit                28425   25.8 %
  shared_explosive              20865   19.0 %
  echo_slash                     9405    8.6 %
  blade_storm                    6857    6.2 %
  twin_arc                       6253    5.7 %
  basic                          2025    1.8 %
verdict: avg 12.95 ms per tick+frame against 12.0 ms -> OVER
```

## All Blade Storm runs (avg / p95 / max, ms; copied from each run's output; load: the 1-minute load average after it)
| Run | sim | sync | frame | total | load |
|---|---|---|---|---|---|
| before 1 | 6.470 / 16.811 / 33.808 | 9.387 / 15.102 / 27.560 | 8.306 / 12.289 / 15.591 | 24.163 / 38.564 / 59.654 | 5.95 |
| before 2 | 7.101 / 18.623 / 37.413 | 10.337 / 17.235 / 23.155 | 9.075 / 14.438 / 21.742 | 26.514 / 45.421 / 76.692 | 5.15 |
| before 3 | 7.015 / 17.173 / 40.959 | 9.978 / 15.724 / 45.000 | 8.743 / 12.870 / 18.326 | 25.736 / 41.717 / 67.694 | 4.75 |
| before 4 | 6.189 / 15.713 / 28.728 | 8.800 / 14.282 / 21.430 | 7.770 / 12.142 / 17.849 | 22.759 / 37.763 / 50.782 | 2.95 |
| before 5 | 6.373 / 16.226 / 27.425 | 9.136 / 14.431 / 27.318 | 8.005 / 11.656 / 25.549 | 23.514 / 38.702 / 60.198 | 2.85 |
| before 6 | 6.504 / 16.331 / 25.986 | 9.485 / 15.540 / 23.377 | 8.321 / 13.092 / 16.734 | 24.309 / 41.558 / 59.432 | 3.33 |
| after 1 | 4.216 / 12.002 / 17.691 | 3.897 / 6.751 / 11.493 | 4.838 / 7.526 / 10.072 | 12.950 / 23.765 / 35.206 | 5.18 |
| after 2 | 4.183 / 12.213 / 20.062 | 3.848 / 6.417 / 11.058 | 4.877 / 7.774 / 21.514 | 12.908 / 24.224 / 35.995 | 4.97 |
| after 3 | 3.996 / 11.358 / 20.199 | 3.680 / 6.188 / 12.096 | 4.605 / 6.503 / 19.095 | 12.281 / 22.226 / 42.658 | 4.57 |
| after 4 | 3.913 / 10.576 / 19.803 | 3.478 / 6.037 / 10.482 | 4.472 / 6.903 / 11.978 | 11.863 / 22.117 / 31.083 | 2.74 |
| after 5 | 3.990 / 11.152 / 24.027 | 3.564 / 5.953 / 12.084 | 4.617 / 7.245 / 12.824 | 12.171 / 22.267 / 36.674 | 2.74 |
| after 6 | 3.770 / 10.679 / 14.564 | 3.434 / 5.839 / 9.743 | 4.398 / 6.863 / 9.211 | 11.602 / 20.528 / 27.898 | 3.72 |

Damage (deterministic, the same in every run of a side): before 136,911 over 10 s = **13,691.1 per s**; after
109,991 = **10,999.1 per s** (−19.7 %). Blade Storm's own 15,103 → 6,857 (the cap); On Hit's 47,135 → 28,425 (the
blades' casts gone; what is left is the slashes' and the crescents', 28,500 in the build without Blade Storm). That
build does 10,303.5 per s, so Blade Storm still adds 6.8 % on this probe.

## The other probes (total avg / p95 / max, ms)
| Probe | Before | After |
|---|---|---|
| Gun base (3 runs) | 5.692 / 9.864 / 15.833; 5.972 / 11.228 / 19.025; 5.644 / 9.988 / 17.061 | 6.106 / 10.844 / 19.458; 5.839 / 10.280 / 21.051; 5.960 / 11.351 / 15.947 |
| Gun + Twin (3 runs) | 6.945 / 13.349 / 33.585; 6.434 / 11.986 / 17.435; 6.585 / 12.255 / 23.902 | 7.231 / 14.540 / 23.457; 6.805 / 12.744 / 19.769; 6.516 / 12.751 / 18.332 |
| Blade combo without Blade Storm (1 run) | 12.728 / 24.926 / 52.036 | 9.848 / 18.755 / 35.653 |
| Blade trade-offs (1 run) | 2.150 / 3.639 / 14.803 | 1.983 / 2.910 / 12.400 |

Damage per s, the same before and after: Gun base 778.1, + Twin 1,014.8, Blade combo 10,303.5, trade-offs 87.5.

## Result
| Metric | Target | Before (6 runs) | After (6 runs) | In band? |
|---|---|---|---|---|
| Blade Storm build, total avg | ≤ ~12 ms | 22.76-26.51 ms | 11.60-12.95 ms | **borderline: 2 of 6 runs within (11.60, 11.86); 4 over, by 0.17-0.95 ms** |
| Blade Storm build, total p95 | reported | 37.76-45.42 ms | 20.53-24.22 ms | **no** |
| The other probes | not worse | 5.64-12.73 ms | see the table | the Blade's better (12.73 → 9.85, 2.15 → 1.98); the Gun's within its run-to-run spread (5.64-5.97 → 5.84-6.11; Twin 6.43-6.95 → 6.52-7.23), not shown better or worse |

## Interpretation
- The cause was the Blade Storm × Double Slash × On Hit chain, plus the crescent drawing: 36 returning blades a swing,
  each blade's hit (out and back) casting On Hit's slash, ~75 blades in flight each rebuilt as 84 vertices, and the
  attack-form view at its mesh cap laying out the casts' slashes. Split Wave was not the cause.
- After: the tick + frame average is about half (22.8-26.5 → 11.6-13.0 ms), close to the same combo without Blade
  Storm (9.8-12.7 ms on this container). **The ~12 ms average is met in 2 of 6 runs only, on a container shared with
  other jobs: reported as borderline, not widened, not retuned to fit.** The p95 is still about double the average
  (missed, as PF's was): the volley ticks cost more.
- Damage: 13,691 → 10,999 per s on the probe; Blade Storm's own blades 1,510 → 686 per s, because with Double Slash
  at level 5 a swing's blades now stop at 36 in flight and their hits cast nothing. Without a repeat card the cap
  never binds. Whether Blade Storm still feels strong: **OWNER ONLY** (data: `alive_max` in
  `data/modifiers/blade_storm.tres`, `cast_free_lines` in `data/wand/wand.tres`; both starting values).
- What it doesn't prove: the GPU's cost, the owner's fps (**OWNER ONLY**), a run with stats and loops.
