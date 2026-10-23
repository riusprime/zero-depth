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
- **Merged, seams green (bar the owner's accepted red test_final_pace), pushed `b312a751`:** Wave 1 (DS, CV, PT, SA,
  FA), TW, XP, LG, IX, TD, AS, AS2, RA, DX, LZ, BM, FV (five floors), MI2 (the owner's models), VP (Void), DP (the
  Purple Portal earned), LK (Lockdowns), all ten Gun forms (AF1 Lance + Scatter, AF1b the Lance as the owner's charged
  energy ball, AF2 Glaive + Seekers, AF3 Wave + Wisps), SH + HF (Fortune/Blood/Chaos shrines, healing fountains), BR
  (the shots-a-second test over every form; `evidence/FORMS_DPS.md`). Lead fixes: enemies never attack through a shut
  doorway or wall (owner 2026-10-23); the Wisps view's death error; the shrines view's orphan lights.
- **Owner answers since 2026-10-22:** final pace stays red; the bar gate is `lockdown_seal`; secrets start on floor 2;
  the Lance is a charged ball at about 1.0× the orbs; questions while the owner is away go to
  [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) (11 open).
- **Agents working:** RG (special-room schema, pacing report, no-softlock tests; `v090-rg` from `d5867aa2`), BV (biome
  looks for the Wave 4 interactions; `v090-bv` from `d5867aa2`). The lead: the e2e mouse helper measures its scale once
  (it aimed every mouse_to at (100, 100) for a frame).
- **Waiting on the owner (all in OWNER_QUESTIONS):** the floor 4–5 bosses (NB G1), the hub layout (HB G2), collectibles
  (CL G1), affinities (RB G1), the VFX audit (VX G1), the forms' tuning (3, 5, 11), Lockdown length, shrine values;
  plus ELITES.md (EL) and the art still wanted.
- **Next:** **SV first** (owner 2026-10-23: +15 max HP a floor cleared, 60 % heal between floors; the owner can't reach the final boss), then **HB2** (owner: the hero walks up the Portal Machine's steps and through the portal after the weapon pick), then merge NB1, EL, HB as they report; **CF** (owner 2026-10-23: closed fights never in a 1×1 room, spawns at once scale with the room) starts when EL is merged (same Lockdown and spawn code); then NB2–NB4, MP, RB, CL.
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
| RA, DX | Rune pillars to turn until they match a carving; cracked walls only the Skill breaks, hidden rooms unseen until open; containers; explosive barrels; faint rune markings by secrets | `9c338674` |
| LZ, BM | The Laser (a held beam) and the Bomb (a lobbed blast) Gun forms | `c8d41c90` |
| FV | A run is five floors (about 10–19 rooms each), all five biomes, the curves stretched; v0.8.0 runs resume in their 3-floor shape | `897725f7` |
| AS2 | The owner's look B: the "Replaces" ribbon and slot pips; a Swap panel when a Secondary or Element slot is full; straight UI edges | `e7ef1309` |
| MI2 | The owner's 29 models and 3 textures installed (two split, Godot simplifier); the bar gate is the Lockdown seal | `54623c07`, `7c0278fb` |
| VP | Void is a Gun form: slow black holes that pass through foes and tug the crowd; the floor black hole retired | `a4a7590d` |
| DP | The Purple Portal is earned: a purple-rune room on floor 2 or 3 whose dais lets that floor's boss open it | `31fd095f` |
| AF1, AF1b | The Lance (hold to charge a swirling energy circle, release a piercing ball that grows, a small recoil; about 1.0× the orbs at full) and the Scatter (a pellet cone) | `7881d345`, `12089362` |
| LK | Lockdown rooms, 1–2 a floor: the owner's bars seal the doorways for three formations (Hazard Lockdowns from floor 2); stuck enemies pulled back, exits open at 90 s | `52cac58c` |
| — | Enemies never attack through a shut doorway or wall (owner 2026-10-23) | `8652b06e` |
| AF2, AF3 | The Glaive (a disc out and back), Seekers (three homing darts), Wave (a wide band through everything) and Wisps (three orbiting wisps) Gun forms | `77bb1c87`, `6c4b06e5` |
| SH, HF | Fortune, Blood and Chaos shrines (one a floor at most, the cost shown first); healing fountains | `b37942de` |
| BR | Every form and pattern stays within 12 an attack and 40 a second (a test); the forms' DPS sheet (Wave and Void the strongest) | `d5867aa2` |
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
