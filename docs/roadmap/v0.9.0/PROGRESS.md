# v0.9.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/world-combat-v090`, cut from `main` at `aeef604a` (v0.8.0).

## Where we are
(The lead keeps this block current at every push; the SessionStart hook prints it. Updated 2026-10-23.)

- **Phase 0 and the owner's answers are done.** Every line of both documents has a row (C1–C90, W1–W78, E1–E2); all
  30 design questions, the attack-forms G1 and the utility-cards G1 are answered (the PLAN's "Owner decisions"). The
  Steps are rewritten from them in six waves. `tests/MIN_TEST_COUNT` is 2676.
- **Biggest changes decided:** a run is 5 floors (PD-03 changed); ten Gun forms with Form / Pattern / Secondary /
  Element limits; Twin and Spread merged; no death explosions; elites only as archetypes on floors 4–5; the Purple
  Portal earned through a purple-rune room; the hub replaces most of the menu.
- **Merged and green (seams, bar the owner's accepted red test_final_pace):** Wave 1 (DS, CV, PT, SA, FA), TW, XP,
  LG, IX, TD, AS and AS2 (look B, the Swap panel, straight edges), RA, DX, LZ, BM, FV (five floors), MI2 (the owner's
  29 models and 3 textures), VP (Void a Gun form; floor black hole retired), DP (the Purple Portal earned), AF1 (Lance
  and Scatter; merged `7881d345`, seams running). Pushed: `31fd095f`.
- **Owner answers since:** final pace stays red; the bar gate is `lockdown_seal`; secrets start on floor 2; the Lance's
  full charge is tuned to about 1.0× the orbs on one target (to do on `7881d345`: `hold_permille` 5000 → ~11000).
- **Agents working:** LK (Lockdowns; branch `v090-lk` from `31fd095f`), AF2 (Glaive + Seekers; `v090-af2` from
  `7881d345`). Next free slot: AF3 (Wave + Wisps). Then BR, VX (G1), NB (G1), SH, HF, BV, TX, RG.
- **Waiting on the owner:** ELITES.md (G1, blocks EL and the Elite Lockdown); the pylon, containers, barrel, hazard
  models and a stone `timed_door` (art list); Swarmer, Mine Layer and Sniper (EM).
- **Known:** Void with Twin Lv 5 averaged 13.5 ms (budget 12) on the horde probe; floor 1 never fits a secret (intended).

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
| PT | The floor portals are tall swirling ovals that grow from a point after the boss dies (walk in once formed, 90 ticks) and collapse when you go through, 1.5 m clear of walls; later floors arrive through the portal you took. Floors saved before v0.9.0 keep their old gates (`3de267b5`) | `b6a780b0` (merge) |
| SA | Floor 1 opens on a big stone altar: runes and jewels light, orbit faster, build up and the hero pops in, over 4.0 s, with a placeholder sound | `f16b8ad4`, merge `1214f0bf` |
| FA | The Ascension portal leads to a quiet stair causeway and a purple altar; two pylons wake the Colossus on the plateau, which becomes the arena | `b084ee3b`, merge `1214f0bf` |
| TW | Twin and Spread are one card: two shots side by side at Lv 1–4, three fanned at Lv 5 | `5a81f10f`, merge `2c196402` |
| XP | No death explosions: Fire's kills leave a burning patch; the Explosive card is retired | `b0665dd2`, merge `2c196402` |
| LG | Legendary Power +32.5 %, Haste +23.4 % (was +40 %, +28.8 %) | `b2aeaef3`, merge `2c196402` |
| IX | One shared interactable and one prompt (the final approach's pylons first) | `8c77e190`, merge `38f2e207` |
| TD | Timed secret doors: two switches open a dead end's door for 15 s of quickening beeps, to a hidden room with an epic altar or a chest; spawns ease to a quarter in the switches' room | `ba7df04d`, merge `38f2e207` |
| AS | Attack slots: Form 1, Pattern 1, Secondary 2, Element 2 inside the wand; a full Form/Pattern slot's new card replaces and burns the old; one compatibility table; 12 projectiles per attack and 40 a second; old saves trimmed | `a45eeb3f`, merge `6cce8a51` |
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
- 2026-10-22 — Merged PT, SA/FA, TW/XP/LG, IX/TD and AS. Seams found and the lead fixed: an over-long test line; the
  achievement toast hidden by the 4.0 s arrival (now held through it); BuildFight still granting the retired Spread;
  old saves no longer restoring because PT moved the gates (legacy_gate for floor rules ≤ 9, `3de267b5`); SlotTable
  missing from WorldSnapshot's lists; the v0.6.1 Blade save now trimmed to one Pattern. Both PT and TD fixed FA's
  state-hash bug (the floor/loop fields). Seams 486/486 on `57c8a0c9` (1889 s). The owner delivered 28 models and 3
  textures (`163a8b42`); meshoptimizer has no Windows build, so prep goes through Godot (owner's pick). The lead's
  boss-scaling draft for five floors (+25 % / +12 %) overshot the owner's "stretch" rule; corrected to ≈ +18.3 % /
  +9.5 % in FV.
