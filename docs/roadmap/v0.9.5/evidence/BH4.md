# v0.9.5 Step BH4 evidence

The Tidecaller: stronger tides, rings all fight, short water waves crossing the room (BOSSES_HARD.md T1-T4). Owner:
"tidescaller tides shouuld be stronger and keep the ball patter all times, we should add spawning waves crossing the
room, small like 2-4 meters that the player has to dodge during all fight".

- Machine: the owner's PC (Windows 11, Godot 4.7.2 console build, headless, `--fixed-fps 60 --language en`), runs in
  parallel, each with its own `APPDATA`.
- Build: base `20b6f9c223c0bea52f821c1a6a8ca9db596d1ddb` (branch `v095-bh4`, cut from the worktree HEAD, then merged
  `claude/v095-feedback`) plus this step's working tree. The step's own commit is the branch head.
- Import: `godot --headless --path . --editor --import --quit` before the work and after each new `class_name`: 0 ERROR
  lines. Disk had 94 GB free.
- Lint: `gdformat` then `gdlint` over every touched `.gd` (25 files): `Success: no problems found`.

## What changed (every number is data, validated; damage of the old attacks unchanged)

- **T1 Tides.** `the_pull` 1.2 -> 1.7 m/s pull, 1.0 -> 1.4 push; `the_pull_3` 1.5 / 1.2 -> 2.0 / 1.7; The Pull every 9 -> 8 s
  (`signature_every_seconds`). The drift cap is data now: the tide attack's `max_mps` 2.2 (`BossAttackTable.tide_max`,
  `BossTide.cap_of`); `BossSchemas.TIDE_MAX_MPS` 1.5 -> 2.2 is the most any attack may set it to, and the pull and push
  must stay under their own cap (validated). The Pull's own `pattern_id` is gone (no `tidecaller_pull_rings*`): the rings
  no longer double up.
- **T2 Rings all fight** (`BossStream.ring`). New phase fields `stream_attack` / `stream_every_seconds` name a `pattern`
  attack (`ring_stream`, `ring_stream_3`, not in any `attack_ids`) and its period: every 2.2 s (132 ticks), phase 2
  1.9 s (114), phase 3 1.6 s (96). The pattern (`tidecaller_stream`: 16 bubbles, 2 gaps of 3, 3.0 m/s, turned 20 degrees a
  ring; `tidecaller_stream_3`: alternate, 90 degrees, so the gaps flip between two sets) has a fixed heading, so the
  gaps are read, not chased. It runs on its own clock (`BossStore.str_*`), on top of every attack, including The Pull
  (the pull's bend still turns the bubbles). None while the boss rises or kneels (the BH1 gate): the clock is held and
  the next ring comes a full period after. The rotation's old `tide_rings` / `tide_rings_fast` attacks and their four
  patterns are removed (the stream replaces them). Cause: `CAUSE_TIDECALLER_RINGS`.
- **T3 Crossing waves** (`BossStream`, new move `wave`, attack `crossing_wave`). Every 3.5 s (210 ticks) one wave (phase 1)
  or two (phases 2, 3) form at the walls of the boss room (`BossStore.arena`; a square round the boss when there is none),
  the first wall drawn from the `ai` stream and the second one of the other three (opposite or adjacent). Length drawn
  from {2, 3, 4} m, 0.5 m thick, a 0.7 s telegraph (the foam line), then 4.5 m/s to the opposite wall; 15 damage once per
  wave and a 1.5 m shove along its travel (`BossTide.shift`: never into a wall); a dash passes through. Its place along
  the wall is drawn among the places whose whole segment is at least 3 m from the hero's projection on that wall as it
  forms (none: the wave is left out). Waves ignore the boss, enemies, props and shots. State is saved and hashed
  (`BossStore.str_*`, `wv_*`; `WorldSnapshot.ADDED_SINCE_V05`: an older save has none). The reader: `boss_waves()`.
- **T4** Undertow and Shell Slam unchanged.
- **Cause (4).** A wave kills with `CAUSE_TIDECALLER_WAVE` (en and es in `locale/strings.csv`): `w.killer_attack` is
  the wave attack's index (tested).
- **View (5)** `TideWaveViews` (new): a pulsing white-cyan foam strip on the floor through the telegraph (brighter as the
  wave nears), then a code-made curling band (0.5 m at the crest, translucent cyan, white foam top edge, streaks drifting
  along it), spray motes (a MultiMesh of the view's own, 8 a wave, 3 on Low density), both shaders unshaded with
  `fog_disabled` and an edge mask. The whoosh is `boss_tide_pull` at pitch 1.35 (`AudioEvents.WAVE_PITCH`), once as each
  wave leaves its wall. Honest note: the spray is the view's own small MultiMesh in the style of `TideViews`' bubbles; no
  existing `VfxLayer` kind is water, so none was reused.

## Runs (raw totals; `NOT YET RUN` where stated)

| Batch | Tests | Result |
|---|---|---|
| New `tests/unit/sim/test_tidecaller_streams.gd` (data rows, bad numbers, 10 bubbles a ring, ring cadence 132 / 114 / 96 ticks, 20 degrees and phase 3's flip, none while rising or kneeling, wave every 210 ticks and lengths, foam line 42 ticks then 4.5 m/s, 15 once and the 1.5 m shove, a dash goes through, never within 3 m (400 tries x 2), two at once from phase 2, determinism by seed, save round trip + hash, older save loads, boss gone, death line) | 19 | 19 pass, 2741 asserts |
| `tests/unit/sim/test_tidecaller.gd` (numbers updated: 1.7 / 1.4, 2.0 / 1.7, 8 s, cap 2.2 m/s; the rings test is now "never stop") | 15 | 15 pass, 73 asserts |
| `tests/unit/sim`: test_boss_hard, _hard_2, _hard_3, test_bosses, _2, test_boss_signatures, _signatures_2, test_readable_cause, test_world_snapshot, test_twin_wardens, test_final_boss, test_clockwork_judge, test_lantern_shade | 13 files | all pass |
| `tests/unit/sim/test_boss_pace.gd` (with the new Tidecaller Blade-lab test) | 5 | 5 pass, 292 asserts |
| `tests/unit/presentation`: new test_tide_wave_views (6), test_tidecaller_views, test_boss_views, test_audio_director, test_boss_fight_views, _views_3, test_boss_fights_2_views | 7 files | all pass (test_tide_wave_views 29 asserts) |
| `tests/content` (folder) | 157 | first run 156 pass, 1 fail: `test_boss_pace.gd` classed the new 15-damage wave as a hit class (see below); after the change `test_boss_pace.gd` 6 / 6 pass, 657 asserts |
| `tests/golden`, `tests/arch` | 6 | 6 pass (4 + 16912 asserts) |
| `tests/e2e/test_e2e_tidecaller.gd` (now also waits for a foam line and a band in the real boss room, and the ring stream's first ring) | 1 | pass, 20 asserts |
| `tests/e2e/test_e2e_boss_dodge`, `_dodge_2`, `_dodge_3` | 3 | 3 pass (60, 84, 12 asserts) |
| `test_five_floors`, `test_curse_room`, `test_modifier_smoke`, `test_event_rarity`, `scripts/ci/seams.sh`, the full suite | - | not run (the brief; GitHub runs the full suite) |

## Tests changed because a pinned number is the data's old one (no bar lowered)

- `test_tidecaller.gd`: the pull and push speeds, the 9 s cadence, the cap, the rings test (the Pull has no rings of its own).
- `tests/content/test_boss_pace.gd`: `KEPT_SLOW` names `ring_stream` (still 0.8 s) instead of `tide_rings`. The new
  `crossing_wave` joins `UNCLASSED` (like the meltdown: a hazard with no hit class of its own): the owner set it at 15
  damage, which is 7 hits to kill the 100 HP base hero, outside the small class (4-5). The count of classed attacks
  (110) is unchanged (the two ring stream attacks replace the two rotation ring attacks).

## Difficulty sanity: the Blade bot (`BladeRun`, `test_boss_pace.gd`; seeds 9, 10, 11, the base Blade build, loop 1)

Before this step no lab fought the Tidecaller; the same bot on the same three seeds, run on the base build (a throwaway
probe, not kept):

| | seed 9 | seed 10 | seed 11 | total |
|---|---|---|---|---|
| Before: killed in | 125.6 s | 131.5 s | 128.3 s | 385.4 s |
| Before: damage taken | 115 (5 hits) | 207 (9) | 23 (1) | 345 = **53.7 a minute** |
| After: killed in | 137.2 s | 132.4 s | 135.0 s | 404.6 s |
| After: damage taken | 292 (14 hits) | 222 (12) | 271 (14) | 785 = **116.4 a minute** |

(`test_the_blade_kills_the_tidecaller_through_its_streams` is the kept test; it prints `BH4 blade tidecaller: 785 damage
over 404.6 s = 116.4 a minute` and asserts the kill within the 180 s limit on each seed.) The bar (the Blade kills it
within 3 minutes) is unchanged and met on all three seeds.

Where the damage comes from, read from the bot's per-hit log (the bot's damage is scaled by the base build: waves hit
for 11, bubbles 17, Undertow 23, Shell Slam 38): the waves are the smallest part (3 to 5 hits a seed); most of the
rise is the Undertow and Shell Slam. Cause: the rotation lost its two ring attacks (the stream replaces them), so the
boss now picks Undertow and Shell Slam 50 / 50 instead of a third each, and the bot, which hugs the boss where the
rings can't reach, has more of them to take. **Owner decision, not made here:** if that is more than wanted, the
rotation's weights or cooldowns (data/bosses/tidecaller.tres) are the knob.

I tried teaching the bot to answer the waves, and neither helped, so the kept bot ignores them:
- stepping out of a wave's lane before it arrives: 159.4 a minute, and one seed did not kill within 180 s (it left the
  boss's side, where the rings can't reach, and the bubbles hit it: 17-damage hits went from about 2 to about 10 a run);
- dashing through a wave when it is 1.1 m away: 132.2 a minute (no better: the dash is on cooldown for the big attacks).

The sim's dodge is therefore the human's: a foam line 0.7 s ahead, a lane as long as the wave, and 6 m/s sideways.

## Not done / honest limits

- No owner playtest, no feel check (OWNER ONLY): whether 3.5 s waves plus 2.2 s rings are dodgeable by a person is not
  measured here; the bot's numbers are not a human's.
- The wave's `clear_m` keeps it 3 m from the hero's projection when it forms; the hero walks during the 0.7 s telegraph
  and can walk into the lane. That is the dodge.
- No screenshot tour was taken (the brief asked for none).
