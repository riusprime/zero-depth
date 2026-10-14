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
| RT2 (the other 21 layouts) | Every room size is furnished from designed layouts, three each (24): small 1×1, 2×1 and 3×1 rooms get a few small corner, wall and centre groups (fewer, smaller: they stay fightable), the big rooms get ruined buildings with broken walls and pillars, central ruined blocks, diagonal bands of blocks round an open middle and wreck convoys; each size's three differ (corners / centre / diagonal or a building). A save made under RT1 resumes on its own floor (floor rules 5; rules 4 rebuilds with RT1's three). The boss rooms keep their own builder. Evidence [`evidence/ROOMS.md`](evidence/ROOMS.md) RT2 | `a879063` (branch `v080-rt2`) |
| EC | Enemies wear one colour family per role (palette A, the owner's G2 pick): melee red-orange, ranged blue-violet, bombers yellow, support green, tanks bronze, each kind its own shade, every kind with a glowing eye ([evidence](evidence/ENEMY_COLOURS.md)) | `234f119` (palettes) + `d71aa5c` (the pick) |
| MU | The shard cards are gone: cards, plaques, wand tiles and pips, Codex tiles, achievement rows and toast, the shop, Swap and build picker are carved Ember stone tablets (element-coloured inlay ring round the icon, a groove in the family's colour, a carved rarity gem, a gold rim on epic and legendary, the level badge kept); every menu sits on a stone slab with an ember-lit focused row and an ember diamond; the main menu has its own ember-lit stone backdrop, sparks rising (still under reduced motion); long Spanish sentences reflow clear of the gem; the glow is kept apart from the Hot heat colour. Evidence [MENU](evidence/MENU.md); the look is OWNER ONLY | `c78bdbd` (branch `v080-mu2`) |
| BS part 1 (S1–S3) | Three bosses each get a mechanic of their own: the Gatekeeper's shock lanes leave stone pillars standing for 6 s, real walls you take cover behind from its rock rings (never on you, never sealing you in); the Warlord's tower shield blocks every hit from the front, so you circle it, and its javelins stick in the floor then all fly back along the same lines; the Brood Mother's eggs sit 3 s to be broken, or they hatch (and in phase 3 burst into acid). Cross Quake, Javelin Rain and the fast Web Spiral are gone. Evidence [BOSS_SIGNATURES_1](evidence/BOSS_SIGNATURES_1.md), shots in `evidence/bs_shots/`; the feel is OWNER ONLY | `e34550e` (branch `v080-bs1`) |
| AV (part 2) | Every other boss ground attack keeps its dull-then-bright marker but fills it with its own ground (stone cracks, steel scratches, bubbling acid, gold light, hazard stripes, molten seams) instead of flat red, and strikes in 3D on the sim's strike tick: the Gatekeeper's fist slams blow craters and its sweep kicks a dust arc; the Warlord's spears thrust up the lanes, its lunge scorches a skid, its bash swings a steel arc, its javelins plant in the circles; the Brood Mother's eggs cast a growing shadow then splat acid, its leap cracks the ground, its burrow erupts; the Hive Lens fires a 3D beam and a ring of light; the Siege Engine's shells fall and explode, its rail streaks and scorches, its shockwave rolls out as dust; the Foundry pours molten metal that cools to a crust, blasts steam and sets lanes burning. Evidence [ATTACK_VISUALS](evidence/ATTACK_VISUALS.md) part 2 | `2a39c6c` (branch `v080-av2`) |
| BS part 2 (S4–S6) | The other three bosses get theirs: the Hive Lens turns its Gaze round the room, a beam that starts aimed away from you, turns a quarter turn every 2 s and reverses, stops at walls and burns what it touches while its orbs fly; the Siege Engine's Turret Cross embers bounce off the walls once and come back at you from behind (never onto you within 0.5 s), and in phase 3 its turrets' shots bounce too; the Foundry's Molten Flood leaves lava for 5 s (enemies walk round it, a way to the boss and the door always stays), and phase 3 opens with a roar while the room's outer ring glows, then melts for good and creeps in, never closer than 7 m to the centre. Glare Ring, Turret Cross Reversing and the fast Furnace Waves are gone. Deaths name the gaze, its orbs, the ricochets, the lava and the melt. Evidence [BOSS_SIGNATURES_2](evidence/BOSS_SIGNATURES_2.md), shots 7–12 in `evidence/bs_shots/`; the feel is OWNER ONLY | `ef919d3` (branch `v080-bs2`) |
| BL | The Blade's cards multiply now: Double Slash adds a repeat a level (5 at level 5, 70 % each), Wave a crescent a level, Split Wave a split a level; Heavy, Flurry and Thrust lose their drawback from level 3 (none at 5); a Blade slash's hit casts On Hit / On Kill / On Finisher twice; two new Blade cards, Blade Storm (returning blades, 2 + 1 a level) and Riposte Chain (a kill slashes on, 2 + 1 a level); offers favour the run's own weapon's cards ×1.5; the Gun's Split shards no longer split or explode and Explosive's blasts past 8 a tick merge. Probe DPS: Gun Spread + Split + Explosive 1,432 → 778 per s, + Twin 1,694 → 1,015; Blade combo 1,870 → 10,304. With Blade Storm the Blade combo is over the frame budget (26.6 ms avg), reported. Evidence [`evidence/BLADE.md`](evidence/BLADE.md); feel OWNER ONLY | `cb7235f` (branch `v080-bl`) |
| PF2 | The Blade Storm combo no longer halves the frame: a Blade Storm blade's hits cast no trigger's spell (the slash and Wave's crescents still do), at most 36 Blade Storm blades fly at once (one level-5 Double Slash swing; Blade Storm alone never reaches it; a cut throw leaves a LIMIT event), and the crescents and ghost slashes are drawn as instances of baked shapes (same look). Probe (Double Slash, Blade Storm, Wave, Split Wave, On Hit, Explosive, L5) tick + frame avg 22.8-26.5 → 11.6-13.0 ms (~12 ms met in 2 of 6 runs on a shared container: borderline, reported), p95 37.8-45.4 → 20.5-24.2 ms (missed); damage 13,691 → 10,999 per s. Evidence [`evidence/PERF.md`](evidence/PERF.md) PF2; feel and fps OWNER ONLY | `25cbc01` (branch `v080-pf2`) |

## Goldens changed on purpose
- LS: none; loop 1 is unscaled, `tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 pass unchanged
- TG: none (`telegraph()` is not hashed; `tests/golden` passed unchanged)
- PF: none (the shot cap's per-tick fields aren't hashed; `tests/golden` passed unchanged)
- AV: none (presentation only; `tests/golden` 2/2 unchanged)
- RT1: none (no golden fixture holds a run floor: the replay and export-smoke goldens use the kernel arena;
  `tests/golden` passes unchanged). Run floors change on purpose (floor rules 4); a floor saved before keeps its own.
- BA: none (presentation, plus two read-only WorldReader reads; `tests/golden` 2/2 unchanged)
- RT2: none (no golden fixture holds a run floor; `tests/golden` passes unchanged). Run floors change on purpose again
  (floor rules 5); a floor saved under rules 1-4 keeps its own.
- EC: none (presentation only)
- MU: none (presentation only)
- BS1: none (no golden fixture holds a boss fight; the new BossStore lists hash only while a pillar or javelin stands; `tests/golden` 2/2 unchanged)
- AV part 2: none (presentation only; `tests/golden` 2/2 unchanged)
- BS2: none (no golden fixture holds a boss fight; the lava/melt lists hash only while molten floor is down; `tests/golden` 2/2 unchanged)
- BL: none (`tests/golden` 2/2 and `test_modifier_equivalence.gd` 3/3 unchanged: `AttackSpec.repeats` hashes only when set, the blast-merge marks are per tick and not hashed, no golden case holds a Blade pool card or a mod draw)
- PF2: none (`tests/golden` 2/2 and `test_modifier_equivalence.gd` unchanged: `AttackSpec.alive_max` is a `LATE_INT_FIELDS` field hashed only when set, no golden case holds Blade Storm, and the cap's count is read on demand, never stored)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1–Q6 (PLAN "Owner decisions") | 2026-10-14 | by role; prompts for the seven kinds without an owner design; only the Arc Caster rune and Mine Layer mines keep ground marks; code clips first; CC0 + the owner's generator; HP ×6 / damage ×1.2 per loop | 2026-10-14 |
| G1 [BOSS_SIGNATURES](BOSS_SIGNATURES.md) S1–S6 | 2026-10-14 | "boss OK": all rows as proposed | 2026-10-14 |
| G1 [BLADE_AUDIT](BLADE_AUDIT.md) B1–B7 | 2026-10-14 | "blade audit … OK": all rows as proposed | 2026-10-14 |
| G2 EC: palettes A/B/C ([ENEMY_COLOURS](evidence/ENEMY_COLOURS.md), shots in `evidence/ec_shots/`) | 2026-10-14 | "Color palette A" | 2026-10-14 |
| G1 [FINAL_BOSS](FINAL_BOSS.md) F1–F9 | 2026-10-14 | "Approve all" with changes: any loop's End leads to it and it ends the run; its own cosmic round gladiator-arena biome; Nemesis copies weapon + dash + 2–3 cards; "Phase-by-phase mix" scaling | 2026-10-14 |
| G2 MU: 3 menu and card directions ([MENU_G2](evidence/MENU_G2.md): A Salvage, B Ember stone, C Field kit × main menu, card pick, Build page) | 2026-10-14 | "menu style B" (Ember stone) | 2026-10-14 |
| G1 [BOSS_SIGNATURES](BOSS_SIGNATURES.md) S1–S6 | 2026-10-14 | pending | |
| G1 [BLADE_AUDIT](BLADE_AUDIT.md) B1–B7 | 2026-10-14 | pending | |
| G2 RT: the first 3 designed rooms ([evidence/ROOMS.md](evidence/ROOMS.md), shots in `evidence/rt_shots/`) | 2026-10-14 | "New rooms are fine in density don't need anything else, follow the line of those to create the rest" | 2026-10-14 |
| G2 MU: 3 menu and card directions | — | not yet made | |

## Open
- RT2 finding: `tests/e2e/test_e2e_bosses_2.gd::test_the_warlord_is_reached_through_the_dev_panel` fails locally on
  `3cd8b4a` (before RT2) and with RT2: "warlord: its telegraph is drawn" ([evidence/ROOMS.md](evidence/ROOMS.md) RT2).
  For the lead.
- RT2 density: several new layouts block less than RT1's 14.7-16.5 % in a typical room (the 3×1s 10.9-12.0 % on
  purpose, "fewer, smaller groups"; `room_4x4_2` 11.8 %, `room_4x4_3` 12.2 %); numbers in ROOMS.md RT2, not widened.
- v0.7.5 PR riusprime/zero-depth#6 not merged.
- RT (agent's reading, for the lead to confirm with the owner): "start, portal/boss rooms, shop and arenas keep their
  rules" read as their selection rules; the shop, arena and Overrun rooms are chosen after the floor is generated,
  so they may hold a designed interior (SR redesigns the shop room). The start hall, portal room and boss room never do.

## Blockers
- none

## History
- 2026-10-14: PF2 (agent, branch `v080-pf2` from `62b9ff7`): temporary per-phase timers and counters (not committed)
  found the Blade Storm build's cost: 36 returning blades a Double Slash swing (~75 in flight), every blade hit casting
  On Hit's slash (6.6 casts and 43.9 hits a tick against 1.3 and 23.6 without Blade Storm), 99 crescents a tick
  rebuilt as ImmediateMesh vertices, AttackFormView at its mesh cap; Split Wave was not the cause. Fix:
  `WandTable.cast_free_lines` (`blade_storm`), `AttackSpec.alive_max` (Blade Storm 36, LIMIT `attack_alive_cap`),
  `BakedMeshPools` for BladeFormView's crescents and ghosts, AttackFormCanvas skips mesh-only effects past the cap; the
  probe counts `alive_capped`. SIM_CONTRACTS §8j, CONTENT_SCHEMA, PRESENTATION §7 updated. New
  `tests/unit/sim/test_blade_storm_cost.gd` (9), one test each in `test_blade_form_view.gd` and `test_attack_forms.gd`.
  Run locally: lint clean (870 files); sim set (blade combos, Blade Storm cost, combos, four-slash, modifier
  abilities / equivalence / smoke / smoke mx4, modifiers, mx4 engine / modifiers / modifiers 2, shot cap, the ten
  wand files) 245/245; presentation (attack-form looks / forms / live, blade form view, vfx budget / layer, movement
  vfx) 72/72; `tests/golden` + `tests/arch` + `tests/content` 127/127; e2e wand_blade, damage_soak, playground 3/3.
  Not run locally: the full suite, seams (the lead's). Target: borderline (2 of 6 runs within 12 ms), reported.
- 2026-10-14: BS part 2 (agent, branch `v080-bs2` from `94c691e`): `BossGaze` (S4, new `gaze` move), `BossRicochet`
  (S5: bounces on the Turret Cross, phase-3 turret shots, the 0.5 s fairness), `BossLava` (S6: lava with fords and a
  fairness flood, new `melt` move, `NavField.set_extra` melt shapes + `reach`), `BossStore` lava/melt lists (in
  `ADDED_SINCE_V05`), six new `CAUSE_*` lines en + es and three `*_DESC`, the three boss files (trims, new params),
  `BossSignatureViews` (beam, aim line, scorch, sparks, lava, meltdown) + `BossSignatureShaders`, clips (Hive `gaze`,
  Siege `pattern_shielded`, Foundry `melt`); the readable-cause checker reads late causes and molten DoT; SIM_CONTRACTS
  §10f, CONTENT_SCHEMA §4, BOSS_FIGHTS.md, BOSS_SIGNATURES "Built in". Run locally: lint clean (858 files); sim by
  name 289/289; `tests/content` 121/121; `tests/arch` 4/4; `tests/golden` 2/2; presentation boss files 150/150;
  application saves 20/20; `tests/unit/debug` 12/12; boss/playground/dev/save e2e 26/26. Shots 7–12 (llvmpipe). The
  machine restarted mid-step; the cut runs were run again. Not run locally: the full suite, the bot sims, seams.
- 2026-10-14: BL (agent, branch `v080-bl` from `48c5bf9`): BLADE_AUDIT B1–B7. `AttackSpec.repeats` (LATE_INT_FIELDS,
  hashed only when set), `ModifierRuntime.queue_echoes`; `ModifierOp.per_level_after`; `WandCompile` B3 double casts
  and B6 `once_more`; `Attacks.merged` (+ `World.blast_*` in `ADDED_SINCE_V05`); `ItemPool.card_weight` (B5,
  `RewardsDefinition.own_weapon_card_permille`); `WandDefinition` B3/B6 fields; `ItemDefinition.index_wave` (new
  cards index last); `blade_storm`, `riposte_chain` (data, en + es, `BladeCardIcons`); card texts; perf probe's DPS
  tally and `--weapon` / `--cards`. SIM_CONTRACTS §8j, CONTENT_SCHEMA, WAND.md. Run locally: lint clean (859 files);
  new `test_blade_combos.gd` 20/20; content + arch + golden 126/126; application + debug + golden 105/105; wand/modifier
  sim files 97/97 and 271/277 then the 6 fixed (counts, lists, one queue bound) 86/86; presentation 55/55; e2e 10
  files 13/13. The machine restarted mid-run; the cut-off runs were re-run. Not run locally: the full suite, seams.
  Missed: the Gun's DPS fell ~45 %, not "an order"; the Blade Storm combo is over the frame budget (26.6 ms avg).
  Feel: OWNER ONLY.
- 2026-10-14: MU (agent, branch `v080-mu2` from `bace713`): direction B "Ember stone" shipped (owner G2 "menu style
  B"). New `src/presentation/theme/` `EmberStone` (tokens, the grain made from noise), `StoneBox` (the carved slab
  style box), `InlaySocket`, `TextFit`; `StoneCard` replaces `CrystalCard`; `PlaqueBox` / `Plaques`, `MenuStyle`,
  `MenuPanel` (slab, `EmberMarker`, title groove), `MenuBackdrop` (blur + ember wash, the main menu's own stone
  scene, sparks; reduced motion holds its clock), `BuildCard` / `BuildPicker`, `WandRow`, `BuildHud` pips, `CodexTile`,
  `AchievementRow`, `AchievementToast`, `SwapPanel` restyled; `CardFrames` is a colour table only. Retired: the crystal
  frames / plaques / build-picker art, their manifests, crop scripts, asset tests, `BuildArt`; credits list rebuilt.
  Shots `scripts/shots/mu2_shots.gd` (real screens, en + es). Run locally: lint; `tests/unit/presentation` 577/577;
  `tests/content` + `tests/arch` 123/123; menu/pick/build/codex/shop/swap/achievements/shell/pad e2e (17 files) 40/40.
  An earlier presentation run under machine load had 2 stone-spike failures (pass alone and in order, on this tree
  and on `bace713`; the clean rerun is green). Not run locally: the full suite. The look: OWNER ONLY. Open for the
  lead: `tests/MIN_TEST_COUNT` (about 8 tests fewer: the retired art's asset tests).
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
- 2026-10-14: AV part 2 on `v080-av2` (agent, from `0dfa2c7`): `BossStrikeLooks` (a look per boss kind and move;
  every ground attack in `data/bosses` has one), styled marker fills in `TelegraphViews` (tracking dull and unfilled,
  locked hot; edges unchanged), and `BossStrikeViews` (+ `BossStrikeShapes`, `BossStrikeMeshes`, `BossStrikeFx`)
  drawing each strike on the sim's strike tick from WorldReader, pooled (six capped MultiMeshes, 24 strikes), through
  VfxCore's sprite, light and decal budgets and `VfxLayer.burst` / `BurstBudget`. The shots showed MultiMesh instance
  colours coming through white in these shaders and a bright molten bed turning cream under the stage's exposure: the
  colours now ride in the custom data and the bed is dimmer (seams hot). New tests `test_attack_visuals_2.gd` (11) and
  e2e `test_e2e_boss_strikes.gd` (1); part 1's fist-slam test follows the styled flash. Run locally: lint clean (831
  files); presentation set 148/148; `tests/arch` 4/4; `tests/golden` 2/2; `tests/content` 133/133; boss e2e 11/11.
  Shots `scripts/shots/attack_visuals_2.gd` (24, llvmpipe). Not run locally: the full suite. The look is OWNER ONLY.
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
- 2026-10-14: G2 RT answered: the first three layouts' density is right; the other 21 follow them (RT2).
- 2026-10-14: the owner's final boss (O16–O17): their Tripo file split into three models (Colossus, Prism, Nemesis; no piece cut); G1 FINAL_BOSS.md written.
- 2026-10-14: G1 FINAL_BOSS answered (rows in FINAL_BOSS.md "Decisions").
- 2026-10-14: RT2 (agent, branch `v080-rt2` from `3cd8b4a`): 21 layouts written by `scripts/content/room_layouts.py`
  (new prefabs: small corners, wall spurs, a building outline and its broken corner, a central block, a diagonal band;
  RT1's prefabs and three files byte-identical); the script's checks gain a regions flood, a wall-slit check, 1-cell
  sizes and a 3 cm spacing margin (the game's cm rounding broke two 4×4 groups on a 2.2 m edge). `FLOOR_RULES` 5,
  `RunState.rt1_rooms`, `RunSaver.RT1_LAYOUTS`/`rt1_layouts`: a rules-4 floor rebuilds with RT1's three, the same as
  RT1's code built it (90 floors compared). Tests: content (24 layouts, 3 per size), the run-floor property test over 60
  floors with every size (kept share per size), the RT1 old save. Run locally: lint; content 136/136; arch + golden
  6/6; map/generator sim tests by name (one 3000 s run timed out inside `test_ice_patches.gd` with the others green;
  run again on its own, see ROOMS.md); starglow 6/6; application + debug 104/104; dresser/biomes 36/36; e2e set 7/7;
  e2e shard 127/128: `test_e2e_bosses_2.gd` "warlord: its telegraph is drawn" fails, and fails the same on the base
  `3cd8b4a` without RT2 (open, not fixed here). Shots: 21 in Ruins (gl_compatibility on llvmpipe), 8 copied to
  `evidence/rt_shots/`. Not run locally: the full suite.
