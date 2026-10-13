# v0.7.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/v0.7.5-new-ground`, cut from `main` at `a20850f` (owner N1).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| CX | The Codex: a journal of every card (by pool), enemy, boss and biome, from the main menu and the pause menu; an entry unlocks the first time you meet it and shows its card or emblem, its text and your counts, kept in the profile ([evidence](evidence/CODEX.md)) | `v0.7.5 Step CX` commit (branch `v075-cx`) |

## Goldens changed on purpose
- none yet (CX changed none: the Codex is outside the sim; the replay golden passed in its content / arch run)
| AC | Local achievements: 37 to unlock (floors, wins, each boss and biome from the data, the wand, kills, sealed rooms, risks, the Codex, Ascension), a toast when one unlocks, an Achievements page in the Codex from both menus, kept in the profile ([evidence](evidence/ACHIEVEMENTS.md)) | `v0.7.5 Step AC` commit (branch `v075-ac`) |
| NB1 | Biome 4, Frozen Shore: a cold moonlit snow biome over a frozen sea, ice patches you slide on, in the run's biome draw (3 floors from 4) | `v0.7.5 Step NB1` commit |

## Goldens changed on purpose
- NB1: none. `tests/golden` passes unchanged; ice is laid only on Frozen Shore floors and is not hashed itself.
- AC: none. No sim file changed; `tests/golden` passed in its units run (evidence/ACHIEVEMENTS.md).

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The lead's readings in PLAN (the Ascension loop, the cosmic biome's name, the achievement list) | — | the owner asked for no interventions; corrected at the playtest | |
| EI-05: the sub-streams `map:ice` (NB1) and `map:overrun` (since v0.6.0) aren't named in the locked stream list; add them to EI-05? | — | pending (lead keeps them, the same pattern the owner approved for `map:event` on 2026-10-08) | |

## History
- 2026-10-12: plan from the owner's message (verbatim in PLAN), written while the v0.7.0 suite ran.
- 2026-10-13: v0.7.0 merged into `main` (`a20850f`); this branch, `claude/v0.7.5-new-ground`, cut from it (owner N1:
  "create a new branch"). Wave 1 (MG, NB1, CX) was started from `6381fcb`, the same tree as `a20850f`.
- 2026-10-12: CX (the Codex) built on `v075-cx` from `6381fcb`; the lead's readings are in PLAN "CX"; evidence in
  [`evidence/CODEX.md`](evidence/CODEX.md). The pause menu gained a Codex row (after Options) and the main menu one
  (after Credits); the menu e2e that count rows were updated. Not run by the agent: the full suite (the lead's, once
  per wave).
- 2026-10-12: NB1 Frozen Shore built on `v075-nb1` (from `6381fcb`): biome data, ice in the sim (`map:ice`), its look, tests; evidence [`evidence/FROZEN_SHORE.md`](evidence/FROZEN_SHORE.md). Not pushed.
- 2026-10-13: AC (local achievements) built on `v075-ac` from `fa70fcb` (CX and NB1 merged); the lead's readings are in
  PLAN "AC"; evidence in [`evidence/ACHIEVEMENTS.md`](evidence/ACHIEVEMENTS.md). The Codex gained a fifth page
  (Achievements); `runs:ascended` is left for AP to report. Not run by the agent: the full suite and the bot sims
  (the lead's, once per wave). Not pushed.
