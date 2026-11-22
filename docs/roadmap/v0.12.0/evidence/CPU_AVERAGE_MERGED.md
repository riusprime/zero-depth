# CPU_AVERAGE_MERGED: steps 48-50 merged, before and after on a quiet machine

- **Status:** RUN
- **Build:** before `0f298c3d` (`src/` and `scripts/` checked out from it in the lead's worktree); after `e746d4eb`
  (branch `lead-v0120`, steps 48, 49, 50 merged); the debug native library (no native change); Godot `4.7.2.stable`.
- **Machine:** the owner's PC (i7-10700K, RTX 3060), driven by the lead; no other Godot process before or after any run
  (`tasklist | grep -ci godot` = 0 every time). **Date:** 2026-11-22. **Who ran it:** the lead.

Command (each run, alternating after, base, after, base per biome):
```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-lead "$GODOT" --path . --gpu-profile --resolution 2560x1440 --windowed \
  --position -10000,-10000 -s scripts/checks/floor_fight_probe.gd -- --biome=<b> --seed=4404 --secs=90 --perf-log
python -I scripts/perf/summarize_perf.py "<perf csv>"
```

| run | log | frame avg ms | p99 | process step ms | of which views' sync + listeners | other nodes' `_process` | physics steps | GPU ms |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| after 1, Red Canyon | perf_20261122_144622 | 8.58 | 24.48 | 3.75 | 1.56 | 2.19 | 0.83 | 6.15 |
| base 1, Red Canyon | perf_20261122_144900 | 8.60 | 21.29 | 3.79 | 1.57 | 2.22 | 0.82 | 6.17 |
| after 2, Red Canyon | perf_20261122_145133 | 8.70 | 21.93 | 3.74 | 1.60 | 2.14 | 0.86 | 6.28 |
| base 2, Red Canyon | perf_20261122_145407 | 8.71 | 21.61 | 3.84 | 1.60 | 2.24 | 0.84 | 6.29 |
| after 1, Night Rocks | perf_20261122_145640 | 9.12 | 26.19 | 3.88 | 1.65 | 2.23 | 0.90 | 6.82 |
| base 1, Night Rocks | perf_20261122_145913 | 9.14 | 23.88 | 4.03 | 1.70 | 2.32 | 0.91 | 6.79 |
| after 2, Night Rocks | perf_20261122_150146 | 8.72 | 23.31 | 3.71 | 1.56 | 2.15 | 0.85 | 6.62 |
| base 2, Night Rocks | perf_20261122_150419 | 9.09 | 25.25 | 4.02 | 1.68 | 2.34 | 0.90 | 6.71 |

- **The process step is 0.05-0.10 ms shorter in Red Canyon and 0.15-0.31 ms shorter in Night Rocks** after the merge,
  in every pair. The average frame moves by less than that (0.01-0.37 ms) because the probe's frame is not CPU-bound
  (it waits in the draw 40-44 % of frames; the probe's fights are lighter than the owner's play: process step 3.8 ms
  here against 6.43 ms in the owner's log).
- The probe drives a seeded floor on the frame clock, so a run's fights are not identical; the p99 moves either way.
- Owner-only: the frame in the owner's own play after this merge (their next `--perf-log`): OWNER ONLY.
