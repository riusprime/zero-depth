# v0.10.5 O4 — the intensity director reads how you're doing

Owner line **D46** (2026-11-01): "sometimes it feels like it is not working and on some occasions it feels overcrowded
if you are weak, could we also adjust it to not make it unfair based on the strength?" → chose **"Read your state
live"**. Overnight mode ("Pick and build"): every call below is the agent's, built as a starting value.

Build: worktree `wt-o4`, branch `v0105-o4` cut from `74075798`. "Before" ran on `74075798` with only the new probe
script added (no `src/` change); "after" on the same tree with this step's changes, uncommitted when it ran; the step's
commit is the one that adds this file. Godot 4.7.2.stable.official.ed1daf0bf, headless, the owner's PC (Windows 11).

## The probe (scripted sim, not the bot suite)

`scripts/checks/director_fairness.gd` (new): floor 1 of each run seed as Main builds it (`SaveLab.floor_world`, Blade),
FightBot's input held within 5 m of its start (as N5's `intensity_curve.gd`), 300 s of floor time, HP topped up to full
between ticks when under 15 %. Three heroes that differ only in the damage stat: **weak** 400 ‰, **expected** 1000 ‰,
**strong** 2500 ‰. Every 5 s it logs the state, intensity, alive / cap, kills, HP and kills in the last 10 s; per run
it sums the peaks, each quiet's length (director ticks) and how it ended, the build-ups, pull back's ends, alive means.

```
godot --headless --path . -s scripts/checks/director_fairness.gd -- seeds=11,12,13,14,15 seconds=300 log=1
```

Quiet labels: `drawn` = ended on its drawn length; `max` = ran ≥ 20 s (`quiet_ticks_max`). Before, a quiet reaching
20 s was always the forced end. After, no quiet runs past its draw; a `max` there is a struggling quiet (× 1.5 of a
draw, up to 30 s). The script's label wasn't changed between the runs.

## 1. "Not working": what the director did before (raw, `74075798`)

```
RUN 11 weak     | peaks 7 at s [52.6, 91.1, 127.6, 167.4, 210.7, 246.6, 284.8] | quiets [20.0 max, 20.0 max, 20.0 max, 20.0 max, 20.0 max, 20.0 max] | build-ups s [52.6, 13.5, 5.7, 8.8, 8.6, 3.4, 6.5], open 21.7 | pull back ["near", "timeout", "timeout", "timeout", "timeout", "timeout", "timeout"]
RUN 12 expected | peaks 7 at s [44.2, 92.9, 132.0, 171.8, 209.4, 247.8, 287.7] | quiets [20.0 max, 20.0 max, 20.0 max, 20.0 max, 20.0 max, 20.0 max] | build-ups s [44.2, 19.1, 9.6, 9.1, 4.4, 5.8, 7.7], open 20.1 | pull back ["timeout", "timeout", "timeout", "timeout", "timeout", "timeout", "timeout"]
MEAN weak     | kills/min 17.8 | alive 17.0 | quiet mean s 20.0 (30 quiets, 30 forced at max) | runs with no quiet 0
MEAN expected | kills/min 26.2 | alive 15.7 | quiet mean s 20.0 (29 quiets, 29 forced at max) | runs with no quiet 0
MEAN strong   | kills/min 30.1 | alive 14.6 | quiet mean s 20.0 (29 quiets, 29 forced at max) | runs with no quiet 0
```

The curve, seed 11, weak hero (every 5 s, raw):

```
LOG 11 weak     |  95 s | PEAK  | int  937 | alive 17/18 | kills   20 | hp  81 % | kills 10 s  5
LOG 11 weak     | 100 s | QUIET | int 1000 | alive 15/23 | kills   22 | hp  72 % | kills 10 s  6
LOG 11 weak     | 105 s | QUIET | int 1000 | alive 14/23 | kills   23 | hp  72 % | kills 10 s  3
LOG 11 weak     | 110 s | QUIET | int 1000 | alive 14/23 | kills   23 | hp  58 % | kills 10 s  1
LOG 11 weak     | 115 s | QUIET | int 1000 | alive 14/23 | kills   25 | hp  46 % | kills 10 s  2
LOG 11 weak     | 120 s | QUIET | int  998 | alive 12/23 | kills   27 | hp  34 % | kills 10 s  4
LOG 11 weak     | 125 s | BUILD | int  497 | alive 22/23 | kills   27 | hp  18 % | kills 10 s  2
LOG 11 weak     | 130 s | PEAK  | int  869 | alive 23/23 | kills   27 | hp  72 % | kills 10 s  0
```

The cases found:

1. **Quiet never relaxed: 88 of 88 quiets (every seed, every hero) ran to the forced 20 s end.** Leftovers the hero
   can't clear keep intensity at 1000 the whole quiet, so the drawn 10–20 s never matters (N5 saw the same).
2. **The quiet isn't quiet.** No new packs, but the room stays 12–17 alive of a cap of 18–23 through it: the mean
   alive count overall (17.0 / 15.7 / 14.6) is no lower than while packs may come (15.4 / 15.1 / 14.5). The rhythm is
   barely visible as a crowd change — the likeliest "it feels like it's not working".
3. **The build-up doesn't build: it refills in a burst.** The interval clock runs down to 0 during the quiet, so the
   first build-up tick sends a pack at once, then every 0.4 × interval: 12 → 22 alive in 5 s above. Intensity then
   starts at 400 with leftovers still close, so the peak follows 3–19 s later (most 4–10 s).
4. **Pull back ends on its 4 s timeout in 90 of 97 cases** (`pull back` lists; after: 83 of 106): leftovers stay within 8 m.
5. **A weak hero sits in a fuller room** (alive 17.0 vs 14.6 for the strong one) with the same rhythm: this is D46's
   "overcrowded if you are weak".
6. No run went without a quiet, and none stayed stuck in a state (the N5 20 s upper end holds).

## 2. The build

Sim: `src/sim/world/intensity.gd`, `intensity_state.gd`, `intensity_table.gd`; one line in
`SpawnDirector._spawn_pack` (`Intensity.pack_size`, after the phase's pack cap; nothing else in the spawner);
`IntensityState`'s new fields in `WorldSnapshot.ADDED_SINCE_V05`; data `data/spawning/intensity.tres`; contracts
SIM_CONTRACTS §11, CONTENT_SCHEMA §7.

- **Live state.** `IntensityState.kill_ring`: the kills of each of the last 10 one-second slots of fighting (director
  ticks outside QUIET; kills in a quiet or in a gap such as an arena are dropped; the floor's first read only syncs).
  Saved, loaded and hashed with the rest of the director state; an older save loads with an empty window.
- **STRUGGLING**: HP < 40 % of max, **or** (with a full 10 s window and at least 4 enemies alive) the window's kills
  < 50 % of the expected. Expected kills in 10 s = the cap now × 200 ‰ (an 18 cap expects 3.6; picked from the
  expected hero's ~26 kills/min with caps of 18–23 before).
- **STRONG**: HP > 70 % and kills ≥ the expected (before a full window: HP alone) → the build-up as before.
  **BETWEEN** → as before.
- **A struggling hero** gets: the peak at intensity 600 instead of 750 (quiet sooner), the peak's clock at × 2 (it
  ends sooner), a quiet that begins while struggling × 1.5 of its draw (15–30 s), and packs capped at the row's largest
  (its fixed pack, or the floor's `pack_max`) − 1, at least 1.
- **The "not working" fixes** (agent's calls): (a) the quiet ends on its drawn time (it no longer waits for intensity
  to relax; intensity then drops to 400 at most, as the forced end did) — the owner's O58 wording "10 to 20 seconds of
  quiet. Then it builds again"; (b) the build-up's first pack waits one build-up interval instead of arriving the tick
  the quiet ends.
- Every threshold is a field of `IntensityDirectorDefinition` with a `# starting value (owner D46, 2026-11-01)`
  comment, so the dev panel's Difficulty group (its `data/spawning` folder) lists and tunes them with the director's
  other values. F10 → Tools shows "… struggling" / "… strong" after the intensity readout.

## 3. After (raw, same command)

```
RUN 11 weak     | peaks 8 at s [52.6, 73.1, 113.5, 143.2, 178.8, 210.6, 252.6, 295.7] | quiets [11.0 drawn, 19.8 drawn, 15.0 drawn, 22.6 max, 18.5 drawn, 28.6 max, 29.3 max] | build-ups s [52.6, 5.6, 14.0, 4.8, 1.7, 4.0, 2.7, 2.1], open 6.4 | pull back ["near", "near", "timeout", "timeout", "timeout", "timeout", "timeout"]
RUN 11 strong   | peaks 8 at s [61.9, 99.8, 132.0, 161.3, 188.6, 216.4, 260.4, 293.0] | quiets [16.4 drawn, 19.8 drawn, 15.0 drawn, 15.1 drawn, 12.3 drawn, 28.6 max, 19.5 drawn] | build-ups s [61.9, 17.3, 7.8, 4.1, 6.7, 7.3, 6.4, 8.1], open 15.1 | pull back ["near", "near", "timeout", "near", "timeout", "near", "near", "near"]
MEAN weak     | kills/min 16.1 | alive 16.4 | quiet mean s 20.5 (32 quiets, 15 forced at max) | runs with no quiet 0
MEAN expected | kills/min 23.2 | alive 14.7 | quiet mean s 19.3 (33 quiets, 12 forced at max) | runs with no quiet 0
MEAN strong   | kills/min 29.2 | alive 13.6 | quiet mean s 18.7 (33 quiets, 11 forced at max) | runs with no quiet 0
```

Per run (raw, kills and alive; after also the director ticks spent between / struggling / strong):

```
before
RUN 11 weak     | kills 77 (15.4/min) | alive mean 17.8, while sending 15.4
RUN 11 expected | kills 119 (23.8/min) | alive mean 16.3, while sending 15.9
RUN 11 strong   | kills 115 (23.0/min) | alive mean 15.9, while sending 15.1
RUN 12 weak     | kills 101 (20.2/min) | alive mean 16.4, while sending 15.5
RUN 12 expected | kills 152 (30.4/min) | alive mean 14.4, while sending 15.3
RUN 12 strong   | kills 186 (37.2/min) | alive mean 12.7, while sending 13.6
RUN 13 weak     | kills 83 (16.6/min) | alive mean 17.8, while sending 15.7
RUN 13 expected | kills 113 (22.6/min) | alive mean 16.5, while sending 14.8
RUN 13 strong   | kills 124 (24.8/min) | alive mean 16.1, while sending 15.5
RUN 14 weak     | kills 97 (19.4/min) | alive mean 16.1, while sending 15.7
RUN 14 expected | kills 137 (27.4/min) | alive mean 15.5, while sending 15.3
RUN 14 strong   | kills 168 (33.6/min) | alive mean 13.5, while sending 13.8
RUN 15 weak     | kills 88 (17.6/min) | alive mean 16.9, while sending 14.5
RUN 15 expected | kills 135 (27.0/min) | alive mean 15.8, while sending 14.3
RUN 15 strong   | kills 160 (32.0/min) | alive mean 14.8, while sending 14.4
after
RUN 11 weak     | kills 57 (11.4/min) | alive mean 17.0, while sending 12.6 | standing ticks between/struggling/strong [6163, 7822, 2250]
RUN 11 expected | kills 107 (21.4/min) | alive mean 16.1, while sending 13.5 | standing ticks between/struggling/strong [5927, 6698, 3810]
RUN 11 strong   | kills 134 (26.8/min) | alive mean 15.7, while sending 13.7 | standing ticks between/struggling/strong [7213, 5809, 3676]
RUN 12 weak     | kills 92 (18.4/min) | alive mean 15.5, while sending 12.9 | standing ticks between/struggling/strong [3284, 6750, 6013]
RUN 12 expected | kills 130 (26.0/min) | alive mean 13.3, while sending 13.2 | standing ticks between/struggling/strong [4293, 5598, 6520]
RUN 12 strong   | kills 165 (33.0/min) | alive mean 12.3, while sending 12.6 | standing ticks between/struggling/strong [6268, 3668, 6677]
RUN 13 weak     | kills 74 (14.8/min) | alive mean 17.2, while sending 13.5 | standing ticks between/struggling/strong [4116, 8870, 3140]
RUN 13 expected | kills 110 (22.0/min) | alive mean 16.7, while sending 12.4 | standing ticks between/struggling/strong [5184, 6940, 4079]
RUN 13 strong   | kills 137 (27.4/min) | alive mean 14.5, while sending 11.8 | standing ticks between/struggling/strong [4091, 8882, 3543]
RUN 14 weak     | kills 99 (19.8/min) | alive mean 15.8, while sending 12.4 | standing ticks between/struggling/strong [4735, 6395, 4885]
RUN 14 expected | kills 128 (25.6/min) | alive mean 14.2, while sending 12.7 | standing ticks between/struggling/strong [5879, 4058, 6404]
RUN 14 strong   | kills 145 (29.0/min) | alive mean 12.8, while sending 11.9 | standing ticks between/struggling/strong [5858, 4849, 5809]
RUN 15 weak     | kills 81 (16.2/min) | alive mean 16.5, while sending 12.5 | standing ticks between/struggling/strong [4425, 8164, 3508]
RUN 15 expected | kills 105 (21.0/min) | alive mean 13.1, while sending 11.2 | standing ticks between/struggling/strong [5629, 7804, 3109]
RUN 15 strong   | kills 149 (29.8/min) | alive mean 12.6, while sending 11.9 | standing ticks between/struggling/strong [6112, 5345, 5338]
```

The full raw lines (every RUN and LOG line) are in `build/director_fairness_before.txt` and
`build/director_fairness_after.txt` (not tracked).

### Before / after (means of 5 seeds × 300 s; computed by hand from the lines above)

| Hero | kills/min | alive mean | alive while packs may come | quiet mean s | quiets ended on their draw | ticks struggling |
|---|---|---|---|---|---|---|
| weak | 17.8 → 16.1 (−9.6 %) | 17.0 → 16.4 | 15.4 → 12.8 | 20.0 → 20.5 | 0/30 → 32/32 (15 of them ≥ 20 s: struggling) | — → 47 % |
| expected | 26.2 → 23.2 (−11.5 %) | 15.7 → 14.7 | 15.1 → 12.6 | 20.0 → 19.3 | 0/29 → 33/33 | — → 38 % |
| strong | 30.1 → 29.2 (**−3.0 %**, target ±10 %: met) | 14.6 → 13.6 | 14.5 → 12.4 | 20.0 → 18.7 | 0/29 → 33/33 | — → 34 % |

### Findings, honestly

- **Quiet lengths diverge as intended**: weak 20.5 s > expected 19.3 s > strong 18.7 s (before: 20.0 s for all), and
  every quiet now ends on its draw (88 of 88 forced before, 0 of 98 after).
- **The strong hero's kills/min: −3.0 %**, inside the 10 % target. The weak one kills 9.6 % fewer a minute (fewer and
  smaller packs, longer quiets), the expected one 11.5 % fewer.
- **The alive count diverges less than intended.** While packs come, every hero's room is ~2.5 smaller (weak
  15.4 → 12.8). The overall alive mean fell only 0.6 for the weak hero and 1.0 for the strong one: the weak one is
  still the most crowded (16.4 vs 13.6), because it clears less and the leftovers stay through the quiets.
- **The scripted heroes struggle a lot, the strong one too (34 % of director ticks)**: this FightBot on its 5 m leash
  takes hits whatever its damage (it falls under 40 % HP every cycle; the top-up at 15 % is the probe's poke), so the
  HP test fires for all three. The kill-rate test is what separates them (47 % vs 34 %). A real strong player who
  dodges would read STRONG far more; the probe can't show that. NOT YET RUN: a bot-suite or owner check.
- **Not fixed: the refill after the quiet.** The first pack now waits one build-up interval, but the room still goes
  from ~10 to the cap within ~5 s once the build-up starts (seed 11 weak, 100 s → 105 s: 10/23 → 23/23 after). The
  cap and 0.4 × interval ramp do that; changing it would change how fast packs come, so it is a pick below.
- Pull back still mostly ends on its 4 s timeout (unchanged rule).

## Picks for the owner

1. **The struggling rule** (HP < 40 % or kills < 50 % of the expected with ≥ 4 enemies out) and **strong** (HP > 70 %
   and kills ≥ the expected): keep, or change the thresholds (dev panel → Difficulty → `intensity`).
2. **The expected kill rate** = the cap now × 200 ‰ per 10 s (a cap of 18 expects 3.6 kills): keep, or a per-floor
   number.
3. **What struggling buys**: a peak at 600 (not 750), the peak's clock × 2, the quiet × 1.5 (15–30 s), packs one
   smaller. Keep, or stronger (e.g. pack −2, quiet × 2).
4. **The quiet ends on its drawn 10–20 s** (no longer waits for intensity to relax, which never happened): keep, or go
   back to "until relaxed, at most 20 s".
5. **The refill after the quiet** (still to the cap within ~5 s): leave, or ramp the build-up (e.g. at most one pack
   per full curve interval for the first N s, or a lower cap that grows back), which would make the quiet → build-up
   change visible.
6. The leftovers the hero can't reach keep the quiet crowded: leave (the enemies are the indicator), or let a quiet
   thin them (out of D46's scope: it would change what is on the floor).

## Tests

Run on the uncommitted worktree (on `74075798`). No full suite (owner rule).

```
gdformat --check src scripts tests && gdlint src scripts tests
1531 files would be left unchanged
Success: no problems found

bash scripts/ci/gut_shard.sh --check
gut_shard: ok (562 test files in 6 shards)

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_intensity_director.gd,res://tests/unit/sim/test_intensity_fairness.gd -gexit
Tests                28
Passing Tests        28
Asserts             179
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/golden -gtest=res://tests/unit/application/test_old_saves.gd,res://tests/unit/sim/test_world_snapshot.gd,res://tests/unit/sim/test_spawn_director.gd,res://tests/content/test_spawning_validation.gd,res://tests/unit/debug/test_dev_tuning.gd,res://tests/content/test_validation_errors.gd,res://tests/content/test_locale_coverage.gd -gexit
Scripts               8
Tests                74
Passing Tests        74
Time              417.457s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_difficulty_curve.gd,res://tests/e2e/test_e2e_dev_live_balance.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_dev_panel.gd -gexit
Scripts               4
Tests                 6
Passing Tests         6
Time              73.462s
---- All tests passed! ----
```

`test_intensity_director.gd`: two quiet tests rewritten for the on-time end (`test_quiet_ends_on_its_time_even_with_
intensity_high`, `test_the_first_pack_after_the_quiet_waits_a_build_up_interval`); `test_no_new_packs_while_quiet_and_
packs_again_after` waits 600 ticks (was 60) for the first pack; `test_it_never_changes_what_arrives_or_how_strong` turns
the slow-kill test off (its hero never kills, so it would read as struggling). New `test_intensity_fairness.gd` (8
tests): the starting values, the HP and kill-rate standings, the window, the lower and shorter peak, the longer quiet,
the smaller packs, the snapshot and an older save.

**Goldens**: `tests/golden` passed unchanged; no golden fixture moved (its replays don't run the director).
