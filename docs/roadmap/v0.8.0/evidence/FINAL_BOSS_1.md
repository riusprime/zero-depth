# v0.8.0 Step FB1: End the run leads to the final boss; the arena, one bar in three bodies, the Colossus (evidence)

Owner O16–O17 (2026-10-14, verbatim in [`../FINAL_BOSS.md`](../FINAL_BOSS.md)); G1 FINAL_BOSS answered the same day
(rows F1–F9 in its "Decisions"). FB1 builds F1–F4 and part of F7–F9; the Prism (F5) and the Nemesis (F6) are stand-in
bodies here, their fights are FB2 and FB3.

Build: branch `v080-fb1` from `cfe34fb`. Every command below ran on that branch's working tree before the
`v0.8.0 Step FB1` commit (its SHA is in the hand-off report, not here). Machine: a shared cloud container, Godot
4.7.2.stable; shots on llvmpipe (software Vulkan) under xvfb, not the owner's hardware.

## What was built

| Row | As built | Starting values (data; F10 Bosses page lists `data/final_boss`) |
|---|---|---|
| F1 | On the run's last floor, on **any loop**, the Ascension portal's **End the run** (its line now "Face what waits beyond the portal: beat it and the run is won.") sets `RunState.final_fight` and the next world is the final arena, not the end panel. **Ascend** and **Not yet** are unchanged. Beating the last body ends the run as a victory (`WorldReader.outcome() == 1`); the recap adds the "true ending" line; a death is the normal death recap; no loop after it | `data/run/three_floors.tres`: `final_bosses` [colossus, prism, nemesis], `final_name_key` BOSS_HOLLOW_CROWN, `final_arena` hollow_arena, `final_shatter_seconds` 1.5 |
| F2 | Its own biome, **the Hollow Arena** (`FinalArenaDefinition`, category `final_arena`): one round room, its wall a ring of 32 segments (`FinalArena`, sim, integer angles via `Kin`); the hero enters near the camera side, the sealed gate is on the far side. Drawn by `FinalArenaStage`: a cracked, veined disc floor (shader, or `ground_arena.png` when the owner installs it), wall blocks with glowing veins, tiered seating round the far half (open toward the camera), 12 pillars with floating shards, 8 braziers with light, the gate with a crystal portcullis, the star void with nebulae and floating islands. Each piece looks for the owner's model by its art id (`arena_wall_segment`, `arena_gate`, `arena_pillar`, `arena_brazier`, `ground_arena`; art list §7) in `assets/models/arena/` and keeps the code piece until it is installed and listed in the manifest | radius 15 m, 32 segments (16/32/64 allowed) |
| F3 | One boss, **the Hollow Crown**: one bar in three named segments (the Colossus, the Prism, the Nemesis). A body whose segment runs out keeps 1 HP and **shatters** (`FinalBoss.SHATTER`, 1.5 s, invulnerable): every hostile shot on the floor and every pending one is cleared, the bar says SHATTERED; then it leaves as a normal `BOSS_DEFEATED` (the Codex counts the kill) and the next body rises from its shards at the same place. A save is written at the start of each body (`RunSaver`, the run's `final` flag); Continue resumes there | shatter 1.5 s |
| F4 | **The Colossus** (`BossColossus`): **fist combos** (2 or 3 swings that track you until each locks, alternating right and left fist, closing with a two-fisted slam), **leap slams** that track you, lock and land in a **shockwave ring** (a ring pattern with its gap toward you), **spike lines that chase you** (spikes laid one by one toward where you are, stopping at the wall) and **radial bursts** round it, and **boulder throws** (lobbed rocks on tracked circles that shatter into a small ring of shards, never spawned on you). Every strike shows locked 0.5 s before it lands. Fast between attacks, no shield phases. Its HP scales with loops like the other bosses | HP 1,200 (floor-3 scaling and the loop's ×6 apply), r 1.6 m, 4.2 m/s; phase 2 at 50 % (opens with a spike burst, speed ×1.15, cooldowns ×0.75); combos 2 × 0.7 s / 3 × 0.65 s; leap ring 24 shots 6.5 m/s; chase 10 spikes × 1.6 m (two lines from phase 2: 12 × 50°); burst 6 rays × 7 spikes; boulders 2 / 3 rocks, 8 shards |
| F5, F6 | Stand-ins only (TODO FB2 / FB3 in code): the Prism floats and fires two existing patterns (Prism Spiral, Petal Bloom); the Nemesis sweeps, charges and fires a plasma fan | Prism HP 1,400; Nemesis HP 860 |
| F8 (part) | Strings en + es (31 rows): the three bodies and their Codex lines, the Hollow Crown, the arena, 9 causes of death, the true-ending recap line, the SHATTERED bar label, the playground buttons. Codex: a "Final boss" section in Bosses (the three bodies). Three achievements: **Crown Breaker** (beat it, `final:won`), **Untouched** (beat a body without being hit, `final:no_hit_phase`), **Beyond the Loop** (beat it after a loop, `final:won_looped`) | — |
| F9 (part) | The existing boss sounds: the Colossus as the Gatekeeper, the Prism as the Hive Lens, the Nemesis as the Warlord | — |

**Animation (owner Q4: code clips first, the owner's animated model replaces them by name):** `BossRig` cuts the
Colossus's mesh into its pieces (union-find over shared vertices): body, chest, halo and the two fists, each fist its
own bone hung from a shoulder pivot. `ColossusClips`: idle (fists hovering), walk (fists pumping), combo (a `hook`
parameter the avatar maps to the right fist, then the left, and both for the slam), leap, marks (boulder hauled and
hurled), spike_chase (one fist punched down), spike_burst (both slammed down), shielded, flinch, stagger, roar, rise,
death; the halo spins faster while it flares. `FinalStubClips` give the Prism and the Nemesis whole-body clips.
`FinalBodyAvatar`: a shattering body trembles, glows from inside and sinks a little; `FinalBossViews` draws the
gathering ring of light, the burst of 36 shards when it leaves, and the shards pulled into the next body as it rises.
Strikes: combo swings throw dust arcs and the slam a crater (`BossStrikeViews`), the spikes stand as clusters of stone
spikes (`StoneSpikeViews`), the boulders fly as tumbling 3D rocks (`BossShieldView`).

**Models:** `assets/models/bosses/final_boss_{colossus,prism,nemesis}.glb` from the owner's split file
(FINAL_BOSS.md "The models"), listed in `assets/models/manifest.json` with their sha256, credits rebuilt
(`data/credits/licences.tres`, 45 files). `BossModels.SPECS` holds each one's height and facing, measured from raw
renders (`scripts/shots/boss_models.gd ids=...`); no outline (as the other boss models). They load only in the final
arena (or when the playground summons it): `preload_all(final)`.

**Asset size (reported, not solved):** each `.glb` embeds its own copy of the same 8192×8192 colour texture, and
Godot's import extracts it beside each one: 3 × ~9.3–9.9 MB `.glb` + 3 × 9.2 MB `.jpg` (byte-identical) ≈ 56 MB added
to the repository. The imported texture is capped at 4096 (`process/size_limit=4096` in the three `.jpg.import`), so
the game's memory holds 4096² each. Shrinking the source (one shared, smaller texture) needs the owner's re-export or
a decision to re-encode their file; FB1 doesn't change their file.

**Old saves:** the final bosses are a separate content category (`final_bosses`) appended after the floors' bosses,
so a saved boss index never moves. `World.final_fight` and `BossFlow.final_next` are in `WorldSnapshot.ADDED_SINCE_V05`;
`FinalFight` hashes only when present (no golden holds it).

**Changed behaviour of existing tests (on purpose):** `test_ascension.gd` / `test_e2e_ascension.gd`: End the run now
leads to the final boss (renamed `test_end_the_run_leads_to_the_final_boss` / `..._final_arena`).
`test_boss_models.gd`: `preload_all(true)` to count the final bodies too. `test_codex.gd`: the Bosses section counts
`bosses` + `final_bosses`. `test_playground.gd`: the bosses placed in two columns (9 tables now). Achievements:
`runs:won` is now counted when the final boss is beaten (End the run no longer wins at once).

## Tests (raw)

Lint, on the final tree:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
892 files would be left unchanged
Success: no problems found
$ bash scripts/ci/gut_shard.sh --check
gut_shard: ok (316 test files in 6 shards)
```

Each batch ran as
`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<the files, comma-separated> -gexit`.

1. Sim (run before the last fix below; the final-boss files re-ran after it, batch 7):
   `test_final_boss, test_colossus, test_ascension, test_world_snapshot, test_run_flow, test_bosses, test_bosses_2,
   test_boss_gates, test_boss_challenge, test_readable_cause, test_boss_markers, test_after_boss, test_routes,
   test_portal_transit` (tests/unit/sim)
   ```
   Scripts              14
   Tests               184
   Passing Tests       184
   Asserts           55138
   Time              571.168s
   ---- All tests passed! ----
   ```
2. Content, arch, golden, application, debug and the presentation boss files (67 scripts: all of `tests/content`,
   `tests/arch`, `tests/golden`, `tests/unit/application`, `tests/unit/debug`, and `test_ascension_views,
   test_attack_visuals, test_attack_visuals_2, test_attack_view, test_boss_animations, test_boss_challenge_views,
   test_boss_fight_views, test_boss_fight_views_3, test_boss_fights_2_views, test_boss_models, test_boss_models_2,
   test_boss_rigs, test_boss_signature_views, test_boss_signature_views_2, test_boss_telegraph_parity,
   test_boss_views, test_bosses_2_views, test_codex_view, test_final_boss_views, test_stage_dresser, test_stage_mood,
   test_audio_director, test_run_recap, test_hud_style`):
   ```
   Scripts              67
   Tests               435
   Passing Tests       429
   Failing Tests         6
   Asserts           1666469/1666487
   Time              143.683s
   ---- 6 failing tests ----
   ```
   The six: `test_codex.gd` (the Bosses count), `test_playground.gd` (the boss column), `test_boss_models.gd` (the
   loaded count): fixed as listed above, batch 3. And three in `test_attack_visuals_2.gd`, **not FB1's**: they fail
   the same at `cfe34fb` (FB1's base), reproduced there:
   ```
   [Failed]:  [STRING_NAME()] expected to not equal [STRING_NAME()]:  foundry meltdown has a look
   [Failed]:  [STRING_NAME()] expected to not equal [STRING_NAME()]:  hive_lens gaze has a look
   [Failed]:  [STRING_NAME()] expected to not equal [STRING_NAME()]:  hive_lens gaze_fast has a look
   [Failed]:  [STRING_NAME(fd_molten)] expected to equal [STRING_NAME()]:  foundry meltdown strikes with its look
   [Failed]:  [318] expected to equal [120]:  foundry meltdown: drawn on the sim's strike tick
   [Failed]:  [-1] expected to equal [48]:  hive_lens gaze: drawn on the sim's strike tick
   [Failed]:  [4] expected to equal [0]:  hive_lens gaze: no hit lands without its strike drawn
   [Failed]:  [-1] expected to equal [48]:  hive_lens gaze_fast: drawn on the sim's strike tick
   [Failed]:  [5] expected to equal [0]:  hive_lens gaze_fast: no hit lands without its strike drawn
   [Failed]:  foundry meltdown: its marker is styled
   [Failed]:  hive_lens gaze: its marker is styled
   [Failed]:  hive_lens gaze_fast: its marker is styled
   Tests                11
   Passing Tests         8
   Failing Tests         3
   ```
   (BS2 added the Gaze and the Meltdown after AV2 wrote this test; neither has a `BossStrikeLooks` entry. Left for
   the lead: FB1 doesn't touch those bosses.)
3. The three fixed files: `test_boss_models, test_codex, test_playground`:
   ```
   Scripts               3
   Tests                40
   Passing Tests        40
   Asserts             457
   ---- All tests passed! ----
   ```
4. More sim boss files: `test_boss_fights, test_boss_fights_2, test_boss_fights_3, test_boss_pressure,
   test_boss_room_builder, test_boss_signatures, test_boss_signatures_2, test_bullet_patterns, test_damage,
   test_enemy_fireballs, test_rewards, test_state_hasher`:
   ```
   Scripts              12
   Tests               141
   Passing Tests       141
   Asserts           509709
   Time              365.726s
   ---- All tests passed! ----
   ```
5. E2e: `test_e2e_final_boss, test_e2e_ascension`:
   ```
   Scripts               2
   Tests                 4
   Passing Tests         4
   Asserts             157
   Time              103.349s
   ---- All tests passed! ----
   ```
6. E2e that reach the change: `test_e2e_bosses, _bosses_2, _boss_dodge, _boss_dodge_2, _boss_dodge_3,
   _boss_signatures, _boss_signatures_2, _boss_strikes, _stone_spikes, _boss_challenge, _after_boss, _playground,
   _saves, _old_save, _achievements, _codex, _run_flow, _dev_master_panel, _dev_panel`:
   ```
   Scripts              19
   Tests                29
   Passing Tests        29
   Asserts             714
   Time              229.017s
   ---- All tests passed! ----
   ```

**A bug the shots found, fixed:** the first render of the shatter showed the Colossus as a Brood Mother egg.
`FinalBoss.SHATTER` was 7, the value BS1 gave `BossSignatures.EGG` (the views read both off the state alone). It is
10 now; `test_the_shatter_state_is_its_own` (sim) and an egg check in the shatter view test guard it. After the fix:

7. `test_final_boss, test_colossus, test_final_boss_views, test_final_achievements, test_boss_signature_views`:
   ```
   Scripts               5
   Tests                54
   Passing Tests        54
   Asserts            3064
   Time              37.374s
   ---- All tests passed! ----
   ```
8. `test_e2e_final_boss, test_e2e_bosses_2, test_world_snapshot, test_old_saves, test_run_saves`:
   ```
   Scripts               5
   Tests                35
   Passing Tests        35
   Asserts            3948
   Time              220.407s
   ---- All tests passed! ----
   ```

New tests: `tests/unit/sim/test_final_boss.gd` (22: the flow, the shatter, the clamp, saves at phase start, the
playground jump, the state's own value), `tests/unit/sim/test_colossus.gd` (11: each move, the locks, the fairness, the
determinism), `tests/unit/application/test_final_achievements.gd` (4), `tests/unit/presentation/test_final_boss_views.gd`
(10), `tests/e2e/test_e2e_final_boss.gd` (1: End the run → the arena → shatter → the Prism → Main menu, Continue at
the Prism → the win, the true ending line, Crown Breaker). Support: `tests/support/final_lab.gd`.

Not run locally: the full suite (CLAUDE.md: once per version, on GitHub); bot balance sims (not asked).

## Shots

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss.gd
final_boss: res://build/shots/v0.8.0/fb1/1_arena_overview.jpg (tick 121)
final_boss: res://build/shots/v0.8.0/fb1/2_arena_at_play_zoom.jpg (tick 121)
final_boss: res://build/shots/v0.8.0/fb1/3_colossus_rising.jpg (tick 51)
final_boss: res://build/shots/v0.8.0/fb1/4_combo_hook_wound_up.jpg (tick 92)
final_boss: res://build/shots/v0.8.0/fb1/5_combo_hook_lands.jpg (tick 111)
final_boss: res://build/shots/v0.8.0/fb1/6_combo_two_fisted_slam.jpg (tick 195)
final_boss: res://build/shots/v0.8.0/fb1/7_leap_slam_landing_shockwave.jpg (tick 156)
final_boss: res://build/shots/v0.8.0/fb1/8_spike_lines_chasing.jpg (tick 136)
final_boss: res://build/shots/v0.8.0/fb1/9_spike_burst_radial.jpg (tick 124)
final_boss: res://build/shots/v0.8.0/fb1/10_boulder_in_the_air.jpg (tick 105)
final_boss: res://build/shots/v0.8.0/fb1/11_colossus_shatters.jpg (tick 74)
final_boss: res://build/shots/v0.8.0/fb1/12_prism_rises_from_the_shards.jpg (tick 182)
$ ... -s scripts/shots/final_boss.gd -- 13      (re-rendered after its attack id was fixed)
final_boss: res://build/shots/v0.8.0/fb1/13_nemesis_stand_in.jpg (tick 134)
```
All 13 are in [`fb_shots/`](fb_shots/) (1280×720, the HUD's boss bar on top). The world is the one the game builds
after End the run (`FinalLab`: the run's last floor, the bodies scaled, `FinalArenaScenario`); the hero is held still
and invulnerable, the Colossus's own attack picks are switched off and each shot starts the move it shows.

## Owner only

- The feel of the fight, its pace and difficulty, the arena's look, the Colossus's clips: **OWNER ONLY**.
- Frame rate on the owner's hardware with the three models: **OWNER ONLY** (not measured here).
- The final names (working names in the strings): **OWNER ONLY**.
