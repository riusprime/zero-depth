# v0.8.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`, fast-forwarded to v0.7.5's `f1a9ab5` (v0.7.5 is
not in `main` yet).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| LS | Each Ascension loop past the first gives enemies and bosses alike HP ×6 and damage ×1.2 (owner Q6; was enemy HP ×4 / damage ×2, boss HP ×2 / damage ×1.5), the ×100 cap kept: HP caps at loop 4; evidence [`evidence/LOOP_SCALING.md`](evidence/LOOP_SCALING.md) | `51c3b08` (branch `v080-ls`) |
| TG | Normal enemies no longer paint red lanes and discs when they wind up; only the Arc Caster's rune and the Mine Layer's mines stay on the ground. Chargers, Hatchlings, Swarmers, Splitters, Splitlings, Shield Bearers, Wardens, Snipers and Needles crouch, glow and flash just before they strike, facing the attack (steady under reduced motion). Evidence [TELEGRAPHS](evidence/TELEGRAPHS.md) | `a1c688f` (branch `v080-tg`) (`v080-tg`) |
| AV (part 1) | Boss and enemy orbs are lit 3D bodies, each with its own shape (the Gatekeeper's tumbling ember stones, the Warlord's spear heads, the Brood Mother's wobbling acid globs, the Hive Lens's faceted prisms, the Siege Engine's smoking embers, the Foundry's dripping molten drops, the casters' and drones' swirling orbs) and a trail; the Gatekeeper's shock lanes crack the ground while they track and lock, then strike as rows of stone spikes with debris, dust and a hot flash that sink back. Procedural textures (the CC0 sites were blocked). Evidence [ATTACK_VISUALS](evidence/ATTACK_VISUALS.md) | `v0.8.0 Step AV1` (branch `v080-av`) |

## Goldens changed on purpose
- LS: none; loop 1 is unscaled, `tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 pass unchanged
- TG: none (`telegraph()` is not hashed; `tests/golden` passed unchanged)
- AV: none (presentation only; `tests/golden` 2/2 unchanged)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Owner decisions") | 2026-10-14 | by role; prompts for the seven kinds without an owner design; only the Arc Caster rune and Mine Layer mines keep ground marks; code clips first; CC0 + the owner's generator; HP ×6 / damage ×1.2 per loop | 2026-10-14 |
| G1 [BOSS_SIGNATURES](BOSS_SIGNATURES.md) S1–S6 | 2026-10-14 | pending | |
| G1 [BLADE_AUDIT](BLADE_AUDIT.md) B1–B7 | 2026-10-14 | pending | |
| G2 RT: the first 3 designed rooms | — | not yet made | |
| G2 MU: 3 menu and card directions | — | not yet made | |

## Open
- v0.7.5 PR riusprime/zero-depth#6 not merged.

## Blockers
- none

## History
- 2026-10-14: the owner's v0.7.5 playtest message (O1–O11, verbatim in PLAN); three read-only audits of the live
  code; plan written.
- 2026-10-14: Q1–Q6 answered (PLAN "Owner decisions"). PF (direct fix) started by an agent on `v080-pf`.
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
- 2026-10-14: AV part 1 on `v080-av` (agent, from `deb87b4`): FireballViews draws every look as a lit 3D body
  (`ProjectileMeshes`, `FireballShaders`; still three MultiMeshes a look), lights for the lobs, raining drops and a
  boss's signature shots through VfxCore's pool; `StoneSpikeViews` raises pooled stone spikes on the shock lanes'
  strike tick (read from the telegraph), with debris, dust, a flash and crack marks in the effects layer, and a
  `stone_spike` model hook; TelegraphViews draws the shock lanes as cracked ground. VfxCore gained two public helpers
  only. Textures procedural: ambientCG, Poly Haven and Kenney were refused by the network proxy (no asset added, the
  manifest and credits unchanged). New tests `test_attack_visuals.gd` (15) and e2e `test_e2e_stone_spikes.gd` (1);
  `test_boss_fight_views_3.gd` follows the shader materials. Run locally: lint clean (809 files); presentation set
  72/72; `tests/content` 133/133; `tests/arch` 4/4; `tests/golden` 2/2; e2e set 11/11. Shots
  `scripts/shots/attack_visuals.gd` (17, on llvmpipe). Not run locally: the full suite. The look is OWNER ONLY. Open:
  AV part 2 (the other bosses' ground attacks).
