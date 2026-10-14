# v0.8.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`, fast-forwarded to v0.7.5's `f1a9ab5` (v0.7.5 is
not in `main` yet).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| LS | Each Ascension loop past the first gives enemies and bosses alike HP ×6 and damage ×1.2 (owner Q6; was enemy HP ×4 / damage ×2, boss HP ×2 / damage ×1.5), the ×100 cap kept: HP caps at loop 4; evidence [`evidence/LOOP_SCALING.md`](evidence/LOOP_SCALING.md) | `51c3b08` (branch `v080-ls`) |
| TG | Normal enemies no longer paint red lanes and discs when they wind up; only the Arc Caster's rune and the Mine Layer's mines stay on the ground. Chargers, Hatchlings, Swarmers, Splitters, Splitlings, Shield Bearers, Wardens, Snipers and Needles crouch, glow and flash just before they strike, facing the attack (steady under reduced motion). Evidence [TELEGRAPHS](evidence/TELEGRAPHS.md) | `a1c688f` (branch `v080-tg`) (`v080-tg`) |
| PF | Spread + Split + Explosive no longer drops the frame: a few explosions look as before; under load nearby ones merge and the extra ones thin (no light of their own); past 96 live bolts the rest fly as plain darts; at most 256 player shots alive (`data/tuning/sim.tres`). Probe tick + frame avg 26-37 ms → 8-9.4 ms (target ~12 ms met); p95 16.5-20.1 ms (missed, reported). Owner's fps: OWNER ONLY ([`evidence/PERF.md`](evidence/PERF.md)) | `f74e987` (branch `v080-pf`) |

## Goldens changed on purpose
- LS: none; loop 1 is unscaled, `tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 pass unchanged
- TG: none (`telegraph()` is not hashed; `tests/golden` passed unchanged)
- PF: none (the shot cap's per-tick fields aren't hashed; `tests/golden` passed unchanged)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Owner decisions") | 2026-10-14 | by role; prompts for the seven kinds without an owner design; only the Arc Caster rune and Mine Layer mines keep ground marks; code clips first; CC0 + the owner's generator; HP ×6 / damage ×1.2 per loop | 2026-10-14 |
| G1 [BOSS_SIGNATURES](BOSS_SIGNATURES.md) S1–S6 | 2026-10-14 | pending | |
| G1 [BLADE_AUDIT](BLADE_AUDIT.md) B1–B7 | 2026-10-14 | pending | |
| G2 RT: the first 3 designed rooms | — | not yet made | |
| G2 MU: 3 menu and card directions ([MENU_G2](evidence/MENU_G2.md): A Salvage, B Ember stone, C Field kit × main menu, card pick, Build page) | 2026-10-14 | pending | |

## Open
- v0.7.5 PR riusprime/zero-depth#6 not merged.

## Blockers
- none

## History
- 2026-10-14: MU G2 (agent, branch `v080-mu` from `34742a1`): three menu-and-card directions (A Salvage, B Ember stone,
  C Field kit) drawn in code by tool scripts only (`scripts/shots/mu_kit.gd`, `mu_shaders.gd`, `mu_shots.gd`,
  `mock_main_menu.gd`, `mock_pick.gd`, `mock_build.gd`), each on the main menu, the 3-card pick and the Build page at
  1920 × 1080 in en and es from seed 20261010 with real cards and the live wand; shots in
  [`evidence/mu_shots/`](evidence/mu_shots/), trade-offs and commands in [MENU_G2](evidence/MENU_G2.md). No shipped
  code or strings changed. Asked the owner for the pick.
- 2026-10-14: PF (agent, branch `v080-pf`): `scripts/checks/perf_probe.gd`; the explosions' drawing was 20-22 ms of a
  26-37 ms tick + frame (5,000 sprites asked, 995 shown); burst budget (VfxLayer, BurstBudget), live-bolt budget, look
  cache, and the sim cap `player_shots_max` 256 (the probe: the sim was 5 ms avg, 15 ms p95 with Twin). After: avg
  8-9.4 ms, p95 16.5-20.1 ms (over the 12 ms target; reported, not widened). Goldens unchanged.
- 2026-10-14: the owner's v0.7.5 playtest message (O1–O11, verbatim in PLAN); three read-only audits of the live
  code; plan written.
- 2026-10-14: Q1–Q6 answered (PLAN "Owner decisions"). PF (direct fix) started by an agent on `v080-pf`.
- 2026-10-14: seams 302/302 on `deb87b4` (LS + TG merged) and 302/302 on `7944a9e` (+ PF).
- 2026-10-14: LS and TG started by agents (`v080-ls`, `v080-tg`); the lead wrote the G1 audits BOSS_SIGNATURES and BLADE_AUDIT and the enemy-model prompts (`docs/art/requests/v0.8.0_enemy_models.md`).
- 2026-10-14: the owner's second message (O12–O15: designed rooms, the shop room per biome, the menu without shard cards, the art list) added to PLAN; the full art list is `docs/art/requests/v0.8.0_ART_LIST.md`.
- 2026-10-14: LS (agent, branch `v080-ls` from `98698cb`): `data/run/three_floors.tres` and the `RunDefinition`
  defaults to HP 6000 / damage 1200 ‰ per loop for enemies and bosses; CONTENT_SCHEMA updated; two new tests in
  `tests/unit/sim/test_ascension.gd` (the loop 1-5 factors; an enemy and a boss on loops 2 and 3); new
  `scripts/checks/loop_scaling.gd` (writes `build/loop_scaling.txt`). The F10 dev panel lists the fields already
  (every field of `data/run`). Run locally: lint clean (801 files); `tests/golden` 2/2; `tests/content` 133/133;
  `tests/unit/debug` 11/11; `test_ascension.gd` + `test_ascension_saves.gd` 16/16; `test_modifier_equivalence.gd`
  3/3; e2e `test_e2e_ascension.gd` + `test_e2e_achievements.gd` 4/4. Not run locally: the full suite (CLAUDE.md).
- 2026-10-14: TG done on `v080-tg` (agent): the melee kinds', Sniper's and Needle's telegraphs are `"ground": false`
  (shapes and timings kept); their avatars tell the windup (crouch, glow, flash). Contracts updated (PRESENTATION §4,
  SIM §10e, BOSS_FIGHTS "Normal enemies"). The feel is OWNER ONLY.
