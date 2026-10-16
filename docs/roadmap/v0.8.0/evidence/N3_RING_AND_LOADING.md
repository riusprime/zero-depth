# N3: Ring as a travelling shot, and loading covers with portal transitions (v0.8.0 N3, owner O45, O47)

- **Status:** RUN (agent, headless CPU side for the probe; Xvfb + llvmpipe for the shots). Feel, look in motion and
  fps on the owner's PC: **OWNER ONLY**.
- **Build:** "before" = `586f7cc` (an untouched `git archive` copy of it, its own import); "after" = the `v080-n3`
  working tree on `586f7cc`, run before the Step N3 commit (its SHA is in PROGRESS's Done row; only these docs were
  written after the runs). Godot `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 (cloud container, 4 cores, no GPU),
  shared with other agents (the 1-minute load is printed after each frame run).
- **Date:** 2026-10-16
- **Who ran it:** agent

Owner (O47, verbatim in [`../PLAN.md`](../PLAN.md)): "the circle should substitute the fireball not be a circle that
spawns where you aim"; "it was quite broken, maybe substituting the fireball for a shooting ring is better balanced";
D26/D27 "we are gonna change this". Owner (O45): "we have to add loading screens so the game does not freeze when you
start the game and take a portal, these could be fades into black and a little loading symbol on a corner, and the
load between floors in portal an animation that covers the screen with the color and animation style of the portal you
cross and then unveils it back at the new floor".

## Part A: the Ring is the shot

### What it does now (`src/sim/combat/wand_rings.gd`, `ModifierAbilities` ring runner)
The Gun's shot becomes a lightning ring that leaves the hero's edge along the aim at the shot's speed for the shot's
flight (`AttackSpec.ring_flight`, taken in from the bolt by `WandCompile.take_in`; a wall on its line cuts it short),
grows from 45 % of its radius to the whole in 10 ticks, and hits every enemy its disc passes over, **once per ring and
pulse** (`AbilityState.ring_seen`), shocking it. No circle is cast at the aim point any more. The order rule stays:

| Wand | Result |
|---|---|
| Ring | one ring shot (1.4 m, +0.2 m a level) |
| Ring · Spread | a fan of three ring shots (Spread's angles; 5, 7 … by level), each 0.4 of the ring's hit |
| Spread · Ring | **one** ring shot that carries the three: 30 % bigger (+15 % per extra pulse), its flight split into 3 pulses that each grow out again from 45 %, so what it carries is hit up to 3 times (0.4 each) |
| Ring · Spread · Swirl | the storm: each ring flies off its own random way, one every 4 ticks (the named stream) |
| Swirl · Ring · Spread | one spinning group: the three rings circle a centre that flies the aim (0.7 ring radii out, a turn in ~0.7 s); one ring alone wobbles round its line. No randomness |
| Ring · Halo | a circle of ring shots all round the hero (Halo's ×3 and its half range: half the radius) |

The rings of one launch share **one root** (AO gave each ring its own), so a launch feeds an enemy's shock once and
discharges it once however many of its rings pass over it. The card feeds shock every 4th hit (`every = 4`); its hit
share is the whole hit (`ring_share_permille` 1000), `WandRings.MULTI_PERMILLE` 400 when a launch is more than one
ring or pulse. Caps kept: 48 rings alive (`RINGS_MAX`), 5 pulses, 64 ring shards alive. **Swirl's randomness stays
on its named stream** `wand:swirl:<tick>:<launch>` (the storm's directions and a swirled bolt's angle); the group
spin draws nothing. D13 covers listing it (D45 asks it again).

Old saves: the six new ring columns (`ring_vel`, `ring_orb`, `ring_orb_a`, `ring_pulse`, `ring_k`, `ring_seen`) are
in `WorldSnapshot.ADDED_SINCE_V05`; a save's rings without them are padded as plain rings (they grow where they were
cast, as before; `test_a_ring_from_before_n3_is_a_plain_ring_that_grows_where_it_was`). The columns hash only while a
ring travels, so worlds with no travelling ring hash as before.

View: `WorldReader.rings_live()` gives a travelling ring's start, velocity and orbit; `WorldReader.ring_place()` puts
it between ticks with the sim's own formulas (`ModifierAbilities.travel_centre` / `travel_radius`), so the ring drawn is
the ring that hits; it fades over its flight's last fifth. The shock arcs between a launch's rings and the storm's
strikes are AO's (`AttackFormView._sync_ring_arcs`), now on the moving centres.

### Commands
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --cards=<cards> --level=1 --sim-only
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --cards=<cards> --level=1 --sim-only --dummies=1 --on-aim
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --cards=<cards> --level=5
```
each run once in the "before" copy and once in the working tree (the damage is deterministic; the before rows equal
AO's evidence exactly). The comparators (Spread, Halo, Bomb Rounds, Boomerang, Orbit Rounds, Split, Explosive) are
code N3 didn't touch: their before and after rows are identical (both pasted below).

### Tuning runs (in order; reported, not hidden)
Ring alone, L1, 6 dummies / 1 on the aim (per s): radius 1.6, share 600, shock every hit: 498.9 / — (75 % shock
discharges); radius 1.4, share 600, shock every 2: 103.3 / 31.1; share 850: 116.6 / 37.8; then the orders at share
850 / multi 850, each ring its own root: Ring · Spread 513.3 / 92.5, Swirl · Ring · Spread 670.0 / 91.9 (the spinning
group re-hit what it orbited over: fixed by once per ring and pulse); one root per launch, multi 600: 386.4 / 61.7 and
463.0 / 61.3; share 1000, multi 500, shock every 3, group orbit 0.7: 328.1 / 61.7 and 351.8 / 61.7; **kept**: shock
every 4, multi 400 (the table below).

### Raw output: damage, level 1 (`grep ^damage:` of each run)
Before (`586f7cc`):
```
none L1 [6 dummies] damage: 534 over 10.0 s -> 53.4 per s (8.9 per s per dummy; DpsTally overall 53.8)
none L1 [--dummies=1 --on-aim] damage: 346 over 10.0 s -> 34.6 per s (34.6 per s per dummy; DpsTally overall 34.9)
gun_spread L1 [6 dummies] damage: 1107 over 10.0 s -> 110.7 per s (18.4 per s per dummy; DpsTally overall 111.3)
gun_spread L1 [--dummies=1 --on-aim] damage: 346 over 10.0 s -> 34.6 per s (34.6 per s per dummy; DpsTally overall 34.9)
halo_shot L1 [6 dummies] damage: 534 over 10.0 s -> 53.4 per s (8.9 per s per dummy; DpsTally overall 53.8)
halo_shot L1 [--dummies=1 --on-aim] damage: 346 over 10.0 s -> 34.6 per s (34.6 per s per dummy; DpsTally overall 34.9)
bomb_rounds L1 [6 dummies] damage: 790 over 10.0 s -> 79.0 per s (13.2 per s per dummy; DpsTally overall 79.7)
bomb_rounds L1 [--dummies=1 --on-aim] damage: 374 over 10.0 s -> 37.4 per s (37.4 per s per dummy; DpsTally overall 37.7)
boomerang L1 [6 dummies] damage: 1272 over 10.0 s -> 127.2 per s (21.2 per s per dummy; DpsTally overall 127.2)
boomerang L1 [--dummies=1 --on-aim] damage: 618 over 10.0 s -> 61.8 per s (61.8 per s per dummy; DpsTally overall 62.3)
orbit_rounds L1 [6 dummies] damage: 501 over 10.0 s -> 50.1 per s (8.3 per s per dummy; DpsTally overall 50.5)
orbit_rounds L1 [--dummies=1 --on-aim] damage: 346 over 10.0 s -> 34.6 per s (34.6 per s per dummy; DpsTally overall 34.9)
split_shot L1 [6 dummies] damage: 962 over 10.0 s -> 96.2 per s (16.0 per s per dummy; DpsTally overall 96.7)
split_shot L1 [--dummies=1 --on-aim] damage: 346 over 10.0 s -> 34.6 per s (34.6 per s per dummy; DpsTally overall 34.9)
shared_explosive L1 [6 dummies] damage: 865 over 10.0 s -> 86.5 per s (14.4 per s per dummy; DpsTally overall 87.2)
shared_explosive L1 [--dummies=1 --on-aim] damage: 436 over 10.0 s -> 43.6 per s (43.6 per s per dummy; DpsTally overall 44.0)
gun_ring L1 [6 dummies] damage: 3859 over 10.0 s -> 385.9 per s (64.3 per s per dummy; DpsTally overall 385.9)
gun_ring L1 [--dummies=1 --on-aim] damage: 542 over 10.0 s -> 54.2 per s (54.2 per s per dummy; DpsTally overall 54.2)
gun_ring,gun_spread L1 [6 dummies] damage: 7084 over 10.0 s -> 708.4 per s (118.1 per s per dummy; DpsTally overall 712.0)
gun_ring,gun_spread L1 [--dummies=1 --on-aim] damage: 470 over 10.0 s -> 47.0 per s (47.0 per s per dummy; DpsTally overall 47.6)
gun_spread,gun_ring L1 [6 dummies] damage: 10710 over 10.0 s -> 1071.0 per s (178.5 per s per dummy; DpsTally overall 1071.0)
gun_spread,gun_ring L1 [--dummies=1 --on-aim] damage: 1440 over 10.0 s -> 144.0 per s (144.0 per s per dummy; DpsTally overall 144.0)
gun_ring,gun_spread,gun_swirl L1 [6 dummies] damage: 2788 over 10.0 s -> 278.8 per s (46.5 per s per dummy; DpsTally overall 278.8)
gun_ring,gun_spread,gun_swirl L1 [--dummies=1 --on-aim] damage: 378 over 10.0 s -> 37.8 per s (37.8 per s per dummy; DpsTally overall 38.6)
gun_swirl,gun_ring,gun_spread L1 [6 dummies] damage: 2904 over 10.0 s -> 290.4 per s (48.4 per s per dummy; DpsTally overall 290.4)
gun_swirl,gun_ring,gun_spread L1 [--dummies=1 --on-aim] damage: 332 over 10.0 s -> 33.2 per s (33.2 per s per dummy; DpsTally overall 33.6)
gun_ring,halo_shot L1 [6 dummies] damage: 892 over 10.0 s -> 89.2 per s (14.9 per s per dummy; DpsTally overall 89.2)
gun_ring,halo_shot L1 [--dummies=1 --on-aim] damage: 474 over 10.0 s -> 47.4 per s (47.4 per s per dummy; DpsTally overall 47.4)
```
After (the comparators' 16 rows are byte-identical to the before rows above and are not repeated):
```
gun_ring L1 [6 dummies] damage: 1016 over 10.0 s -> 101.6 per s (16.9 per s per dummy; DpsTally overall 101.9)
gun_ring L1 [--dummies=1 --on-aim] damage: 386 over 10.0 s -> 38.6 per s (38.6 per s per dummy; DpsTally overall 38.7)
gun_ring,gun_spread L1 [6 dummies] damage: 2995 over 10.0 s -> 299.5 per s (49.9 per s per dummy; DpsTally overall 300.5)
gun_ring,gun_spread L1 [--dummies=1 --on-aim] damage: 562 over 10.0 s -> 56.2 per s (56.2 per s per dummy; DpsTally overall 56.4)
gun_spread,gun_ring L1 [6 dummies] damage: 2343 over 10.0 s -> 234.3 per s (39.1 per s per dummy; DpsTally overall 234.7)
gun_spread,gun_ring L1 [--dummies=1 --on-aim] damage: 386 over 10.0 s -> 38.6 per s (38.6 per s per dummy; DpsTally overall 38.7)
gun_ring,gun_spread,gun_swirl L1 [6 dummies] damage: 521 over 10.0 s -> 52.1 per s (8.7 per s per dummy; DpsTally overall 52.4)
gun_ring,gun_spread,gun_swirl L1 [--dummies=1 --on-aim] damage: 84 over 10.0 s -> 8.4 per s (8.4 per s per dummy; DpsTally overall 8.8)
gun_swirl,gun_ring,gun_spread L1 [6 dummies] damage: 2895 over 10.0 s -> 289.5 per s (48.2 per s per dummy; DpsTally overall 289.5)
gun_swirl,gun_ring,gun_spread L1 [--dummies=1 --on-aim] damage: 562 over 10.0 s -> 56.2 per s (56.2 per s per dummy; DpsTally overall 56.2)
gun_ring,halo_shot L1 [6 dummies] damage: 609 over 10.0 s -> 60.9 per s (10.2 per s per dummy; DpsTally overall 60.9)
gun_ring,halo_shot L1 [--dummies=1 --on-aim] damage: 183 over 10.0 s -> 18.3 per s (18.3 per s per dummy; DpsTally overall 18.4)
```
Two-card comparators (after tree, code N3 didn't touch; `one.sh` = the same probe command):
```
gun_spread,boomerang L1 [6] damage: 2001 over 10.0 s -> 200.1 per s (33.4 per s per dummy; DpsTally overall 200.1)
gun_spread,boomerang L1 [--dummies=1 --on-aim] damage: 618 over 10.0 s -> 61.8 per s (61.8 per s per dummy; DpsTally overall 62.3)
gun_spread,shared_explosive L1 [6] damage: 1956 over 10.0 s -> 195.6 per s (32.6 per s per dummy; DpsTally overall 196.6)
gun_spread,shared_explosive L1 [--dummies=1 --on-aim] damage: 436 over 10.0 s -> 43.6 per s (43.6 per s per dummy; DpsTally overall 44.0)
```

### DPS table (per second; from the rows above)
| Wand (level 1) | 6 dummies before | after | × plain after | 1 on the aim before | after |
|---|---|---|---|---|---|
| plain shot | 53.4 | 53.4 | 1.0 | 34.6 | 34.6 |
| Spread | 110.7 | 110.7 | 2.1 | 34.6 | 34.6 |
| Boomerang (rare) | 127.2 | 127.2 | 2.4 | 61.8 | 61.8 |
| Split | 96.2 | 96.2 | 1.8 | 34.6 | 34.6 |
| Explosive | 86.5 | 86.5 | 1.6 | 43.6 | 43.6 |
| Bomb Rounds (rare) | 79.0 | 79.0 | 1.5 | 37.4 | 37.4 |
| **Ring** | 385.9 (7.2×) | **101.6** | 1.9 | 54.2 | **38.6** |
| Ring · Spread | 708.4 | **299.5** | 5.6 | 47.0 | **56.2** |
| Spread · Ring | 1,071.0 | **234.3** | 4.4 | 144.0 | **38.6** |
| Ring · Spread · Swirl | 278.8 | **52.1** | 1.0 | 37.8 | **8.4** |
| Swirl · Ring · Spread | 290.4 | **289.5** | 5.4 | 33.2 | **56.2** |
| Ring · Halo | 89.2 | **60.9** | 1.1 | 47.4 | **18.3** |
| Spread · Boomerang (2 cards) | — | 200.1 | 3.7 | — | 61.8 |
| Spread · Explosive (2 cards) | — | 195.6 | 3.7 | — | 43.6 |

| Wand (level 5, 6 dummies) | before | after |
|---|---|---|
| PF reference: Spread · Split · Explosive | 871.8 | 871.8 |
| Ring | 581.8 | 303.8 |
| Ring · Spread | 3,714.8 | 889.3 |
| Spread · Ring | 2,673.0 | 520.7 |
| Ring · Spread · Swirl | 1,352.6 | 235.4 |
| Swirl · Ring · Spread | 1,373.0 | 1,015.5 |
| Ring · Spread · Split | 3,911.2 | 956.8 |
| Spread · Ring · Split | 2,868.7 | 597.5 |
| Ring · Spread · Halo · Swirl · Echo | 418.8 | 134.1 |

Read: the Ring alone went from 7.2× the plain shot on the 6-dummy cluster to 1.9× (between Split and Spread, under
Boomerang), and from 1.6× to 1.1× on one target. The two-card ring orders sit at 4.4-5.6× the plain shot on the
cluster, **1.2-1.5× the two-card comparators (Spread · Boomerang 200.1, Spread · Explosive 195.6): still above them,
reported, not tuned further**; on one target they match or trail them (38.6-56.2 vs 43.6-61.8). At level 5 the
strongest ring order (Swirl · Ring · Spread 1,015.5; Ring · Spread · Split 956.8) is within ~16 % of the PF reference
build (871.8). The storm (Ring · Spread · Swirl) and Ring · Halo fire all round, so on a cluster in front of the hero
they are the weakest (52.1, 60.9); a horde round the hero is not measured. Order still matters: the five orders fight
differently (`test_the_five_orders_compile_and_fight_differently_and_replay`) and the table's rows differ.

### Raw output: frame cost, level 5, 6 dummies, sim + WorldView (the probe's rows: total, sim, sync, frame, rings, verdict)
Before (`586f7cc`):
```
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, ...  total_ms 7.544 14.945 23.572  verdict: avg 7.54 ms -> within  load: 3.35
perf_probe: gun + gun_ring, level 5, ...                                  total_ms 2.576  3.207  9.555  verdict: avg 2.58 ms -> within  load: 2.97
perf_probe: gun + gun_ring, gun_spread, level 5, ...                      total_ms 5.579  9.115 15.649  verdict: avg 5.58 ms -> within  load: 2.91
perf_probe: gun + gun_spread, gun_ring, level 5, ...                      total_ms 3.912  4.504  9.026  verdict: avg 3.91 ms -> within  load: 2.86
perf_probe: gun + gun_ring, gun_spread, gun_swirl, level 5, ...           total_ms 4.612  6.868 19.417  verdict: avg 4.61 ms -> within  load: 2.90
perf_probe: gun + gun_swirl, gun_ring, gun_spread, level 5, ...           total_ms 4.138  5.333 10.013  verdict: avg 4.14 ms -> within  load: 2.84
perf_probe: gun + gun_ring, gun_spread, split_shot, level 5, ...          total_ms 7.995 11.704 16.003  verdict: avg 7.99 ms -> within  load: 2.60
perf_probe: gun + gun_spread, gun_ring, split_shot, level 5, ...          total_ms 6.977 11.020 15.386  verdict: avg 6.98 ms -> within  load: 2.72
perf_probe: gun + gun_ring, gun_spread, halo_shot, gun_swirl, gun_echo, . total_ms 4.086  5.355  8.804  verdict: avg 4.09 ms -> within  load: 2.78
```
After:
```
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, ...  total_ms 6.589 11.516 18.126  verdict: avg 6.59 ms -> within  load: 2.84
perf_probe: gun + gun_ring, level 5, ...                                  total_ms 2.625  3.410  6.628  verdict: avg 2.62 ms -> within  load: 3.01
perf_probe: gun + gun_ring, gun_spread, level 5, ...                      total_ms 6.418  9.329 12.304  verdict: avg 6.42 ms -> within  load: 3.01
perf_probe: gun + gun_spread, gun_ring, level 5, ...                      total_ms 3.161  4.209 17.106  verdict: avg 3.16 ms -> within  load: 3.01
perf_probe: gun + gun_ring, gun_spread, gun_swirl, level 5, ...           total_ms 4.768  5.760 15.781  verdict: avg 4.77 ms -> within  load: 2.85
perf_probe: gun + gun_swirl, gun_ring, gun_spread, level 5, ...           total_ms 7.418 10.966 14.170  verdict: avg 7.42 ms -> within  load: 2.76
perf_probe: gun + gun_ring, gun_spread, split_shot, level 5, ...          total_ms 8.910 12.630 20.680  verdict: avg 8.91 ms -> within  load: 2.83
perf_probe: gun + gun_spread, gun_ring, split_shot, level 5, ...          total_ms 5.622  8.234 11.068  verdict: avg 5.62 ms -> within  load: 2.79
perf_probe: gun + gun_ring, gun_spread, halo_shot, gun_swirl, gun_echo, . total_ms 4.640  6.014  7.763  verdict: avg 4.64 ms -> within  load: 2.56
```
(Each line condensed by hand from the run's own lines: its header, its `total_ms avg p95 max` row, its verdict and
the load printed after it; the full rows with sim/sync/frame and rings are in the scratch output, not committed.
Rings alive after: Ring · Spread 42.7 avg / 48 max, the storm 44.3 / 48, Ring · Spread · Split 42.7 / 48 with 63.6
shards alive.)

**Frame result:** the worst order measured, Ring · Spread · Split at level 5, is **8.91 ms avg, within ~12 ms**; its
p95 **12.63 ms is over** the 12 ms line (the PF reference build's p95 is 11.52 ms in the same session), reported.
The before tree measured 7.99 ms avg for the same build in this session (AO's 13.36 ms was on a busier machine): the
travelling rings cost ~0.9 ms more on it, because a travelling ring lives ~2.5× as long as AO's cast circle, so the
48-ring cap is reached (22 before).

## Part B: loading covers and portal transitions

### What it does (`src/presentation/hud/loading_cover.gd`, `src/app/cover_loads.gd`, `Main`)
- **Play, Continue, Restart:** the screen goes black at once with a small turning loading mark in the bottom-right
  corner (no text); Main waits 2 frames so the cover is drawn, then builds the floor, and the cover fades out over
  0.45 s (it replaced the v0.3.0 fade-in). Any other `_start_floor` (the dev panel's Restart floor, the tools) starts
  covered and fades the same way.
- **A portal to another floor** (the gate, the Deep gate, the Ascension portal to the final arena, the Loop device):
  as the hero goes in (the sim's own way-in progress past 0.55, `WorldReader.portal_enter_progress`), an iris closes
  over the screen in that portal's colours and motion (gate: the visor-blue vortex; Deep: violet torn jagged with the
  red rim; Ascension: gold rays on lavender; Loop: green ripples). When the sim says the hero is through (outcome 3)
  the old floor holds, one frame draws the closed cover with the mark, the next floor loads under it, and the iris
  opens on the new floor over 0.55 s while the arrival column plays. A portal that ends the run (no next floor;
  `WorldReader.portal_loads()`) gets no cover, so the end panel shows. The shop and arena doors load nothing (they are
  rooms of the same floor), so they get no cover.
- **Reduced motion:** a plain fade in the cover's colour; the mark breathes instead of turning.
- Presentation only: the cover reads the sim's progress and its own screen clock; the sim's ticks and outcomes are
  unchanged (the portal's way in is BossFlow's 60 ticks as before; the floor loads one frame after outcome 3 instead of
  in the same frame). The floor build itself still runs on the main thread (no threads): the screen is the cover while
  it runs, the mark is still for that frame.

### Shots (Xvfb + llvmpipe)
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/loading_cover.gd [-- --deep]
loading_cover: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
loading_cover: res://build/shots/v0.7.5-dev/loading/gate_1_new_run_black.png phase=2 style=0 amount=1.00 mark=true floor=-
loading_cover: res://build/shots/v0.7.5-dev/loading/gate_2_iris_closing.png phase=1 style=1 amount=0.48 mark=false floor=1
loading_cover: res://build/shots/v0.7.5-dev/loading/gate_3_closed_loading.png phase=2 style=1 amount=1.00 mark=true floor=1
loading_cover: res://build/shots/v0.7.5-dev/loading/gate_4_opening_floor_2.png phase=3 style=1 amount=0.58 mark=false floor=2
loading_cover: res://build/shots/v0.7.5-dev/loading/deep_1_new_run_black.png phase=2 style=0 amount=1.00 mark=true floor=-
loading_cover: res://build/shots/v0.7.5-dev/loading/deep_2_iris_closing.png phase=1 style=2 amount=0.48 mark=false floor=1
loading_cover: res://build/shots/v0.7.5-dev/loading/deep_3_closed_loading.png phase=2 style=2 amount=1.00 mark=true floor=1
loading_cover: res://build/shots/v0.7.5-dev/loading/deep_4_opening_floor_2.png phase=3 style=2 amount=0.58 mark=false floor=2
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_order.gd
attack_order: res://build/shots/v0.7.5-dev/ring/1_plain_shot.jpg (tick 24, 0 rings alive, 0 arcs laid)
attack_order: res://build/shots/v0.7.5-dev/ring/2_ring.jpg (tick 20, 3 rings alive, 0 arcs laid)
attack_order: res://build/shots/v0.7.5-dev/ring/3_ring_spread.jpg (tick 20, 7 rings alive, 77 arcs laid)
attack_order: res://build/shots/v0.7.5-dev/ring/4_spread_ring.jpg (tick 20, 3 rings alive, 0 arcs laid)
attack_order: res://build/shots/v0.7.5-dev/ring/5_ring_spread_swirl.jpg (tick 34, 8 rings alive, 60 arcs laid)
attack_order: res://build/shots/v0.7.5-dev/ring/6_swirl_ring_spread.jpg (tick 20, 9 rings alive, 135 arcs laid)
attack_order: res://build/shots/v0.7.5-dev/ring/7_ring_halo.jpg (tick 16, 6 rings alive, 69 arcs laid)
```
Copied to [`n3_shots/`](n3_shots/) (the PNGs as JPEG): `ring_1_plain_shot.jpg` … `ring_7_ring_halo.jpg` (each order
mid-flight), `gate_1_new_run_black.jpg` (the black cover and the corner mark), `gate_2_iris_closing.jpg` and
`deep_2_iris_closing.jpg` (the two portal transitions mid-way: the gate's blue vortex, the Deep gate's violet and red),
`gate_3_closed_loading.jpg`, `gate_4_opening_floor_2.jpg`, `deep_3_closed_loading.jpg`, `deep_4_opening_floor_2.jpg` (the Deep run walked into floor 1's real Deep gate; its black start shot is the same as the gate run's and is not copied). The hints and the achievement
toast draw over the cover (they did over the fade-in too). How it looks in motion: OWNER ONLY.

## Tests (the commands and their totals; `scratchpad/n3/gut.sh` runs the GUT line shown)
```
gdformat --check src scripts tests && gdlint src scripts tests
-> 978 files would be left unchanged / Success: no problems found   (final run, see below)
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/content,res://tests/golden,res://tests/unit/application -ginclude_subdirs -gexit
-> Scripts 42, Tests 237, Passing 235, Failing 2 (test_layering: loading_cover.gd's shader text named "Ascension";
   test_item_validation: the new Ring/Swirl descriptions over 60 characters). Fixed; the two files re-run below.
godot ... -gtest=<14 sim files: test_attack_order, test_modifier_smoke, test_mx4_modifiers, test_mx4_modifiers_2, test_modifier_abilities, test_gun_pool, test_gun_pool_order, test_wand_compile, test_wand_order_fight, test_world_snapshot, test_player_builds, test_rewards, test_wand_preview, test_wand_smoke> -gexit
-> Scripts 14, Tests 176, Passing 176, Asserts 18499, Time 651.51s
godot ... -gtest=<14 e2e files: attack_order, gun_pool, wand_build, wand_shared, damage_soak, run_flow, saves, ascension, routes, pad_menus, portal, loading_cover, final_boss, after_boss> -gexit
-> Scripts 14, Tests 24, Passing 23, Failing 1: test_e2e_saves test_quit_mid_room_and_continue_at_its_entry
   ("Continue starts the saved run" at line 98: it read the world in the frame Enter was pressed; the load now waits
   behind the cover). The test (and test_e2e_old_save, same pattern) now waits for the build frame and reads the world
   before its first tick, as before.
godot ... -gtest=test_e2e_saves, test_e2e_old_save, test_loading_cover (presentation), test_layering, test_item_validation, test_locale_coverage, test_e2e_shell, test_e2e_dev_master_panel -gexit
-> Scripts 8, Tests 25, Passing 25, Asserts 16405, Time 65.565s
godot ... -gtest=res://tests/unit/sim/test_modifier_equivalence.gd -gexit   (the golden equivalence, unchanged fixture)
-> Passing Tests 3, Asserts 68, Time 8.512s
godot ... -gtest=res://tests/unit/sim/test_attack_order.gd -gexit   (after the last gdformat)
-> Passing Tests 19, Asserts 142
```
Not run: the full suite, the bot tests (owner rule), the rest of `tests/unit/sim` and `tests/unit/presentation`
(only the files above).

## Interpretation
- O47 is built: the Ring is the shot, it flies and hits what it passes; the order rule holds with new meanings for the
  pulses (a carrier ring) and both Swirls (a storm of travelling rings; a spinning group). The retune brought the Ring
  from 7× the plain shot to Spread's and Split's level on a cluster; the two-card orders are still above the two-card
  comparators on a tight cluster (reported, D45).
- O45 is built for every floor load and every portal that loads; it hides the build, it does not make it faster.
- Not proved: the feel, the look in motion, fps on the owner's PC (OWNER ONLY).
