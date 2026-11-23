# Every model kind in the native batch: before and after (2026-11-22/23)

Owner's PC (i7-10700K, RTX 3060). The runs went one after another, each its own command, with 0 Godot processes
before and after every run (the owner: "let's do 1 by one").

- **After:** `lead-v0120` at `4303ab2c`, steps 51-69 merged (worktree `wt-lead`).
- **Base:** `e1c0a233`, before step 51 (worktree `wt-base51`, its own library built with `ensure.sh`).

## 1. The floor-fight runs: not able to tell

`floor_fight_probe.gd --seed=4404 --secs=90 --perf-log`, 2560x1440, base and after alternated.

- **Not enough enemies:** these floors average 5-7 enemies on screen and never reach 20, so the work in this pass,
  which scales with the number of model enemies, has nothing to act on.
- **Too much spread:** the spread between two runs of the same tree is about ±1 ms. For example, Night Rocks after
  13.65 / 15.02 ms against base 14.24 / 13.11 ms.

So they neither show nor rule out a gain. The rest of the biomes were stopped at the owner's word, and the CSVs are
kept untracked in the lead's scratchpad.

## 2. The 42-enemy mixed fights

The command, the same as `HEAVY_FIGHTS.md`:

```
godot --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --enemies=42 --secs=30 --warm=5 --size=2560x1440 --spans --biome=<b> --kinds=<roster>
NR: --biome=night_rocks  --kinds=charger,needle,swarmer,warden,rock_lurker,stone_thrower
FS: --biome=frozen_shore --kinds=charger,needle,swarmer,warden,frost_spitter,glacier_turtle
```

Raw lines, in the order they ran:

```
after1_NR 4303ab2c  frames=2301  avg_ms=13.044  p50_ms=12.423  p95_ms=18.625  p99_ms=22.047
  spans: probe_script=106  nodes_process=5741  after_process=1246  draw=4139  after_draw=336  physics_pre=22  nodes_physics=1381  physics_post=72
  render_cpu_ms_avg=1.115  render_gpu_ms_avg=10.565   actor view nodes total=231 batched_enemies=43
base1_NR e1c0a233   frames=1718  avg_ms=17.466  p50_ms=17.250  p95_ms=24.494  p99_ms=31.189
  spans: probe_script=130  nodes_process=9384  after_process=1722  draw=3441  after_draw=645  physics_pre=32  nodes_physics=1933  physics_post=180
  render_cpu_ms_avg=1.223  render_gpu_ms_avg=9.769    actor view nodes total=611 batched_enemies=7
after2_NR 4303ab2c  frames=2208  avg_ms=13.591  p50_ms=13.269  p95_ms=19.413  p99_ms=25.743
  spans: probe_script=113  nodes_process=6142  after_process=1360  draw=4055  after_draw=304  physics_pre=24  nodes_physics=1515  physics_post=79
  render_cpu_ms_avg=1.145  render_gpu_ms_avg=10.377   actor view nodes total=246 batched_enemies=42
base2_NR e1c0a233   frames=1552  avg_ms=19.336  p50_ms=18.888  p95_ms=26.360  p99_ms=31.977
  spans: probe_script=143  nodes_process=10329  after_process=1921  draw=3789  after_draw=723  physics_pre=39  nodes_physics=2173  physics_post=219
  render_cpu_ms_avg=1.353  render_gpu_ms_avg=11.686   actor view nodes total=575 batched_enemies=12
after1_FS 4303ab2c  frames=1879  avg_ms=15.968  p50_ms=15.718  p95_ms=20.808  p99_ms=24.669
  spans: probe_script=125  nodes_process=7796  after_process=1787  draw=3920  after_draw=780  physics_pre=30  nodes_physics=1431  physics_post=99
  render_cpu_ms_avg=1.319  render_gpu_ms_avg=10.874   actor view nodes total=231 batched_enemies=41
base1_FS e1c0a233   frames=1646  avg_ms=18.237  p50_ms=18.035  p95_ms=24.410  p99_ms=29.179
  spans: probe_script=137  nodes_process=9956  after_process=1878  draw=3692  after_draw=677  physics_pre=33  nodes_physics=1670  physics_post=195
  render_cpu_ms_avg=1.297  render_gpu_ms_avg=10.551   actor view nodes total=456 batched_enemies=8
after2_FS 4303ab2c  frames=2525  avg_ms=11.883  p50_ms=11.437  p95_ms=16.189  p99_ms=19.651
  spans: probe_script=104  nodes_process=5452  after_process=813  draw=4165  after_draw=435  physics_pre=16  nodes_physics=843  physics_post=55
  render_cpu_ms_avg=0.900  render_gpu_ms_avg=9.761    actor view nodes total=195 batched_enemies=42
base2_FS e1c0a233   frames=1865  avg_ms=16.088  p50_ms=16.271  p95_ms=22.039  p99_ms=26.837
  spans: probe_script=124  nodes_process=9066  after_process=1596  draw=3415  after_draw=304  physics_pre=26  nodes_physics=1409  physics_post=150
  render_cpu_ms_avg=1.187  render_gpu_ms_avg=9.805    actor view nodes total=437 batched_enemies=8
```

| 42 enemies, mixed roster | Base (ms a frame) | After (ms a frame) | Scripts a frame (base → after) | p99 (base → after) |
|---|---|---|---|---|
| Night Rocks | 17.47 / 19.34 | 13.04 / 13.59 | 9.4-10.3 → 5.7-6.1 ms | 31.2-32.0 → 22.0-25.7 ms |
| Frozen Shore | 18.24 / 16.09 | 15.97 / 11.88 | 9.1-10.0 → 5.5-7.8 ms | 26.8-29.2 → 19.7-24.7 ms |

- **Night Rocks:** about 5 ms a frame less, from about 54 to about 75 fps.
- **Frozen Shore:** 2-4 ms a frame less. Its runs spread more on both trees (the FS after runs 15.97 and 11.88), so its
  gain is less sure than Night Rocks'.
- **Node tree:** the actors' view holds 195-246 nodes after, against 437-611 before.
- **What holds the frame now:** the graphics card's time is about the same (9.8-11.7 ms before, 9.8-10.9 after) and
  is now close to the frame, so in these fights it becomes the next limit.

## 3. Not run here

- The twin probe per kind on the merged tree.
- A seeded twin for the Rock Lurker's and the Scrap Hound's "frames over the threshold" readings, and the Gravity
  Node's disc.
- The other three biomes' mixed fights.
- The owner's play test (OWNER ONLY).
