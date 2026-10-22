# v0.9.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/world-combat-v090`, cut from `main` at `aeef604a` (v0.8.0).

## Where we are
(The lead keeps this block current at every push; the SessionStart hook prints it. Updated 2026-10-22.)

- **Phase 0 done; the PLAN is a DRAFT.** Both owner documents are in `feedback/`, every line has a row (C1–C90,
  W1–W78, E1–E2), and the live code is audited. `tests/MIN_TEST_COUNT` is 2676 (PR #7's green `verify` total).
- **Waiting on the owner:** design questions Q1–Q30 in the PLAN, the G1 lists [`ATTACK_FORMS.md`](ATTACK_FORMS.md)
  and [`UTILITY_CARDS.md`](UTILITY_CARDS.md), and the altar model (prompt in
  `docs/art/requests/v0.9.0_altars_portals.md`). The enemy models for Swarmer, Mine Layer and Sniper are still
  waiting too (EM).
- **Next:** record the answers in the PLAN's "Owner decisions", rewrite Steps from them, mark the PLAN approved, then
  Wave 1 (DS, CV, PT, SA, FA).

## Owner decisions (2026-10-22)
- None yet.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | `tests/MIN_TEST_COUNT` 1904 → 2676 | `78271656` |
| 0 | Plan (DRAFT), G1 lists, art request | this commit |

## Goldens changed on purpose
- None.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q30 | [PLAN](PLAN.md) "Design questions" | pending | |
| G1 attack forms | [ATTACK_FORMS.md](ATTACK_FORMS.md) | pending | |
| G1 utility cards (D23) | [UTILITY_CARDS.md](UTILITY_CARDS.md) | pending | |

## Open
- Every step waits on its question or gate.

## Blockers
- None. (The steps wait on the owner's answers, which is the process, not a blocker.)

## History
- 2026-10-22 — Branch cut from `origin/main` at `aeef604a`; `MIN_TEST_COUNT` 2676 (`78271656`). Phase 0: four read-only
  audits (combat; portals, altar, door and camera; elites, rooms and persistence; EM and UC). PLAN (DRAFT) with every
  owner line, 30 design questions and five conflicts (X1–X5) with earlier rules; G1s ATTACK_FORMS and UTILITY_CARDS;
  the altar and portal art request. Next: the owner's answers.
