# O2B_BOSS_PACE: does a floor boss fight last 1–2 minutes at any power, with a one-shot only past an extreme cap?

- **Status:** RUN (sim probe, unit, e2e, content and golden tests); the feel ("still feel easy", "1-2 minutes" in
  play) is **OWNER ONLY**
- **Build:** before: `75adec56` on `v0105-o2b` (= `claude/v0100-cleanup`) plus the new, uncommitted
  `scripts/checks/boss_pace_probe.gd`; after: the same tree plus this step's diff (committed as `v0.10.5 Step O2b`,
  whose parent is `75adec56`). Godot `4.7.2.stable.official.ed1daf0bf`; OS Windows 11 Pro 10.0.26200 (the owner's PC)
- **Date:** 2026-11-02
- **Who ran it:** agent (overnight mode: "Pick and build")

Owner lines (2026-11-01): D38 "bosses be oneshoted on very very rare ocassions, so you can get to a point that you one
shot one, but fights should last 1-2 minutes", option (a): the boss scales with your power when its fight starts; L3
"Faster bosses: still feel easy most of the times".

## The rule (built)

`CatchUp.boss_hp_permille` (src/sim/world/catch_up.gd), applied by `CatchUp.on_boss` at the spawn:

- At the door (`CatchUp.read_boss`, v0.9.5 BH1, unchanged) the boss reads your power P and the floor's boss expected
  power E (2000 / 4000 / 7000).
- HP multiplier = `pace_multiplier(P, E, pace(floor), cap, min)` = max(min, pace × min(P, cap × E) / E), then × the
  same ±8 % spread (one draw of `boss:hp_spread:<floor>:<loop>:<body>`). Integer per mille, no float.
- Data (`data/scaling/catch_up.tres`, starting values, owner D38, 2026-11-01): `boss_pace_permille` 3090 / 3770 /
  4450 (floors 1/2/3; floors 4–5 repeat floor 3's), `boss_pace_cap_permille` 3000, `boss_pace_min_permille` 1000.
- Damage keeps × √m (m = the old BH1 multiplier, its boss cap 2.5–4.5 and threat/loop terms unchanged). The phase
  gates (66 % / 33 %, the invulnerable shifts) are untouched. The final boss's bodies keep m (FinalPace paces them).
  An empty `boss_pace_permille` turns pacing off (labs, kernel, older tables).
- Dev panel: the pace fields show in the Difficulty group (DevFields reflects `data/scaling`); the catch-up readout
  adds "boss HP x… (paced)".

How the pace numbers were set: before-mean at P = E of the two pool bosses (F1 35.1 s, F2 29.7 s, F3 23.0 s) gave
90 s ÷ mean = 2570 / 3040 / 3910; the first after-run (raw below, "after, first pass") came out at 69–89 s means (the
fight's fixed time does not scale with HP), so each was × 90 ÷ that floor's mean once: 3090 / 3770 / 4450. No other
tuning pass.

## Commands

```
godot --headless --path . --editor --import --quit
godot --headless --path . -s scripts/checks/boss_pace_probe.gd          (before, then after; writes build/boss_pace.txt)
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/<golden|content> -ginclude_subdirs -gexit
```
(Godot = `Godot_v4.7.2-stable_win64_console.exe`, each run with its own `APPDATA=$(mktemp -d)`.)

The probe: test_boss_pace.gd's open plane and BladeRun hero (melee, a swing every 4 ticks while the boss can be hurt,
dashes the big attacks, healed to full every tick: it measures the fight's length, not survival), the run's floor
scaling (`RunState.scale_bosses`, loop 1, no Deep), floor_index = f, the catch-up table from data, no threat. Power
levels: the hero's damage stat set to level × E, so P = 0.5 / 1 / 2 / 6 × E (weak / expected / strong / extreme).
No expected-build bot or Playground power preset fits a fixed P (the Playground has none; the old expected-build bot
was retired by P1), so the levels are this damage-only build. Seeds 1, 2, 3.

## Results

Mean (min–max) fight seconds over seeds 1–3; band 60–120 s for weak / expected / strong, extreme allowed under 60 s.

| Boss | weak before | expected before | strong before | extreme before | weak after | expected after | strong after | extreme after |
|---|---|---|---|---|---|---|---|---|
| F1 Gatekeeper | 57.5 (55.7–61.1) | 31.7 (29.1–33.5) | 25.4 (22.6–26.9) | 14.9 (12.4–17.0) | 86.0 (81.3–91.3) | 85.4 (81.3–91.3) | 86.1 (81.3–93.3) | 45.7 (42.0–48.1) |
| F1 Warlord | 64.8 (63.6–66.3) | 38.4 (37.6–39.0) | 30.6 (29.0–31.6) | 19.3 (18.7–20.4) | 95.9 (90.6–99.8) | 95.9 (90.6–99.8) | 95.9 (90.6–99.8) | 56.8 (55.1–58.9) |
| F2 Brood Mother | 55.7 (48.6–60.3) | 30.9 (29.4–32.3) | 20.7 (18.2–24.0) | 15.6 (14.6–16.7) | 93.2 (85.4–103.1) | 93.2 (85.4–103.1) | 93.2 (85.4–103.1) | 50.4 (44.5–57.9) |
| F2 Hive Lens | 49.6 (47.7–52.4) | 28.4 (27.0–29.4) | 21.5 (19.2–23.0) | 14.5 (13.9–15.6) | 84.7 (80.6–92.6) | 83.9 (78.6–92.6) | 83.9 (78.6–92.6) | 47.8 (44.0–51.9) |
| F3 Siege Engine | 39.1 (36.2–40.7) | 22.0 (21.2–23.1) | 14.2 (12.3–17.1) | 8.0 (7.3–8.4) | 76.6 (72.0–80.3) | 76.8 (72.0–80.3) | 76.8 (72.0–80.3) | 43.2 (39.5–46.9) |
| F3 Foundry | 51.4 (46.8–55.8) | 24.0 (20.9–25.8) | 18.5 (17.1–21.3) | 14.6 (13.5–16.1) | 97.5 (93.4–102.5) | 94.3 (87.2–102.5) | 94.3 (87.2–102.5) | 56.5 (55.6–58.3) |

- **Target met:** every weak, expected and strong fight lands in 72.0–103.1 s (all 54 fights in the band); every
  extreme (6× E) fight is 39.5–58.9 s. All 72 fights killed the boss; determinism MATCH both runs.
- Weak, expected and strong are almost the same length on a seed: the HP and the hero's hits both scale with P, so
  the fight takes the same number of hits.
- **Not shown here:** an actual one-hit phase. Past 3× E each extra × of power shortens the fight in step (6× E: about
  half), so a phase melts in a few seconds only far past 6× E; the probe did not run such a build. A fresh build on
  floor 3 (P 1000, 0.14 E) meets the floor ×1 (not ×0.64), so it fights longer than the weak row; not measured.

## Raw output: before (`build/boss_pace.txt` at `75adec56` + the probe)

```
boss_pace_probe: BladeRun hero, damage stat = level x E, seeds [1, 2, 3], cap 36000 ticks, 60 Hz headless
columns: floor boss level seed | seconds | max HP | HP mult | P | dead
F1 gatekeeper weak 1 | 61.1 | 1437 | 1026 | 1000 | true
F1 gatekeeper weak 2 | 55.8 | 1366 | 975 | 1000 | true
F1 gatekeeper weak 3 | 55.7 | 1463 | 1045 | 1000 | true
F1 gatekeeper weak ALL | mean 57.5 s, min 55.7, max 61.1
F1 gatekeeper expected 1 | 29.1 | 1437 | 1026 | 2000 | true
F1 gatekeeper expected 2 | 33.5 | 1366 | 975 | 2000 | true
F1 gatekeeper expected 3 | 32.5 | 1463 | 1045 | 2000 | true
F1 gatekeeper expected ALL | mean 31.7 s, min 29.1, max 33.5
F1 gatekeeper strong 1 | 26.6 | 2032 | 1451 | 4000 | true
F1 gatekeeper strong 2 | 22.6 | 1932 | 1380 | 4000 | true
F1 gatekeeper strong 3 | 26.9 | 2067 | 1476 | 4000 | true
F1 gatekeeper strong ALL | mean 25.4 s, min 22.6, max 26.9
F1 gatekeeper extreme 1 | 15.4 | 3521 | 2515 | 12000 | true
F1 gatekeeper extreme 2 | 12.4 | 3346 | 2390 | 12000 | true
F1 gatekeeper extreme 3 | 17.0 | 3582 | 2558 | 12000 | true
F1 gatekeeper extreme ALL | mean 14.9 s, min 12.4, max 17.0
F1 warlord weak 1 | 63.6 | 1437 | 1026 | 1000 | true
F1 warlord weak 2 | 66.3 | 1366 | 975 | 1000 | true
F1 warlord weak 3 | 64.4 | 1463 | 1045 | 1000 | true
F1 warlord weak ALL | mean 64.8 s, min 63.6, max 66.3
F1 warlord expected 1 | 37.6 | 1437 | 1026 | 2000 | true
F1 warlord expected 2 | 38.6 | 1366 | 975 | 2000 | true
F1 warlord expected 3 | 39.0 | 1463 | 1045 | 2000 | true
F1 warlord expected ALL | mean 38.4 s, min 37.6, max 39.0
F1 warlord strong 1 | 31.1 | 2032 | 1451 | 4000 | true
F1 warlord strong 2 | 29.0 | 1932 | 1380 | 4000 | true
F1 warlord strong 3 | 31.6 | 2067 | 1476 | 4000 | true
F1 warlord strong ALL | mean 30.6 s, min 29.0, max 31.6
F1 warlord extreme 1 | 18.7 | 3521 | 2515 | 12000 | true
F1 warlord extreme 2 | 20.4 | 3346 | 2390 | 12000 | true
F1 warlord extreme 3 | 19.0 | 3582 | 2558 | 12000 | true
F1 warlord extreme ALL | mean 19.3 s, min 18.7, max 20.4
F2 brood_mother weak 1 | 60.3 | 2551 | 1062 | 2000 | true
F2 brood_mother weak 2 | 48.6 | 2294 | 955 | 2000 | true
F2 brood_mother weak 3 | 58.2 | 2342 | 975 | 2000 | true
F2 brood_mother weak ALL | mean 55.7 s, min 48.6, max 60.3
F2 brood_mother expected 1 | 30.9 | 2551 | 1062 | 4000 | true
F2 brood_mother expected 2 | 29.4 | 2294 | 955 | 4000 | true
F2 brood_mother expected 3 | 32.3 | 2342 | 975 | 4000 | true
F2 brood_mother expected ALL | mean 30.9 s, min 29.4, max 32.3
F2 brood_mother strong 1 | 20.1 | 3607 | 1502 | 8000 | true
F2 brood_mother strong 2 | 24.0 | 3242 | 1350 | 8000 | true
F2 brood_mother strong 3 | 18.2 | 3312 | 1380 | 8000 | true
F2 brood_mother strong ALL | mean 20.7 s, min 18.2, max 24.0
F2 brood_mother extreme 1 | 16.7 | 6247 | 2602 | 24000 | true
F2 brood_mother extreme 2 | 15.5 | 5618 | 2340 | 24000 | true
F2 brood_mother extreme 3 | 14.6 | 5736 | 2390 | 24000 | true
F2 brood_mother extreme ALL | mean 15.6 s, min 14.6, max 16.7
F2 hive_lens weak 1 | 52.4 | 2630 | 1062 | 2000 | true
F2 hive_lens weak 2 | 47.7 | 2366 | 955 | 2000 | true
F2 hive_lens weak 3 | 48.6 | 2415 | 975 | 2000 | true
F2 hive_lens weak ALL | mean 49.6 s, min 47.7, max 52.4
F2 hive_lens expected 1 | 29.4 | 2630 | 1062 | 4000 | true
F2 hive_lens expected 2 | 27.0 | 2366 | 955 | 4000 | true
F2 hive_lens expected 3 | 28.7 | 2415 | 975 | 4000 | true
F2 hive_lens expected ALL | mean 28.4 s, min 27.0, max 29.4
F2 hive_lens strong 1 | 22.5 | 3719 | 1502 | 8000 | true
F2 hive_lens strong 2 | 19.2 | 3343 | 1350 | 8000 | true
F2 hive_lens strong 3 | 23.0 | 3415 | 1379 | 8000 | true
F2 hive_lens strong ALL | mean 21.5 s, min 19.2, max 23.0
F2 hive_lens extreme 1 | 15.6 | 6442 | 2602 | 24000 | true
F2 hive_lens extreme 2 | 13.9 | 5793 | 2340 | 24000 | true
F2 hive_lens extreme 3 | 14.2 | 5915 | 2389 | 24000 | true
F2 hive_lens extreme ALL | mean 14.5 s, min 13.9, max 15.6
F3 siege_engine weak 1 | 40.5 | 3379 | 1072 | 3500 | true
F3 siege_engine weak 2 | 40.7 | 3310 | 1050 | 3500 | true
F3 siege_engine weak 3 | 36.2 | 3379 | 1072 | 3500 | true
F3 siege_engine weak ALL | mean 39.1 s, min 36.2, max 40.7
F3 siege_engine expected 1 | 21.2 | 3379 | 1072 | 7000 | true
F3 siege_engine expected 2 | 23.1 | 3310 | 1050 | 7000 | true
F3 siege_engine expected 3 | 21.9 | 3379 | 1072 | 7000 | true
F3 siege_engine expected ALL | mean 22.0 s, min 21.2, max 23.1
F3 siege_engine strong 1 | 13.2 | 4778 | 1516 | 14000 | true
F3 siege_engine strong 2 | 12.3 | 4680 | 1485 | 14000 | true
F3 siege_engine strong 3 | 17.1 | 4778 | 1516 | 14000 | true
F3 siege_engine strong ALL | mean 14.2 s, min 12.3, max 17.1
F3 siege_engine extreme 1 | 8.4 | 8275 | 2626 | 42000 | true
F3 siege_engine extreme 2 | 8.3 | 8104 | 2572 | 42000 | true
F3 siege_engine extreme 3 | 7.3 | 8275 | 2626 | 42000 | true
F3 siege_engine extreme ALL | mean 8.0 s, min 7.3, max 8.4
F3 foundry weak 1 | 51.6 | 3567 | 1072 | 3500 | true
F3 foundry weak 2 | 55.8 | 3494 | 1050 | 3500 | true
F3 foundry weak 3 | 46.8 | 3567 | 1072 | 3500 | true
F3 foundry weak ALL | mean 51.4 s, min 46.8, max 55.8
F3 foundry expected 1 | 25.3 | 3567 | 1072 | 7000 | true
F3 foundry expected 2 | 20.9 | 3494 | 1050 | 7000 | true
F3 foundry expected 3 | 25.8 | 3567 | 1072 | 7000 | true
F3 foundry expected ALL | mean 24.0 s, min 20.9, max 25.8
F3 foundry strong 1 | 21.3 | 5044 | 1516 | 14000 | true
F3 foundry strong 2 | 17.1 | 4940 | 1485 | 14000 | true
F3 foundry strong 3 | 17.1 | 5044 | 1516 | 14000 | true
F3 foundry strong ALL | mean 18.5 s, min 17.1, max 21.3
F3 foundry extreme 1 | 16.1 | 8734 | 2626 | 42000 | true
F3 foundry extreme 2 | 14.2 | 8555 | 2572 | 42000 | true
F3 foundry extreme 3 | 13.5 | 8734 | 2626 | 42000 | true
F3 foundry extreme ALL | mean 14.6 s, min 13.5, max 16.1
determinism: MATCH
```

## Raw output: after, first pass (pace 2570 / 3040 / 3910; summary lines only)

```
F1 gatekeeper weak ALL | mean 69.7 s, min 67.7, max 73.0
F1 gatekeeper expected ALL | mean 69.7 s, min 67.7, max 73.0
F1 gatekeeper strong ALL | mean 69.7 s, min 67.7, max 73.0
F1 gatekeeper extreme ALL | mean 38.4 s, min 37.0, max 39.6
F1 warlord weak ALL | mean 79.9 s, min 79.2, max 81.4
F1 warlord expected ALL | mean 79.9 s, min 79.2, max 81.4
F1 warlord strong ALL | mean 80.0 s, min 79.3, max 81.4
F1 warlord extreme ALL | mean 47.1 s, min 42.2, max 54.8
F2 brood_mother weak ALL | mean 76.6 s, min 75.0, max 77.8
F2 brood_mother expected ALL | mean 76.6 s, min 75.0, max 77.8
F2 brood_mother strong ALL | mean 76.6 s, min 75.0, max 77.8
F2 brood_mother extreme ALL | mean 42.2 s, min 37.8, max 45.6
F2 hive_lens weak ALL | mean 68.6 s, min 64.0, max 76.3
F2 hive_lens expected ALL | mean 68.5 s, min 63.9, max 76.3
F2 hive_lens strong ALL | mean 69.9 s, min 63.9, max 76.3
F2 hive_lens extreme ALL | mean 36.9 s, min 34.4, max 38.3
F3 siege_engine weak ALL | mean 70.4 s, min 64.3, max 76.3
F3 siege_engine expected ALL | mean 70.4 s, min 64.3, max 76.3
F3 siege_engine strong ALL | mean 70.8 s, min 65.8, max 76.3
F3 siege_engine extreme ALL | mean 36.3 s, min 33.6, max 39.0
F3 foundry weak ALL | mean 89.4 s, min 82.8, max 96.9
F3 foundry expected ALL | mean 87.7 s, min 82.8, max 96.9
F3 foundry strong ALL | mean 87.7 s, min 82.8, max 96.9
F3 foundry extreme ALL | mean 50.4 s, min 46.9, max 55.8
determinism: MATCH
```

## Raw output: after (pace 3090 / 3770 / 4450, the committed values)

```
boss_pace_probe: BladeRun hero, damage stat = level x E, seeds [1, 2, 3], cap 36000 ticks, 60 Hz headless
columns: floor boss level seed | seconds | max HP | HP mult | P | dead
F1 gatekeeper weak 1 | 91.3 | 2220 | 1585 | 1000 | true
F1 gatekeeper weak 2 | 81.3 | 2109 | 1506 | 1000 | true
F1 gatekeeper weak 3 | 85.4 | 2259 | 1613 | 1000 | true
F1 gatekeeper weak ALL | mean 86.0 s, min 81.3, max 91.3
F1 gatekeeper expected 1 | 91.3 | 4442 | 3172 | 2000 | true
F1 gatekeeper expected 2 | 81.3 | 4221 | 3015 | 2000 | true
F1 gatekeeper expected 3 | 83.6 | 4520 | 3228 | 2000 | true
F1 gatekeeper expected ALL | mean 85.4 s, min 81.3, max 91.3
F1 gatekeeper strong 1 | 93.3 | 8884 | 6345 | 4000 | true
F1 gatekeeper strong 2 | 81.3 | 8443 | 6030 | 4000 | true
F1 gatekeeper strong 3 | 83.6 | 9041 | 6457 | 4000 | true
F1 gatekeeper strong ALL | mean 86.1 s, min 81.3, max 93.3
F1 gatekeeper extreme 1 | 42.0 | 13328 | 9520 | 12000 | true
F1 gatekeeper extreme 2 | 48.1 | 12665 | 9046 | 12000 | true
F1 gatekeeper extreme 3 | 46.8 | 13561 | 9686 | 12000 | true
F1 gatekeeper extreme ALL | mean 45.7 s, min 42.0, max 48.1
F1 warlord weak 1 | 97.2 | 2220 | 1585 | 1000 | true
F1 warlord weak 2 | 90.6 | 2109 | 1506 | 1000 | true
F1 warlord weak 3 | 99.8 | 2259 | 1613 | 1000 | true
F1 warlord weak ALL | mean 95.9 s, min 90.6, max 99.8
F1 warlord expected 1 | 97.2 | 4442 | 3172 | 2000 | true
F1 warlord expected 2 | 90.6 | 4221 | 3015 | 2000 | true
F1 warlord expected 3 | 99.8 | 4520 | 3228 | 2000 | true
F1 warlord expected ALL | mean 95.9 s, min 90.6, max 99.8
F1 warlord strong 1 | 97.2 | 8884 | 6345 | 4000 | true
F1 warlord strong 2 | 90.6 | 8443 | 6030 | 4000 | true
F1 warlord strong 3 | 99.8 | 9041 | 6457 | 4000 | true
F1 warlord strong ALL | mean 95.9 s, min 90.6, max 99.8
F1 warlord extreme 1 | 55.1 | 13328 | 9520 | 12000 | true
F1 warlord extreme 2 | 56.3 | 12665 | 9046 | 12000 | true
F1 warlord extreme 3 | 58.9 | 13561 | 9686 | 12000 | true
F1 warlord extreme ALL | mean 56.8 s, min 55.1, max 58.9
F2 brood_mother weak 1 | 103.1 | 4807 | 2002 | 2000 | true
F2 brood_mother weak 2 | 91.1 | 4324 | 1801 | 2000 | true
F2 brood_mother weak 3 | 85.4 | 4413 | 1838 | 2000 | true
F2 brood_mother weak ALL | mean 93.2 s, min 85.4, max 103.1
F2 brood_mother expected 1 | 103.1 | 9616 | 4006 | 4000 | true
F2 brood_mother expected 2 | 91.1 | 8649 | 3603 | 4000 | true
F2 brood_mother expected 3 | 85.4 | 8829 | 3678 | 4000 | true
F2 brood_mother expected ALL | mean 93.2 s, min 85.4, max 103.1
F2 brood_mother strong 1 | 103.1 | 19236 | 8015 | 8000 | true
F2 brood_mother strong 2 | 91.1 | 17299 | 7207 | 8000 | true
F2 brood_mother strong 3 | 85.4 | 17661 | 7358 | 8000 | true
F2 brood_mother strong ALL | mean 93.2 s, min 85.4, max 103.1
F2 brood_mother extreme 1 | 57.9 | 28852 | 12021 | 24000 | true
F2 brood_mother extreme 2 | 44.5 | 25948 | 10811 | 24000 | true
F2 brood_mother extreme 3 | 48.9 | 26491 | 11037 | 24000 | true
F2 brood_mother extreme ALL | mean 50.4 s, min 44.5, max 57.9
F2 hive_lens weak 1 | 92.6 | 4957 | 2002 | 2000 | true
F2 hive_lens weak 2 | 80.6 | 4459 | 1801 | 2000 | true
F2 hive_lens weak 3 | 81.0 | 4551 | 1838 | 2000 | true
F2 hive_lens weak ALL | mean 84.7 s, min 80.6, max 92.6
F2 hive_lens expected 1 | 92.6 | 9917 | 4006 | 4000 | true
F2 hive_lens expected 2 | 80.6 | 8919 | 3603 | 4000 | true
F2 hive_lens expected 3 | 78.6 | 9105 | 3678 | 4000 | true
F2 hive_lens expected ALL | mean 83.9 s, min 78.6, max 92.6
F2 hive_lens strong 1 | 92.6 | 19837 | 8014 | 8000 | true
F2 hive_lens strong 2 | 80.6 | 17839 | 7207 | 8000 | true
F2 hive_lens strong 3 | 78.6 | 18213 | 7358 | 8000 | true
F2 hive_lens strong ALL | mean 83.9 s, min 78.6, max 92.6
F2 hive_lens extreme 1 | 51.9 | 29754 | 12021 | 24000 | true
F2 hive_lens extreme 2 | 44.0 | 26759 | 10811 | 24000 | true
F2 hive_lens extreme 3 | 47.5 | 27319 | 11037 | 24000 | true
F2 hive_lens extreme ALL | mean 47.8 s, min 44.0, max 51.9
F3 siege_engine weak 1 | 72.0 | 7519 | 2386 | 3500 | true
F3 siege_engine weak 2 | 80.3 | 7364 | 2337 | 3500 | true
F3 siege_engine weak 3 | 77.6 | 7519 | 2386 | 3500 | true
F3 siege_engine weak ALL | mean 76.6 s, min 72.0, max 80.3
F3 siege_engine expected 1 | 72.0 | 15038 | 4773 | 7000 | true
F3 siege_engine expected 2 | 80.3 | 14729 | 4675 | 7000 | true
F3 siege_engine expected 3 | 78.1 | 15038 | 4773 | 7000 | true
F3 siege_engine expected ALL | mean 76.8 s, min 72.0, max 80.3
F3 siege_engine strong 1 | 72.0 | 30079 | 9548 | 14000 | true
F3 siege_engine strong 2 | 80.3 | 29461 | 9352 | 14000 | true
F3 siege_engine strong 3 | 78.1 | 30079 | 9548 | 14000 | true
F3 siege_engine strong ALL | mean 76.8 s, min 72.0, max 80.3
F3 siege_engine extreme 1 | 46.9 | 45120 | 14323 | 42000 | true
F3 siege_engine extreme 2 | 43.2 | 44194 | 14029 | 42000 | true
F3 siege_engine extreme 3 | 39.5 | 45120 | 14323 | 42000 | true
F3 siege_engine extreme ALL | mean 43.2 s, min 39.5, max 46.9
F3 foundry weak 1 | 96.6 | 7936 | 2386 | 3500 | true
F3 foundry weak 2 | 102.5 | 7773 | 2337 | 3500 | true
F3 foundry weak 3 | 93.4 | 7936 | 2386 | 3500 | true
F3 foundry weak ALL | mean 97.5 s, min 93.4, max 102.5
F3 foundry expected 1 | 87.2 | 15873 | 4773 | 7000 | true
F3 foundry expected 2 | 102.5 | 15547 | 4675 | 7000 | true
F3 foundry expected 3 | 93.4 | 15873 | 4773 | 7000 | true
F3 foundry expected ALL | mean 94.3 s, min 87.2, max 102.5
F3 foundry strong 1 | 87.2 | 31750 | 9548 | 14000 | true
F3 foundry strong 2 | 102.5 | 31098 | 9352 | 14000 | true
F3 foundry strong 3 | 93.4 | 31750 | 9548 | 14000 | true
F3 foundry strong ALL | mean 94.3 s, min 87.2, max 102.5
F3 foundry extreme 1 | 55.6 | 47627 | 14323 | 42000 | true
F3 foundry extreme 2 | 58.3 | 46649 | 14029 | 42000 | true
F3 foundry extreme 3 | 55.6 | 47627 | 14323 | 42000 | true
F3 foundry extreme ALL | mean 56.5 s, min 55.6, max 58.3
determinism: MATCH
```

## Tests

After tree (raw GUT summaries):

- `tests/unit/sim/test_catch_up.gd` (2 new tests: the pace multiplier's bounds and the extreme cap; the paced HP from
  data; 3 boss-HP asserts moved to the paced value) is in the 11-file run below, green there.
- 11 unit files (test_catch_up, test_deep_bite, test_ascension, test_boss_gates, test_world_snapshot,
  test_five_floors, test_run_flow, test_closed_fights, test_boss_challenge, test_final_pace, test_final_boss):
  `Scripts 11, Tests 157, Passing Tests 154, Failing Tests 3, Asserts 19040/19062, Time 3176.755s`. The 3 failures:
  `test_deep_bite.gd::test_the_deep_event_offers_its_two_choices` (`["Abismo susurrante"] expected to equal
  ["Whispering Deep"]`: this PC's locale), `test_ascension.gd::test_loop_scaling_compounds_and_caps` and
  `::test_q6_loops_2_and_3_scale_an_enemy_and_a_boss` (e.g. `[204] expected to equal [240]: loop 2 enemy HP`: the
  enemy floor-1 ease of v0.9.5 EP3). **Not this step's:** the same two files on the base tree (`git stash`, HEAD
  `75adec56`): `Tests 20, Passing Tests 17, Failing Tests 3, Asserts 3487/3509`, the same three tests.
- e2e (test_e2e_difficulty, test_e2e_boss_challenge, test_e2e_old_save, test_e2e_health_bars, test_e2e_bosses,
  test_e2e_saves), first run: `Scripts 6, Tests 8, Passing Tests 7, Failing Tests 1, Asserts 513/514`; the failure was
  `test_e2e_difficulty.gd` `[6377] expected to equal [1743]: boss HP × m` (the assert still expected the old HP rule);
  updated to the paced HP and re-run: `Tests 1, Passing Tests 1, Asserts 215`.
- `tests/content`: `Tests 166, Passing Tests 166, Asserts 13593`. `tests/arch`: `Tests 4, Passing Tests 4, Asserts
  18846`. `tests/golden`: `Tests 2, Passing Tests 2, Asserts 4`.
- Lint: `gdformat --check src scripts tests` → `1527 files would be left unchanged`; `gdlint src scripts tests` →
  `Success: no problems found` (content_compiler.gd went past 1000 lines with the 3 compile lines; it takes the
  `# gdlint: disable=max-file-lines` header, as world.gd and world_snapshot.gd do).
- Boss HP is not new state: no new saved or hashed field (the spawned max HP is saved as before), so old saves load
  as before (test_e2e_old_save, test_world_snapshot green).

## Goldens

None moved. `tests/golden` (`test_replay_ground_plane.gd`: the ground-plane replay, no catch-up table, no floor
boss) ran green on the after tree: `Tests 2, Passing Tests 2, Asserts 4`. No golden was re-recorded.

## Lead/agent picks for the owner

1. HP is linear in power (pace × P ÷ E) rather than N2's 120 s × √(30 / dps): a fixed fight length needs HP ∝ P; N2's
   square root makes a stronger build quicker on purpose, which D38 asks only past the cap.
2. The pace reads the door's P (BH1's read), not a measured damage per second: a floor fight is too short to meter,
   and the read stays a pure function of the build (never of how well you play).
3. The power cap at 3× the expected power (`boss_pace_cap_permille` 3000): a strong (2×) build still gets ~90 s; at
   6× the fight is ~40–60 s; a phase melts only far past that.
4. No rate cap for floor bosses (the final boss keeps its own): a cap would forbid the rare one-shot D38 wants.
5. The HP multiplier never goes under ×1 (`boss_pace_min_permille` 1000): a weak build never meets a boss below its
   own data HP, so a very weak build can fight longer than 2 minutes.
6. The pace is per floor (3090 / 3770 / 4450), not per boss: the pool's two bosses differ by about 10 s at most.
7. Floors 4–5 (and loops) repeat floor 3's pace, not measured here; loops still raise boss HP through the run's loop
   factor and damage through the loop cap.
8. Threat (curses, Deep) no longer raises a floor boss's HP (it raised the old cap); it still raises its damage cap.
9. Damage keeps × √m (the old multiplier), so stronger builds still meet harder-hitting bosses, as before.
10. The ±8 % spread stays on the paced HP.
11. The probe's power levels are 0.5 / 1 / 2 / 6 × the floor's boss expected power, by the damage stat alone.
