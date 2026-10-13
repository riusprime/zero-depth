# v0.7.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/v0.7.5-new-ground`, cut from `main` at `a20850f` (owner N1).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| CX | The Codex: a journal of every card (by pool), enemy, boss and biome, from the main menu and the pause menu; an entry unlocks the first time you meet it and shows its card or emblem, its text and your counts, kept in the profile ([evidence](evidence/CODEX.md)) | `v0.7.5 Step CX` commit (branch `v075-cx`) |

## Goldens changed on purpose
- none yet (CX changed none: the Codex is outside the sim; the replay golden passed in its content / arch run)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The lead's readings in PLAN (the Ascension loop, the cosmic biome's name, the achievement list) | — | the owner asked for no interventions; corrected at the playtest | |

## History
- 2026-10-12: plan from the owner's message (verbatim in PLAN), written while the v0.7.0 suite ran.
- 2026-10-13: v0.7.0 merged into `main` (`a20850f`); this branch, `claude/v0.7.5-new-ground`, cut from it (owner N1:
  "create a new branch"). Wave 1 (MG, NB1, CX) was started from `6381fcb`, the same tree as `a20850f`.
- 2026-10-12: CX (the Codex) built on `v075-cx` from `6381fcb`; the lead's readings are in PLAN "CX"; evidence in
  [`evidence/CODEX.md`](evidence/CODEX.md). The pause menu gained a Codex row (after Options) and the main menu one
  (after Credits); the menu e2e that count rows were updated. Not run by the agent: the full suite (the lead's, once
  per wave).
