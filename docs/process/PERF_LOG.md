# Logging a normal game (perf log)

v0.10.5 (owner: "play a normal game, log it and then you can measure what takes the most frames"). The game records
every rendered frame to a CSV while you play; a script turns the CSV into a short report of what cost the frames.

## 1. Launch with the flag

Everything after `--` goes to the game. Two modes:

| Flag | What each frame records |
|---|---|
| `--perf-log=light` | the frame time, the sim ticks run that frame, the load (live enemies, hero and enemy projectiles, drawn effects, boss alive and its phase), the scene (menu, hub, loading, run, training, playground), the floor and biome; every 2 s the node count, draw calls, primitives, objects drawn, video memory |
| `--perf-log` | all of that, plus the frame probe's breakdown: the sim's step and its phases, each view's sync, every SimDriver listener, the rest of the script time, and what is left over (the engine and the draw) |

Light costs less; use the full mode to find out *what* is slow. With no flag nothing records and nothing is slower.

**Git Bash** (from the project folder; `godot` is Godot 4.7.2):

```bash
godot --path . -- --perf-log
godot --path . -- --perf-log=light
```

**PowerShell**:

```powershell
godot --path . -- --perf-log
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --perf-log=light
```

An exported build takes the same flag: `"Zero Depth.exe" -- --perf-log`.

While it records, the top-right corner shows **● PERF**. Press **F9** when something feels bad: the corner flashes
"mark N" and the frame is marked in the CSV. F9 does nothing when the game isn't recording.

Play normally (about 10 minutes is plenty), then quit from the menu or close the window.

## 2. Where the CSV lands

`%APPDATA%\Godot\app_userdata\Zero Depth\perf\perf_<date>_<time>.csv`, for example
`C:\Users\<you>\AppData\Roaming\Godot\app_userdata\Zero Depth\perf\perf_20261102_201500.csv`. The game also prints
the full path to the console when it starts recording. Each launch writes a new file.

The rows are written in the background every couple of seconds, when you return to the menu and when you quit, so
a crash loses at most the last two seconds. A 10-minute full log at 144 fps is about 86,000 rows.

## 3. Summarize it

```bash
python scripts/perf/summarize_perf.py "$APPDATA/Godot/app_userdata/Zero Depth/perf/perf_20261102_201500.csv"
```

```powershell
python scripts\perf\summarize_perf.py "$env:APPDATA\Godot\app_userdata\Zero Depth\perf\perf_20261102_201500.csv"
```

It writes `build/perf/<csv name>_summary.md` (about 150 lines) and prints its top lines:
- the totals per scene and floor (avg / p50 / p95 / p99 / max ms, fps);
- the 50 worst frames, each with its top 5 costs and its load;
- the stutter clusters (bursts over 33 ms and over 50 ms: when, how long, what dominated);
- the frame time against the enemy count and the projectile count;
- the top costs over the run, split into sim / views / listeners / other script / engine+draw;
- a ±2 s window round each F9 mark, with what dominated it.

`python scripts/perf/summarize_perf.py --self-check` tests the script on a generated 40,000-row CSV.

## Notes

- The breakdown's buckets nest: `view.*` and `actors.*` sit inside the views' sync, `phase.*` inside `sim_step`.
  The five-part split (sim / views / listeners / other script / engine+draw) does not overlap.
- In the Playground the full mode skips the per-listener timing (its biome switch reconnects the view's listeners);
  everything else is recorded.
- The recorder is app-side (`src/app/perf_recorder.gd`); the shared breakdown (`src/app/perf_breakdown.gd`) is the
  same code the frame probe's `--breakdown` uses.
