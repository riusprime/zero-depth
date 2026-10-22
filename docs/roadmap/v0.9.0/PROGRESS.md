# v0.9.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/world-combat-v090`, cut from `main` at `aeef604a` (v0.8.0).

## Where we are
(The lead keeps this block current at every push; the SessionStart hook prints it. Updated 2026-10-22.)

- **Phase 0 and the owner's answers are done.** Every line of both documents has a row (C1–C90, W1–W78, E1–E2); all
  30 design questions, the attack-forms G1 and the utility-cards G1 are answered (the PLAN's "Owner decisions"). The
  Steps are rewritten from them in six waves. `tests/MIN_TEST_COUNT` is 2676.
- **Biggest changes decided:** a run is 5 floors (PD-03 changed); ten Gun forms with Form / Pattern / Secondary /
  Element limits; Twin and Spread merged; no death explosions; elites only as archetypes on floors 4–5; the Purple
  Portal earned through a purple-rune room; the hub replaces most of the menu.
- **Wave 1 under way (owner's go, 2026-10-22):** DS and CV done; PT (agent, branch `v090-pt`) and SA then FA
  (agent, branch `v090-safa`) building in worktrees.
- **Waiting on the owner:** the altar model (prompt in
  `docs/art/requests/v0.9.0_altars_portals.md`); Swarmer, Mine Layer and Sniper models (EM). The G1s and G2s named in
  later steps come as those steps start.
- **Next:** merge PT and SA/FA, seams, then Wave 2.

## Owner decisions (2026-10-22)
- Q1–Q30, ATTACK_FORMS and UTILITY_CARDS, verbatim in the PLAN's "Owner decisions". LOCKED_DECISIONS change log: six
  rows (the wand, elements and Void, the legendaries, PD-03 five floors, PD-05 local timers, elites and the Purple
  Portal); ROADMAP §3: two rows.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | `tests/MIN_TEST_COUNT` 1904 → 2676 | `78271656` |
| DS | The boss door's boom lands with the slab: the impact sound starts 18 ticks (0.3 s) before the touchdown, so the file's peak meets it; sim and goldens unchanged | `15a1bac2` |
| CV | The arrival and the boss door vibrate (a small fast buzz on both axes, averaging to nothing) instead of shaking and kicking the view; also walking into the Ascension portal; hit, finisher and Blade-kick shakes unchanged | `ce7ffad7` |
| 0 | Plan, G1 lists, art request; the owner's answers | `54f40318`, `74fca543`, `1ae81240`, this commit |

## Goldens changed on purpose
- None.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q14 | [PLAN](PLAN.md) "Design questions" | answered | 2026-10-22 |
| Q15–Q19 | [PLAN](PLAN.md) "Design questions" | answered | 2026-10-22 |
| Q20–Q30 | [PLAN](PLAN.md) "Design questions" | answered | 2026-10-22 |
| G1 attack forms | [ATTACK_FORMS.md](ATTACK_FORMS.md) | F1–F10 approved; Twin and Spread merged | 2026-10-22 |
| G1 utility cards (D23) | [UTILITY_CARDS.md](UTILITY_CARDS.md) | 14 rows yes, row 4 as Phase Strike's level-up, 7 no | 2026-10-22 |

## Open
- Wave 1 waits on the owner's go; later steps open their own G1s and G2s.

## Blockers
- None. (The steps wait on the owner's answers, which is the process, not a blocker.)

## History
- 2026-10-22 — Branch cut from `origin/main` at `aeef604a`; `MIN_TEST_COUNT` 2676 (`78271656`). Phase 0: four read-only
  audits (combat; portals, altar, door and camera; elites, rooms and persistence; EM and UC). PLAN (DRAFT) with every
  owner line, 30 design questions and five conflicts (X1–X5) with earlier rules; G1s ATTACK_FORMS and UTILITY_CARDS;
  the altar and portal art request. Next: the owner's answers.
- 2026-10-22 — The owner answered Q1–Q14 and the attack-forms G1 (recorded in the PLAN, ATTACK_FORMS and
  LOCKED_DECISIONS). Next: Q15–Q30 and the UC list.
- 2026-10-22 — The owner answered Q15–Q19 (recorded in the PLAN; the art request now asks for the altar only). Next:
  Q20–Q30 and the UC list.
- 2026-10-22 — The owner answered Q20–Q30 and the UC list (five floors, lockdowns as a new room type, puzzle calm,
  cracked walls to the Skill, elites on floors 4–5 with a 30 % core, Marked and Ambush Cache deleted, the earned Purple
  Portal, the hub menu, two unlockable forms, shrines, fountains, robes and affinities). Steps rewritten in six waves.
  Next: the owner's go for Wave 1.
- 2026-10-22 — Wave 1 started (owner: "Start the development phase with Wave 1"). Toolchain on this PC: Godot 4.7.2 from
  Downloads and gdtoolkit 4.5.0 in a scratch venv (nothing installed system-wide). DS (`15a1bac2`): test_door_boom +
  test_boss_door_view + test_audio_director 22/22, then test_door_boom + arch layering/purity 6/6, e2e run_flow 3/3. CV (`ce7ffad7`): 43/43 presentation
  and arch, e2e arrival + ascension 4/4, audio + portal 3/3. PT and SA/FA handed to two agents in worktrees.
