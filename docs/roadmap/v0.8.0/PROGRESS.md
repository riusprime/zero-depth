# v0.8.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`, fast-forwarded to v0.7.5's `f1a9ab5` (v0.7.5 is
not in `main` yet).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| TG | Normal enemies no longer paint red lanes and discs when they wind up; only the Arc Caster's rune and the Mine Layer's mines stay on the ground. Chargers, Hatchlings, Swarmers, Splitters, Splitlings, Shield Bearers, Wardens, Snipers and Needles crouch, glow and flash just before they strike, facing the attack (steady under reduced motion). Evidence [TELEGRAPHS](evidence/TELEGRAPHS.md) | this commit (`v080-tg`) |

## Goldens changed on purpose
- none (TG: `telegraph()` is not hashed; `tests/golden` passed unchanged)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Owner decisions") | 2026-10-14 | by role; prompts for the seven kinds without an owner design; only the Arc Caster rune and Mine Layer mines keep ground marks; code clips first; CC0 + the owner's generator; HP ×6 / damage ×1.2 per loop | 2026-10-14 |
| G1 BOSS_SIGNATURES | — | not yet written | |
| G1 BLADE_AUDIT | — | not yet written | |

## Open
- v0.7.5 PR riusprime/zero-depth#6 not merged.

## Blockers
- none

## History
- 2026-10-14: the owner's v0.7.5 playtest message (O1–O11, verbatim in PLAN); three read-only audits of the live
  code; plan written.
- 2026-10-14: Q1–Q6 answered (PLAN "Owner decisions"). PF (direct fix) started by an agent on `v080-pf`.
- 2026-10-14: TG done on `v080-tg` (agent): the melee kinds', Sniper's and Needle's telegraphs are `"ground": false`
  (shapes and timings kept); their avatars tell the windup (crouch, glow, flash). Contracts updated (PRESENTATION §4,
  SIM §10e, BOSS_FIGHTS "Normal enemies"). The feel is OWNER ONLY.
