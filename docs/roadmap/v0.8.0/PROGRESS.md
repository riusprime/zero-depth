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
| AV (part 1) | Boss and enemy orbs are lit 3D bodies, each with its own shape (the Gatekeeper's tumbling ember stones, the Warlord's spear heads, the Brood Mother's wobbling acid globs, the Hive Lens's faceted prisms, the Siege Engine's smoking embers, the Foundry's dripping molten drops, the casters' and drones' swirling orbs) and a trail; the Gatekeeper's shock lanes crack the ground while they track and lock, then strike as rows of stone spikes with debris, dust and a hot flash that sink back. Procedural textures (the CC0 sites were blocked). Evidence [ATTACK_VISUALS](evidence/ATTACK_VISUALS.md) | `fcd7fec` (branch `v080-av`) |
| BA | The six bosses move with keyframed clips (code-made, owner Q4) instead of a few code sways: every attack winds up with anticipation, lands its strike pose on the very tick the hit resolves (the clip's time is driven by the sim's windup / active / recovery ticks; a multi-marker slam re-strikes on each marker's tick) and recovers; idle breathing, walks matched to speed, a shielded pose (the Gatekeeper curls into a boulder for its Rock Rings), a flinch, a reel-and-slump stagger, a roar at each phase gate, a rise with the boss bar, and a collapse when it dies (all six now; only the Warlord fell before). Owner clips with the same name in the model's AnimationPlayer replace the code clips. Reduced motion: same poses, no tremble or overshoot. Evidence [BOSS_ANIMATIONS](evidence/BOSS_ANIMATIONS.md), sheets in `evidence/ba_shots/`; the feel is OWNER ONLY | `8b35845` (branch `v080-ba`) |
| RT part 1 (system + 3 layouts) | Rooms of 2×2, 3×2 and 3×3 cells are furnished from hand-designed layouts (dense clusters of tall blocks, crate stacks, wrecks, fire barrels, broken walls and pillars, grass and rubble, an open lane in the middle), picked per room and turned and mirrored by the generator, restyled by each biome; other sizes keep their rule-built rooms until their layouts come; a save made before RT resumes on its own floor. G2 asked; evidence [`evidence/ROOMS.md`](evidence/ROOMS.md) | `38beba1` (branch `v080-rt`) |
| EC | Enemies wear one colour family per role (palette A, the owner's G2 pick): melee red-orange, ranged blue-violet, bombers yellow, support green, tanks bronze, each kind its own shade, every kind with a glowing eye ([evidence](evidence/ENEMY_COLOURS.md)) | `234f119` (palettes) + `d71aa5c` (the pick) |
| BS part 1 (S1–S3) | Three bosses each get a mechanic of their own: the Gatekeeper's shock lanes leave stone pillars standing for 6 s, real walls you take cover behind from its rock rings (never on you, never sealing you in); the Warlord's tower shield blocks every hit from the front, so you circle it, and its javelins stick in the floor then all fly back along the same lines; the Brood Mother's eggs sit 3 s to be broken, or they hatch (and in phase 3 burst into acid). Cross Quake, Javelin Rain and the fast Web Spiral are gone. Evidence [BOSS_SIGNATURES_1](evidence/BOSS_SIGNATURES_1.md), shots in `evidence/bs_shots/`; the feel is OWNER ONLY | branch `v080-bs1` (the `v0.8.0 Step BS1` commit) |

## Goldens changed on purpose
- LS: none; loop 1 is unscaled, `tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 pass unchanged
- TG: none (`telegraph()` is not hashed; `tests/golden` passed unchanged)
- PF: none (the shot cap's per-tick fields aren't hashed; `tests/golden` passed unchanged)
- AV: none (presentation only; `tests/golden` 2/2 unchanged)
- RT1: none (no golden fixture holds a run floor: the replay and export-smoke goldens use the kernel arena;
  `tests/golden` passes unchanged). Run floors change on purpose (floor rules 4); a floor saved before keeps its own.
- BA: none (presentation, plus two read-only WorldReader reads; `tests/golden` 2/2 unchanged)
- EC: none (presentation only)
- BS1: none (no golden fixture holds a boss fight; the new BossStore lists hash only while a pillar or javelin stands; `tests/golden` 2/2 unchanged)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Owner decisions") | 2026-10-14 | by role; prompts for the seven kinds without an owner design; only the Arc Caster rune and Mine Layer mines keep ground marks; code clips first; CC0 + the owner's generator; HP ×6 / damage ×1.2 per loop | 2026-10-14 |
| G1 [BOSS_SIGNATURES](BOSS_SIGNATURES.md) S1–S6 | 2026-10-14 | "boss OK": all rows as proposed | 2026-10-14 |
| G1 [BLADE_AUDIT](BLADE_AUDIT.md) B1–B7 | 2026-10-14 | "blade audit … OK": all rows as proposed | 2026-10-14 |
| G2 EC: palettes A/B/C ([ENEMY_COLOURS](evidence/ENEMY_COLOURS.md), shots in `evidence/ec_shots/`) | 2026-10-14 | "Color palette A" | 2026-10-14 |
| G2 RT: the first 3 designed rooms | — | not yet made | |
| G2 MU: 3 menu and card directions ([MENU_G2](evidence/MENU_G2.md): A Salvage, B Ember stone, C Field kit × main menu, card pick, Build page) | 2026-10-14 | "menu style B" (Ember stone) | 2026-10-14 |
| G1 [BOSS_SIGNATURES](BOSS_SIGNATURES.md) S1–S6 | 2026-10-14 | pending | |
| G1 [BLADE_AUDIT](BLADE_AUDIT.md) B1–B7 | 2026-10-14 | pending | |
| G2 RT: the first 3 designed rooms ([evidence/ROOMS.md](evidence/ROOMS.md), shots in `evidence/rt_shots/`) | 2026-10-14 | pending | |
| G2 MU: 3 menu and card directions | — | not yet made | |

## Open
- v0.7.5 PR riusprime/zero-depth#6 not merged.
- RT (agent's reading, for the lead to confirm with the owner): "start, portal/boss rooms, shop and arenas keep their
  rules" read as their selection rules; the shop, arena and Overrun rooms are chosen after the floor is generated,
  so they may hold a designed interior (SR redesigns the shop room). The start hall, portal room and boss room never do.

## Blockers
- none

## History
- 2026-10-14: BS part 1 (agent, branch `v080-bs1` from `bace713`): `BossSignatures` (S1 pillars as barriers + `NavField.set_extra`, S2 front ×0 block + stuck/recalled javelins, S3 eggs as Hatchlings in an EGG state), `BossStore` pillar/javelin lists (in `ADDED_SINCE_V05`), `late_cause_key` + `CAUSE_WARLORD_RECALL` / `CAUSE_BROOD_EGG_BURST`, the three boss files (trims, new params), `BossSignatureViews` (javelins, eggs), `StoneSpikeViews` pillars, clips (Warlord `recall`, Brood lay, Gatekeeper raise); SIM_CONTRACTS §10f, CONTENT_SCHEMA §4, BOSS_FIGHTS.md. Run locally: lint clean (848 files); boss sim files 213/213; `tests/content` 137/137; `tests/arch` 4/4; `tests/golden` 2/2; application saves + debug 31/31; presentation folder 573/575 then the two fixed files + the spikes e2e 23/23; boss/playground/save e2e 17/18 then the failing one green (evidence). Shots 6 (llvmpipe). Not run locally: the full suite, the bot sims, seams. A `pkill -f gut_cmdln.gd` may have stopped another agent's GUT run on the shared machine.
- 2026-10-14: BA (agent, branch `v080-ba` from `0dfa2c7`): `src/presentation/world_view/boss_anim/` (BossClip: keyed
  tracks of bone / body turn, shift, stretch and named parameters with eases and SETTLE overshoot keys;
  BossAnimator: additive layers idle / walk / action (+ crossfade) / shielded / flinch / stagger / roar / rise /
  death, and the owner-clip hook; one clip library per boss, 13-14 clips each). BossAvatar drives the action clip's
  time from the sim (new `WorldReader.boss_attack_ticks`, `STATE_GATE`; the gate's and intro's progress) and every
  owner's model now plays a death (ActorViews keeps it 1.6 s). The avatars' old per-move pose code for the models is
  replaced by the clips (the code-built fallback bodies are unchanged). Tests: new `test_boss_animations.gd` (15);
  `test_boss_models.gd`, `test_boss_models_2.gd`, `test_boss_rigs.gd` follow the data's real moves and the deaths.
  Shots `scripts/shots/boss_anims.gd` (one boss per run, llvmpipe). Run locally: lint, boss/avatar presentation
  158/158, arch + golden 6/6, boss e2e 9/9, `test_boss_markers` + `test_bosses_2` 30/30. Not run locally: the full
  suite. Feel: OWNER ONLY.
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
- 2026-10-14: seams 302/302 on `deb87b4` (LS + TG merged), 302/302 on `7944a9e` (+ PF) and 302/302 on `0dfa2c7` (+ EC, MU, AV1).
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
- 2026-10-14: EC G2 made on `v080-ec` (agent, from `deb87b4`), not Done: the 14 normal kinds' colours moved into one
  table (`EnemyPalettes`: body / trim / grey / eye per kind) that every enemy avatar reads; `current` (today's red and
  grey, value for value) stays the shipped default; candidates A (saturated), B (muted, weathered), C (grey bodies,
  role trims and eyes), with an eye slit for the Splitter / Splitling and Mender in the candidates. Shots
  (`scripts/shots/mock_enemy_colours.gd`, Ruins and Frozen Shore, 1920 x 1080) and colour-blind numbers and
  simulations in [ENEMY_COLOURS](evidence/ENEMY_COLOURS.md). Run locally: lint clean; `tests/unit/presentation`
  527/527 (new `test_enemy_palettes.gd` 9/9); `tests/arch` + `tests/golden` 6/6; e2e enemies, horde enemies, new
  enemies 4/4. Not run locally: the full suite (CLAUDE.md). Waiting on the owner's pick.
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
- 2026-10-14: the owner's picks: "Color palette A, menu style B, blade audit and boss OK, keep de x100 loop". Palette A shipped as the default (`EnemyPalettes.SHIPPED`; enemy presentation tests + enemy e2e 72/72).
- 2026-10-14: RT part 1 (agent, branch `v080-rt` from `96cbbbd`): `RoomLayoutDefinition` (+ group, piece) and
  `data/room_layouts/` (2×2, 3×2, 3×3, written by `scripts/content/room_layouts.py`); `RoomLayouts` /
  `RoomLayoutTable` and the generator's layout draw, orientation settle and group-by-group furnishing on the `map`
  stream (no new sub-stream); `FLOOR_RULES` 4 (older saves rebuild without layouts); the dresser's biome swaps for
  designed rooms; `scripts/shots/room_layouts.gd`; PLAN "### RT"; CONTENT_SCHEMA and SIM_CONTRACTS "Designed rooms".
  Run locally: lint clean (810 files); `tests/content` 136/136; `tests/arch` + `tests/golden` 6/6; map/generator sim
  tests by name 12 scripts green (93 tests; the starglow/run-flow pair re-run on its own after a timeout); 
  `tests/unit/application` + `tests/unit/debug` 103/103; presentation dresser/biomes 36/36; e2e saves/old save/run
  flow/designed rooms 7/7 and the e2e shard 127/127. Shots: 10 at 1920×1080 (llvmpipe), 6 copied to
  `evidence/rt_shots/`. Not run locally: the full suite. G2 RT asked.
