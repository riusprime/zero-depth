# BALANCE_MR: with shared damage, secondary proc and the new rhythms, what does each build deal?

- **Status:** RUN (after only; before NOT YET RUN)
- **Build:** the working tree of step MR (branch `v080-mr`: `db725a0` + MR + the SG merge `7aaebe72`, at merge commit
  `b0853211` plus the step's uncommitted test and text fixes), run before it was committed as the step's commit (no
  sim code changed between the run and the commit); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux (cloud
  container, 4 CPUs)
- **Date:** 2026-10-20
- **Who ran it:** agent

Owner's words (O91): "Give Twin/Spread/Halo/Echo partial damage sharing and appropriate secondary proc effectiveness.
Extra projectiles must not each duplicate full damage and full-strength effects. … Rework Rapid Fire/Flurry into
distinct sustained-fire/burst rhythms." Plan: [`../BALANCE_PASS.md`](../BALANCE_PASS.md) "MR".

## Command
One run per build, each:
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --sim-only --seconds=10 --weapon=<w> --cards=<cards>
```
The probe grants the cards at level 5 (its default), puts 6 dummies in the Playground's room, holds Shoot (the Gun)
or presses Primary every tick (the Blade) for 10 s after 60 warm-up ticks, and tallies the damage the dummies took
(DpsTally). Timings are not claims (a busy cloud machine; CLAUDE.md "No timing on a busy machine"): only the damage
lines are read here.

**Before** is NOT YET RUN: it needs the pre-MR tree checked out and imported, which CLAUDE.md "Keep steps fast"
rules out unless the owner asks ("No baseline copies").

## Raw output (the damage line of each run)
```
=== weapon=gun cards=none
damage: 534 over 10.0 s -> 53.4 per s (8.9 per s per dummy; DpsTally overall 53.8)
=== weapon=gun cards=gun_twin
damage: 748 over 10.0 s -> 74.8 per s (12.5 per s per dummy; DpsTally overall 75.4)
=== weapon=gun cards=gun_spread
damage: 877 over 10.0 s -> 87.7 per s (14.6 per s per dummy; DpsTally overall 88.4)
=== weapon=gun cards=gun_twin,gun_spread,halo_shot
damage: 466 over 10.0 s -> 46.6 per s (7.8 per s per dummy; DpsTally overall 46.7)
=== weapon=gun cards=gun_echo
damage: 703 over 10.0 s -> 70.3 per s (11.7 per s per dummy; DpsTally overall 70.9)
=== weapon=gun cards=gun_rapid_fire
damage: 686 over 10.0 s -> 68.6 per s (11.4 per s per dummy; DpsTally overall 68.8)
=== weapon=blade cards=none
damage: 1931 over 10.0 s -> 193.1 per s (32.2 per s per dummy; DpsTally overall 194.1)
=== weapon=blade cards=flurry
damage: 1497 over 10.0 s -> 149.7 per s (24.9 per s per dummy; DpsTally overall 151.5)
=== weapon=blade cards=double_slash
damage: 7254 over 10.0 s -> 725.4 per s (120.9 per s per dummy; DpsTally overall 729.0)
```
Every run exited 0. The Twin · Spread · Halo run also printed `projectiles 84.155 avg, 256.000 p95` and
`shots_capped 0.027 avg` (the 256-shot cap held some volleys back).

## What the numbers say (agent's reading; no target was set for this step)
| Build (level 5) | DPS | vs the plain weapon |
|---|---|---|
| Gun plain | 53.4 | ×1.00 |
| Twin | 74.8 | ×1.40 |
| Spread | 87.7 | ×1.64 |
| Echo | 70.3 | ×1.32 |
| Rapid Fire | 68.6 | ×1.28 |
| Twin · Spread · Halo | 46.6 | ×0.87 |
| Blade plain | 193.1 | ×1.00 |
| Flurry | 149.7 | ×0.78 |
| Double Slash | 725.4 | ×3.76 |

- **Twin · Spread · Halo deals less than the plain Gun.** The Gun's bolt deals 5. The three shares at level 5 are
  800 × 670 × 600 ‰ = 32 %, so each bolt deals 1.6, which the integer floor makes 1 (`maxi(1, …)`). Halo's ring also
  sends most of its 98 bolts (7 × 7 × 2) away from dummies that stand in front, and the 256-shot cap held volleys back. The
  rounding loss comes from the small base number, not from the rule.
- **Flurry pressed every tick deals less than the plain Blade.** The probe never pauses, so the burst runs once and
  every later swing is at the base rate with ×0.85 damage. That is the rhythm working as specified (a burst after a
  pause); the probe doesn't exercise it.
- **Double Slash at level 5 is ×3.76.** Five repeats at 60 % each, against 6 dummies the swing reaches. The repeats'
  damage share is the plan's starting value.

These are starting values. Re-tuning is the owner's call (D66); nothing was changed after these runs.

## Lead fix (2026-10-20, landed with step RM)
The lead found that a share floored (`d0 * share / 1000`): a 5-damage bolt at a 32 % share became 1, so Twin · Spread ·
Halo hit less than the plain Gun. `Attacks._shared_form` (each projectile's share of the launch's damage and base
damage) and `Attacks.bolt_base_damage` (a split shot's `damage_permille` share) now round half up,
`(d * share + 500) / 1000`, still at least 1. The damage table above was measured before this fix; it was not re-run
(NOT YET RUN after the fix). The tests it moved are named in PROGRESS (step RM).
