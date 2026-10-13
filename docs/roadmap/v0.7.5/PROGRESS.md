# v0.7.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/v0.7.5-new-ground`, cut from `main` at `a20850f` (owner N1).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| CX | The Codex: a journal of every card (by pool), enemy, boss and biome, from the main menu and the pause menu; an entry unlocks the first time you meet it and shows its card or emblem, its text and your counts, kept in the profile ([evidence](evidence/CODEX.md)) | `v0.7.5 Step CX` commit (branch `v075-cx`) |
| NB1 | Biome 4, Frozen Shore: a cold moonlit snow biome over a frozen sea, ice patches you slide on, in the run's biome draw (3 floors from 4) | `v0.7.5 Step NB1` commit |
| AP | The Ascension portal: after the last floor's boss a rising column of golden light stands where the gate was; walking in offers End the run (a victory, the recap now counts loops cleared) or Ascend (floor 1 of the next loop with your whole build, new biomes, harder each loop, endless), or Not yet; "Loop 2 · Floor 1" on the HUD; shops and curses keep every two floors across loops; Continue works mid-loop and old saves load as loop 1 ([evidence](evidence/ASCENSION.md)) | the `v0.7.5 Step AP` commit on `v075-ap` |
| MG | Floors of 16-20 rooms (was 11-13) with bigger rooms and an extra-large 4×4; 20 % fewer challenge rooms (3.23 → 2.42 a floor); the shop on floors 1, 3, 5 …; cursed chests only on floors 1, 3, 5 …, at most one a floor; all tunable in data (F10); a save made before v0.7.5 resumes on its v0.7.0 floor ([`evidence/MAPS.md`](evidence/MAPS.md)) | the `v0.7.5 Step MG` commit on `v075-mg` |
| AC | Local achievements: 37 to unlock (floors, wins, each boss and biome from the data, the wand, kills, sealed rooms, risks, the Codex, Ascension), a toast when one unlocks, an Achievements page in the Codex from both menus, kept in the profile ([evidence](evidence/ACHIEVEMENTS.md)) | `v0.7.5 Step AC` commit (branch `v075-ac`) |
| NB2 | Biome 5, Starfall: a cosmic biome, the floor a floating island in a starry void with nebula light and drifting rock and crystal islands, starglow pools that speed your step, in the run's biome draw (3 floors from 5) ([evidence](evidence/STARFALL.md)) | `v0.7.5 Step NB2` commit (branch `v075-nb2`) |
| SM | The small things: a card's level on every pick card ("Lv 1", "Lv 2 → 3", the legendary "Lv N → 5") and on the HUD's wand pips and the Build page; ten first-run hints, each once, never blocking, with the keys of the device you use (Options: Show hints, Reset hints); the credits generated from the repo's manifests, fonts and addons, with the app icon; an Interface size option and reduced-motion / colour-blind fixes from an accessibility pass; the dev panel behind one release switch, left ON ([evidence](evidence/SMALL_THINGS.md)) | `v0.7.5 Step SM` commit (branch `v075-sm`) |
| BM | The owner's Warlord, Hive Lens and Foundry models replace their code bodies and move from their bones: the Warlord walks, carries and lifts its shield, raises and plants, couches and thrusts, draws and throws its spear, flinches, reels and falls when it dies; the Hive Lens bobs and rolls, its tails sway and trail, its eye turns to you, it opens, closes, splits and dives; the Foundry's legs (cut from its mesh) step in pairs as it pours, vents and launches. Every boss is drawn 1.3× bigger (owner N18) ([evidence](evidence/BOSS_MODELS.md)) | `v0.7.5 Step BM` commit (branch `v075-bm`) |
| BF1 | Boss fights, part 1: the Gatekeeper and the Warlord fight dodge-first: slow fireball patterns in their own looks (Rock Rings, Cross Quake; Shield Wall, crossing walls, Javelin Fan), ground circles and lanes that follow you then lock and flash for 0.8 s before they strike (move after the lock and you're out), a crystal shield while the signature pattern runs, open between patterns; HP ×1.25; phases add and speed patterns. All six bosses 1.3× bigger and fought in the 4×4 room (N18). The pattern engine is data for the next bosses ([evidence](evidence/BOSS_FIGHTS_1.md)) | `v0.7.5 Step BF1` commit (branch `v075-bf1`) |
| PG | The Playground (owner N20): a main-menu row into one big 4×4 room with your weapon; F1 opens a panel (the game waits) to add any card at any level or remove it, place dummies (never die, or a set HP), any enemy or boss with a click and delete with a right click, switch between the five biomes, god mode and heal; a DPS meter (last 5 s, average, total, time, every source by its card's name); nothing saved or recorded ([evidence](evidence/PLAYGROUND.md)) | `f612776`, `f85657f`, `519a445`, `431b543`, `d1ed9ac` (branch `claude/playground`) |

## Goldens changed on purpose
- none yet (CX changed none: the Codex is outside the sim; the replay golden passed in its content / arch run)
- NB1: none. `tests/golden` passes unchanged; ice is laid only on Frozen Shore floors and is not hashed itself.
- MG: none. `tests/golden` passes with its fixtures unchanged; every seed's floor layout changed on purpose (N9), and no golden fixture holds one
- AC: none. No sim file changed; `tests/golden` passed in its units run (evidence/ACHIEVEMENTS.md).
- NB2: none. `tests/golden` passes unchanged; starglow is laid only on Starfall floors and is not hashed itself. (A
  fifth biome changes every run seed's biome draw; no golden pins one.)
- AP: none. `tests/golden` passes unchanged: the loop and Ascension fields are hashed only past loop 1 / on the Ascension floor, so every loop-1 floor other than the last hashes as before (the last floor's hash changes on purpose; no golden fixture holds one)
- SM: none. The one sim edit is a read key (`Wand.read`'s `wand`), nothing hashed; `tests/golden` not run by the agent (the lead's full suite).
- BM: none. No sim file changed (presentation, assets and docs only); `tests/golden` not run by the agent.
- BF1: none. `tests/golden` passes unchanged (the kernel replay is boss-free; the fireball look column is hashed only once a fireball has flown). The boss fights' own hashes change on purpose (new attacks, patterns, HP, radius, rooms); no golden fixture holds one
- PG: none. One sim file gained a function (`FloorGenerator.one_room`) and one a read (`WorldReader.has_gate`); `tests/golden` passed in the seams run.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The lead's readings in PLAN (the Ascension loop, the cosmic biome's name, the achievement list) | — | the owner asked for no interventions; corrected at the playtest | |
| EI-05: the sub-streams `map:ice` (NB1), `map:starglow` (NB2) and `map:overrun` (since v0.6.0) aren't named in the locked stream list; add them to EI-05? | — | pending (lead keeps them, the same pattern the owner approved for `map:event` on 2026-10-08) | |
| SM: the owner's credit line (`CREDITS_OWNER`, "…" since v0.0.1, O4); the AI 3D generator's terms for shipping the kit models | — | pending (OWNER ONLY) | |
| EI-05: the sub-streams `map:ice` (NB1) and `map:overrun` (since v0.6.0) aren't named in the locked stream list; add them to EI-05? | — | pending (lead keeps them, the same pattern the owner approved for `map:event` on 2026-10-08) | |
| PG: the Playground's entry, dummies, DPS meter and panel look | 2026-10-13 | "Main menu row"; "Never die + optional HP"; "Total + per-source"; "Dev-tool style, no mockups" (G2 waived for this tool) | 2026-10-13 |

## History
- 2026-10-12: plan from the owner's message (verbatim in PLAN), written while the v0.7.0 suite ran.
- 2026-10-13: v0.7.0 merged into `main` (`a20850f`); this branch, `claude/v0.7.5-new-ground`, cut from it (owner N1:
  "create a new branch"). Wave 1 (MG, NB1, CX) was started from `6381fcb`, the same tree as `a20850f`.
- 2026-10-12: CX (the Codex) built on `v075-cx` from `6381fcb`; the lead's readings are in PLAN "CX"; evidence in
  [`evidence/CODEX.md`](evidence/CODEX.md). The pause menu gained a Codex row (after Options) and the main menu one
  (after Credits); the menu e2e that count rows were updated. Not run by the agent: the full suite (the lead's, once
  per wave).
- 2026-10-12: NB1 Frozen Shore built on `v075-nb1` (from `6381fcb`): biome data, ice in the sim (`map:ice`), its look, tests; evidence [`evidence/FROZEN_SHORE.md`](evidence/FROZEN_SHORE.md). Not pushed.
- 2026-10-13: AP (agent, branch `v075-ap` from `9bbe930`): the Ascension portal and the endless loop; the lead's
  readings are in PLAN "AP"; evidence [`evidence/ASCENSION.md`](evidence/ASCENSION.md) (with "For the merge": AC's
  `achievement_tracker.report(&"runs:ascended")` is called, guarded, and End the run is outcome 1). The shop and curse
  cadence now read the run's floor across loops (MG's open item). Not run by the agent: the full suite, bot sims, the
  save bench. Open for the lead: MIN_TEST_COUNT (AP adds 21 tests), the per-loop numbers (owner tuning).
- 2026-10-13: MG (agent, branch `v075-mg` from `6381fcb`): `data/map` (new `MapDefinition`, in the F10 panel's
  Difficulty page), `FloorCadence` for the shop and cursed chests, arena share 0.11, `RunState.floor_rules` so an
  old save keeps its floor. Measured before/after with `scripts/checks/map_stats.gd` (evidence/MAPS.md). Tests run by
  the agent (not the full suite): lint clean; `tests/unit/sim` 910/910 (its test_curses and test_shop_placement were
  edited during the run and re-run: with test_old_saves, 22/22); content + arch + golden + unit/application +
  unit/debug 160/160; 15 e2e files (shop, curses, events, arenas, arena, run_flow, saves, old_save, floor, routes,
  minimap, rewards, dev_master_panel, portal, after_boss) 26/26; 8 presentation files (minimap, minimap orientation,
  stage dresser, shard dressing, shop, routes, event and reward views) 54/54. Open for the lead: the full suite;
  the save snapshot cost on a bigger floor (save_bench NOT YET RUN); AP must pass the run's absolute floor number to
  the shop and curse cadence.
- 2026-10-13: AC (local achievements) built on `v075-ac` from `fa70fcb` (CX and NB1 merged); the lead's readings are in
  PLAN "AC"; evidence in [`evidence/ACHIEVEMENTS.md`](evidence/ACHIEVEMENTS.md). The Codex gained a fifth page
  (Achievements); `runs:ascended` is left for AP to report. Not run by the agent: the full suite and the bot sims
  (the lead's, once per wave). Not pushed.
- 2026-10-13: NB2 Starfall built on `v075-nb2` (from `fa70fcb`, CX and NB1 merged): biome data, starglow pools in the sim (`map:starglow`), the starry void edge, code-made pieces, its look, tests; evidence [`evidence/STARFALL.md`](evidence/STARFALL.md). Not pushed. Not run by the agent: the full suite and bot sims (the lead's, once per wave).
- 2026-10-13: SM (agent, branch `v075-sm` from `0e58966`): card levels on the pick cards and wand pips, the first-run
  hints (`HintStore`, `OnboardingHints`; Options → Accessibility: Interface size, Show hints, Reset hints), the
  generated licence list (`scripts/content/build_credits.gd` → `data/credits/licences.tres`; a licence line added to
  `assets/models/manifest.json`), the app icon on the credits, the accessibility fixes, `DevGate` (ON). The lead's
  readings are in PLAN "SM"; evidence in [`evidence/SMALL_THINGS.md`](evidence/SMALL_THINGS.md). Run by the agent:
  lint; content + arch + unit/application + unit/app 193/193; 13 presentation unit files 88/88; 31 e2e files 61/61;
  re-runs 14/14, the dev switch e2e 1/1 and a final 16 files 52/52 on `191dbcd`; screenshots en + es at 1280×720.
  Not run by the agent: the full suite, goldens, the bot sims. Shared files touched additively:
  `main.gd`, `options_menu.gd`, `strings.csv` (26 rows), `project.godot` (a `[game]` section). Not pushed.
- 2026-10-13: the wave's suite on `5641b0f` was stopped before its end (the 2-hour limit, then superseded); one full
  suite on every step (MG, NB1, NB2, AP, CX, AC, SM) at `0410800`, from a clean worktree (`bash scripts/verify.sh`):
  `verify exit 1`, `Tests 1724`, `Passing Tests 1722`, `Failing Tests 2`:
  - `test_e2e_damage_soak.gd` "no orphan nodes" 90 ≠ 0: the F10 panel's Tools page (a `DevPanel` Main builds for it)
    was left an orphan when the panel closed without visiting Tools (30 nodes per open; `test_e2e_ascension` opens it 3
    times). Fixed in `DevMasterPanel` (freed with the panel; kept, not freed, when another page is shown). Ascension +
    card levels + damage soak in one process: 6/6; the four dev-panel e2e 6/6.
  - `test_dev_master_panel.gd` "data/achievements is in the panel": achievements aren't balance, so the folder joins
    the test's not-balance list (with audio, credits, patch notes). `tests/unit/debug` 10/10.
  The every-card soak: `SOAK| kills=265 events=6696 most_in_a_tick=188 limits=0`. MIN_TEST_COUNT 1598 → 1724. Pushed;
  the PR into `main`.
- 2026-10-13: owner: the audit branch `claude/sharp-lovelace-74ii7v` is the base to build on; merged into this branch
  (6 conflicts, both sides kept; import and lint clean; the six files' tests 45/45; seams NOT YET RUN at this line).
  Owner N14–N16: the three boss models, the dodge-first boss fights and the enemy fireballs; design for the owner in
  `docs/design/BOSS_FIGHTS.md`.
- 2026-10-13: seams on the audit merge `01c1e2f` from a clean worktree (`bash scripts/ci/seams.sh`): 52 scripts,
  `Tests 266`, `Passing Tests 266`, `check_gut_log: ok`. The first sharded GitHub run (PR #6 at `8199c3e`): every
  job green; `verify` finished 71 min after the start (sim_b 68 min, sim_a 21, presentation 8, e2e 7, checks 3,
  rest 2). sim_b's five slowest files (local JUnit times) move to a shard of their own, `sim_c`.
- 2026-10-13: owner: "some lighting adjustments have been made, so before pushing this one into main also merge this
  branch into yours to make a complete merge claude/optimistic-ride-x1sdnu". Merged (`3bb043a`, look pass v3: warm
  dusk Ruins lighting, tamed glow and fire lights; built on the audit branch; no conflicts).
- 2026-10-13: BM (agent, branch `v075-bm` from `67c9af9`): the owner's three boss models installed (manifest,
  sha256, extracted textures, the credits list regenerated), SPECS read from the committed raw render
  (`scripts/shots/boss_models.gd mode=raw`), the rigged Warlord and Hive Lens posed from their own bones
  (`BonePoser`), the Foundry's legs cut in code (`BossRig`), a `shielded` pose hook and `anchor()` points for BF,
  the Warlord's death fall (ActorViews keeps it 1.6 s). Owner N18 (sent by the lead): every boss drawn 1.3×
  (`BossModels.SIZE_SCALE`). Run by the agent: lint; `tests/unit/presentation` + `tests/content` 610/610; the boss
  e2e (bosses, bosses_2, boss_challenge, after_boss) 6/6; screenshots under xvfb + llvmpipe. Not run by the agent:
  the full suite, export smoke, goldens. Shared files touched: `actor_views.gd` (the death hand-off, the boss
  height), `data/credits/licences.tres`. Not pushed.
- 2026-10-13: seams (`bash scripts/ci/seams.sh`, clean worktree): on the lighting merge `36a4d71` `Tests 266`,
  `Passing Tests 266`; on the BM merge `ed5b447` `Tests 266`, `Passing Tests 266`. GitHub `verify` on `f388716`
  (six shards): green, 15:42:53 → 16:10:25 UTC (27.5 min; sim_a 27, sim_c 25.5, sim_b 22, e2e 11, presentation 9,
  checks 2, rest 1.5). Pushed.
- 2026-10-13: BF1 (agent, branch `v075-bf1` from `edda87e`): the bullet pattern engine (`BulletPatternDefinition`,
  `BulletPatterns`, `PatternCompiler`), tracked-then-locked markers (`lock_seconds`, moves `marks` and `row_lanes`,
  `BossDodge`), the shielded signature (`Damage`), the Gatekeeper's and the Warlord's fights rebuilt, fireball /
  marker / shield views (`FireballViews`, `TelegraphViews`, `BossShieldView`); N18 (lead's message): all six bosses
  radius ×1.3 and 4×4 rooms. Reads for BM's avatars: `WorldReader.boss_shielded`, `boss_pattern`. Evidence
  [`evidence/BOSS_FIGHTS_1.md`](evidence/BOSS_FIGHTS_1.md). Not run by the agent: the full suite, bot sims. Not pushed.
- 2026-10-13: BF1 merged (`4d772cc`); the lead wired BF1's `WorldReader.boss_shielded` into BM's shielded pose
  (`81a07b5`; boss model views + boss e2e 27/27). Seams on `81a07b5` (`bash scripts/ci/seams.sh`, clean worktree):
  `Tests 275`, `Passing Tests 275`. Pushed. BF2, BF3 and EF started from `81a07b5`.
- 2026-10-13: owner N20, the Playground (a creative mode to test builds, dummies, bosses and biomes); plan in
  [`../../tools/PLAYGROUND.md`](../../tools/PLAYGROUND.md), built on `claude/playground` from `d5a5602`.
- 2026-10-13: PG built on `claude/playground` (PG1-PG5, evidence [`evidence/PLAYGROUND.md`](evidence/PLAYGROUND.md)): seams 288/288, presentation units + 11 e2e 516/516; a BM bug in `ActorViews._drop_missing` (get_meta with a null default) fixed on the way. Not merged into `claude/v0.7.5-new-ground` yet (that branch's lead merges it, so BF's boss changes reach the Playground).
