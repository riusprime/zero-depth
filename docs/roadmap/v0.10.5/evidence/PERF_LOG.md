# v0.10.5 evidence: the perf recorder (--perf-log) and its summary

Machine: the owner's PC (i7-10700K, RTX 3060), 2026-11-02, Godot 4.7.2, branch `v0105-perflog`.
Build: `5f861d50` plus the follow-up commit that adds the `rec_us` column (the recorder's own time); the smoke
runs below ran on that working tree before it was committed.

## Tests run

| Check | Command | Result |
|---|---|---|
| Lint | `gdformat --check src scripts tests && gdlint src scripts tests` | `1578 files would be left unchanged`, `Success: no problems found` |
| Recorder unit + arch + tests/unit/app | `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/unit/app -ginclude_subdirs -gexit` | 22/22 passed (6 scripts; before `rec_us`) |
| Perf-log e2e + run flow e2e | `... -gtest=res://tests/e2e/test_e2e_perf_log.gd,res://tests/e2e/test_e2e_run_flow.gd -gexit` | 4/4 passed (before `rec_us`) |
| After `rec_us` | `... -gtest=res://tests/unit/app/test_perf_recorder.gd,res://tests/e2e/test_e2e_perf_log.gd -gexit` | 6/6 passed |
| Summarizer self-check | `python scripts/perf/summarize_perf.py --self-check` | `self-check OK` (40,000-row full CSV: 119 lines in 0.57 s; light: 107 lines in 0.28 s) |
| tests/arch and test_e2e_run_flow after `rec_us` | — | NOT YET RUN (owner: stop running tests) |
| frame_probe `--breakdown` after the PerfBreakdown move | — | NOT YET RUN (the code moved unchanged; not run rendered) |
| The owner's ~10-minute logged game | — | OWNER ONLY |

## Smoke: a logged frame-probe run (rendered, off screen)

The frame probe's Playground scenario (20 enemies, the multi-hit build, vsync off) with the recorder on through
Main's flag. Both runs had finished when the owner asked to stop running tests; no further runs were started.

```bash
APPDATA=$(mktemp -d) godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 \
  -s scripts/checks/frame_probe.gd -- --biome=frozen_shore --secs=30 --perf-log=light   # and --perf-log
python scripts/perf/summarize_perf.py build/perfstep/p2_light/perf_20261102_134435.csv
python scripts/perf/summarize_perf.py build/perfstep/p2_full/perf_20261102_134542.csv
```

Light, the first lines of the real summary:

```
# Perf log perf_20261102_134435

2365 frames over 48.2 s, light log (perf_20261102_134435.csv), 0 F9 marks. Times in ms unless marked.

The recorder's own main-thread time: mean 62 us, p99 106 us a frame.

## Totals per scene and floor

| scene / floor | frames | avg | p50 | p95 | p99 | max | fps |
|---|---:|---:|---:|---:|---:|---:|---:|
| menu | 4 | 54.93 | 3.75 | 145.30 | 145.30 | 145.30 | 18 |
| playground | 2361 | 20.35 | 13.75 | 21.67 | 29.73 | 13743.91 | 49 |
```

Full, the first lines and the cost split:

```
# Perf log perf_20261102_134542

2033 frames over 48.7 s, full log (perf_20261102_134542.csv), 0 F9 marks. Times in ms unless marked.

The recorder's own main-thread time: mean 226 us, p99 463 us a frame.

## Totals per scene and floor

| scene / floor | frames | avg | p50 | p95 | p99 | max | fps |
|---|---:|---:|---:|---:|---:|---:|---:|
| menu | 4 | 58.20 | 3.05 | 166.97 | 166.97 | 166.97 | 17 |
| playground | 2029 | 23.93 | 15.78 | 26.23 | 36.60 | 14144.04 | 42 |

| part | mean us/frame | share | p99 us |
|---|---:|---:|---:|
| sim | 1741 | 7% | 6229 |
| views | 3439 | 14% | 8206 |
| listeners | 609 | 3% | 1357 |
| other script | 63 | 0% | 184 |
| engine+draw (unaccounted) | 18175 | 76% | 22137 |
```

Reading it honestly:
- The ~14 s max frame is the Playground's room build on the main thread (the probe opens it directly); it inflates
  the averages and the engine+draw mean. The p50 / p95 are the useful numbers here.
- `rec_us` is the recorder's own `_process` (the row, the flush hand-off). It leaves out the full mode's extra
  costs elsewhere: the PerfMarks stamps, the timed listeners, the views' sync timing. A rough A/B on the same probe
  (no log 16.41 ms avg, light 15.30, full 14.66, earlier runs) was inside the run-to-run noise, so the overhead is
  not resolved by it.
- Timing under a busy machine is noise (CLAUDE.md); the owner's own logged game is the measurement.
