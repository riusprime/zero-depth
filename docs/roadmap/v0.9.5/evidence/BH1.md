# v0.9.5 Step BH1 evidence

Bosses can't be staggered; their core opens at phase changes; boss HP is read when the door opens; loops ease the
Hollow Crown. Owner rows H0, H1, H2, HC7 (BOSSES_HARD.md) and PLAN Q2, Q3, Q11.

- Machine: the owner's PC (Windows 11, Godot 4.7.2 console build, headless, `--fixed-fps 60 --language en`).
- Build: base `679af4df2bbae1244affe68a635db0f19e901064` (branch `v095-bh1`, cut from it after merging
  `claude/v095-feedback`) plus this step's working tree. The step's own commit is the branch head.
- Lint: `gdformat --check` and `gdlint` over every touched `.gd`: `Success: no problems found` (32 files).

## What changed

- **H0.** `BossAi.on_damage`, `BossChallenge.stagger_permille`, the meter decay, `WorldReader.boss_stagger_permille` /
  `boss_staggered`, the boss bar's stagger meter and the `boss_stagger` sound cue are gone. The only call into
  `damage.gd` removed is the boss one (and `CoreTheft.on_damage`, which read the stagger). No sim path enters
  `STAGGERED` now. The weak point still takes armour off (`hit_mult`); it just fills nothing.
  Kept on purpose, so saves and tests load: the `STAGGERED` constant and its countdown branch in `BossAi.think` (an old
  save made mid-stagger runs it out; tests that "hold" a boss still use it), `BossStore.meter` / `stagger_t` (always 0
  now), and the data fields `stagger_size`, `stagger_decay_per_second`, `stagger_seconds`, `weak_point_stagger_permille`
  (validated, no longer read by the sim except `stagger_ticks`/`size` in `BossTable`). `stagger_decay_milli` was dropped.
- **H1 + Q3.** The phase gate (`BossGates`, 1.0 s, sim tuning `gate_seconds`) is the kneel: no attack starts, no movement,
  and the boss **can be hit** (the gate's invulnerability is gone; the HP floor at the next gate still holds).
  `CoreTheft.on_phase_change` opens the steal window at the gate's first tick; `core_window_seconds` is now 3.0
  (`data/event_rules/floor.tres`, default and validation in `event_rules_definition.gd`). View: the avatars' existing
  slump hook is driven by the gate (`BossAvatar._kneeling`), the model dips 15 % (`KNEEL_DIP`), the existing gem ring
  shows during the window (`core_views.gd` now reads the steal window for bosses), and the bar shows "PHASE SHIFT".
- **H2 + Q2.** `CatchUp.read_boss` is called in `BossFlow.interact` as the door starts to open; it stores power, expected,
  cap and m (and `boss_read = 1`) in `CatchUpState`. `CatchUp.on_boss` (called by `spawn_boss`) uses it and clears it, or
  reads at the spawn when none was stored. Boss cap table `[2500, 3000, 3500, 4000, 4500]` (`data/scaling/catch_up.tres`),
  still `+ 250 x Threat + 500 x (loop - 1)`. Spread: named stream `boss:hp_spread` (`RngStream.derive(seed,
  "boss:hp_spread:<floor>:<loop>:<final body>")`, one draw per fight), uniform in +-80 per mille
  (`boss_spread_permille`, validated 0..500), applied after the cap. `boss_read` is hashed only when 1 and listed in
  `WorldSnapshot.ADDED_SINCE_V05` (`CatchUpState`). Boss expected power unchanged.
- **HC7 + Q11.** `FinalPace.loops_eased = min(loop - 1, 3)`; `ease_permille = 1000 - 120 n` scales `pace_ref_ticks`, the
  clamp's floor `pace_min_ticks` and the rate cap (the floor) before the square root and the clamp (`seconds_at`,
  `hp_for`, `rate_milli` take an optional `ease`; callers pass it). `damage_ease_permille = 1000 - 80 n` scales each final
  body's `ActorStore.power` in `FinalBoss._spawn`. Run summary: `Looped x%d` line (`RUN_SUMMARY_LOOPED`, en `Looped ×%d`,
  es `Bucles ×%d`) in `end_panel.gd` when N >= 1. The 12 % / 8 % / 3 are constants in `final_pace.gd`
  (`LOOP_TIME_EASE_PERMILLE`, `LOOP_DAMAGE_EASE_PERMILLE`, `LOOP_EASE_MAX`), not data: **not done as data**.

## Tests converted (asserted stagger; now assert none)

- `tests/unit/sim/test_bosses.gd`: `test_stagger_fills_staggers_and_resets` -> `test_a_boss_never_staggers_however_hard_it_is_hit`;
  `test_stagger_interrupts_an_attack` -> `test_a_hit_does_not_interrupt_a_boss_attack`.
- `tests/unit/sim/test_boss_challenge.gd`: the weak point "fills the meter twice as fast" -> the meter stays 0.
- `tests/unit/sim/test_core_theft.gd`: `..._its_own_stagger_opens_the_window` -> `..._its_phase_change_opens_the_window`.
- `tests/unit/sim/test_boss_gates.gd`: "invulnerable in the gate" -> the kneeling boss takes a hit.
- `tests/unit/presentation/test_boss_views.gd` / `test_bosses_2_views.gd`: the stagger pose is driven by `STATE_GATE`;
  the bar test asserts no stagger instead of a full meter.
- `tests/unit/sim/test_catch_up.gd`, `tests/e2e/test_e2e_difficulty.gd`: caps 2.5 / 3.5 and the spread.
- `tests/unit/sim/test_final_boss.gd` (loop HP compared without m), `test_final_pace.gd` (the "never under a minute"
  floor is 60 s x the loop ease).

## New tests

Never STAGGERED under a burst; the kneel lasts 60 ticks, no attack starts and the boss does not move (all six bosses);
core steal inside the 3 s window, not after; m read at the door (build changed between door and spawn); caps per floor;
spread deterministic by seed and within +-8 %; door-read m hashed and saved; final time and damage at n = 0..3 (and
beyond, capped); "Looped x N" text (en and es).

## Raw totals (GUT, headless; each batch its own `APPDATA`)

| Batch | Files | Result |
|---|---|---|
| sim: bosses, boss_challenge, boss_gates, core_theft, catch_up | 5 | 73 tests, 71 pass, 2 fail (my new window test off by one tick); fixed, core_theft re-run green in the next row |
| sim: bosses_2, boss_signatures(_2), final_boss, final_pace | 5 | 97 tests, 95 pass, 2 fail (loop-3 floor 60 s; loop HP vs spread); fixed |
| sim: colossus, prism, nemesis, tidecaller, lantern_shade, ascension, loop_deep_ease | 7 | 117/117 |
| re-run: core_theft, final_boss, final_pace + 7 presentation boss/ascension views | 10 | 121 tests, 120 pass, 1 fail (a label assertion of mine, removed) |
| `tests/content` | whole folder | 157/157 |
| `tests/golden`, `tests/arch` | folders | 2/2, 4/4 |
| `tests/unit/application` | whole folder | 136/136 |
| e2e: bosses, bosses_2, boss_challenge, final_boss, ascension, difficulty + old_saves, ascension_saves | 8 | 22 tests, 21 pass, 1 fail (difficulty: cap 2.5 + spread); re-run with test_boss_views: 9/9 |
| e2e: boss_dodge 1-3, boss_signatures 1-2, boss_strikes, after_boss | 7 | 11/11 |
| `tests/unit/presentation` (all) | 153 scripts | 1038 tests, 1037 pass, 1 fail: `test_gun_pulse.gd` "Big Shot doubles the pulse with its hit radius" (0.396 vs 0.360). Not touched by this step (gun pulse view); not investigated |

Not run (per the brief): `test_five_floors.gd`, `test_curse_room.gd`, `test_modifier_smoke.gd`; no full suite.

## test_final_pace.gd numbers (this tree, `test_each_body_lasts_a_minute_or_more_whatever_the_build`)

Bodies in seconds, seed 21:

| Build | Body 0 / 1 / 2 | [max HP, measured dps] per body |
|---|---|---|
| base blade (loop 1) | 103.7 / 98.6 / 152.6 | [2849, 18] [703, 35] [3908, 35] |
| strong blade (loop 1) | 72.8 / 80.5 / 151.4 | [9360, 156] [2232, 206] [12402, 206] |
| absurd gun (loop 3, ease 760) | 49.3 / 53.5 / 49.5 | [7232, 158] [999, 121] [5551, 121] |
| absurd blade (loop 3, ease 760) | 49.2 / 63.2 / 101.0 | [9147, 200] [2689, 327] [14943, 327] |

Before this step the brief reports "strong blade body 2: 138.8 vs the base's 147.3 s" red. NOT YET RUN here: I did not
check out the base tree for a before-run (Keep steps fast). In this tree the same check reads 151.4 vs 152.6 s and
passes; the base and strong numbers moved because the bosses' m now carries a seeded spread and a new cap. The pass is
not a widened tolerance: the test's 1.0 s margin and 185 s ceiling are unchanged. The loop-3 builds' floor is now
60 s x 0.76 = 45.6 s (their bodies 49.2-53.5 s clear it); the floor assertion was changed to follow the ease, nothing else.

## Not done / notes

- The 12 % / 8 % / 3 loop numbers are code constants, not data (see above).
- Dev panel text for the boss m is unchanged (`s.boss` now includes the spread).
- Goldens: no golden fixture changed (`tests/golden` green). Worlds without a catch-up table hash as before; with one,
  `boss_read` joins the hash only while a door-read m waits.
