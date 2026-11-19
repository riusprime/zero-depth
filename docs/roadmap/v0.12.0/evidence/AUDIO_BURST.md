# AUDIO_BURST: what a burst of sounds costs the frame, before and after the sounds load ahead and play from a pool

- **Status:** RUN (headless, Dummy audio driver: the director's own work, not the mixing)
- **Build:** before `80694620` (`claude/v0120`); after: Step 34's commit on `v0120-s34` (parent `80694620`); Godot
  `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200
- **Machine:** the owner's PC (i7-10700K, RTX 3060), driven by an agent; one Godot process at a time; another agent
  may have been editing files meanwhile, no other Godot ran during the probes
- **Date:** 2026-11-19
- **Who ran it:** agent

## What the owner's log showed

`build/perf/perf_20261119_090644_summary.md` (the owner's 30-minute log): `tick.audio_director.gd.sync` 263 us/frame on
average, max 24.2 ms. A streaming read of the raw CSV (125,028 frames, 88,673 with the bucket) counted 77 frames over
3 ms, nearly all 11 to 18 ms, spread across the whole run (70 s to 1764 s), many with 0 to 5 enemies. The game has 134
cues; each cue's stream was loaded on its first play, in the frame (`stream_for` → `load`), so a spike per cue heard
for the first time matches what the log shows. Every play also made a new player node and freed it later.

## Command

```
godot --headless --path . -s scripts/bench/audio_burst_probe.gd
```

The probe boots a director as Main does, plays 45 distinct world cues in one frame (the first time any of them
plays), the same 45 again once they have ended, then 200 plays over 200 frames, counting the nodes added to the tree.

## Before (`80694620`), two runs

```
audio_burst_probe: 134 cues, burst of 48 sfx cues
boot (new + add_child) 128.84 ms, warm-up finish 0.00 ms
burst (first plays): 45 played in one frame, 67.87 ms, nodes created 45
burst (again): 45 played in one frame, 0.93 ms, nodes created 45
200 plays over 200 frames: 19.27 ms in all, worst frame 1.787 ms, nodes created 390
```
```
audio_burst_probe: 134 cues, burst of 48 sfx cues
boot (new + add_child) 130.09 ms, warm-up finish 0.00 ms
burst (first plays): 45 played in one frame, 69.50 ms, nodes created 45
burst (again): 45 played in one frame, 0.96 ms, nodes created 45
200 plays over 200 frames: 19.92 ms in all, worst frame 1.820 ms, nodes created 390
```

## After (Step 34), two runs

```
audio_burst_probe: 134 cues, burst of 48 sfx cues
boot (new + add_child) 210.72 ms, warm-up finish 0.48 ms
burst (first plays): 45 played in one frame, 0.83 ms, nodes created 0
burst (again): 45 played in one frame, 0.88 ms, nodes created 0
200 plays over 200 frames: 10.99 ms in all, worst frame 0.119 ms, nodes created 0
```
```
audio_burst_probe: 134 cues, burst of 48 sfx cues
boot (new + add_child) 209.46 ms, warm-up finish 0.47 ms
burst (first plays): 45 played in one frame, 0.81 ms, nodes created 0
burst (again): 45 played in one frame, 0.72 ms, nodes created 0
200 plays over 200 frames: 11.87 ms in all, worst frame 0.168 ms, nodes created 0
```

## Reading

- A burst of first plays: 68–70 ms → 0.8 ms; no node made per sound (45 → 0, 390 → 0 over 200 plays).
- The cost moved to boot: +80 ms once, when Main adds the director at launch, before the menu (the loads requested
  on a loader thread, the 80 pooled players made). A floor's build waits for any load still running, behind its cover.
- The in-game effect on the owner's spikes: NOT YET RUN (owner hardware: a new perf log of a normal run).
