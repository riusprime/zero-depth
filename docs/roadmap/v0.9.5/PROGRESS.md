# v0.9.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v095-feedback`, cut from `main` at `d33bc82a` (v0.9.0, PR
riusprime/zero-depth#9).

## Where we are
(The lead keeps this block current at every push; the SessionStart hook prints it. Updated 2026-10-25.)

- **Phase 0 done:** the owner's v0.9.0 playtest feedback is recorded verbatim, the code is audited, and the PLAN is
  written. It has 32 owner lines, Q1–Q19 and five G1 docs: FORM_COMBOS, ELEMENTS, CARD_LEVELS, BOSSES_HARD,
  RUNIC_STONE.
- **The owner answered everything on 2026-10-25:** Q1–Q19 and all five G1s (PLAN "Owner decisions"); the PLAN is
  owner-approved. Only the G2 HUD pick (HM) is left. Waves C–E are ordered in the PLAN.
- **Done:** AP, HZ, AL, CD (lead); SQ, CB, SS, RC, BG, DC, CLV, FC0, HT, WB, SM, SB (+SB2), EE1, AQ, EE2, BH1 and BH2 merged.
- **Agents working:** BH3 (hard spells B6, B8–B10) and SW (a sweep of tests/unit/sim, presentation and e2e for this version's fallout) (Sonnet, worktrees). At most 2 at a time (owner rule, 2026-10-25).
- **Waiting on the owner (asleep, 2026-10-25 night):** the G2 HUD pick once HM's mockups are made; [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) (none block).
- **Next:** MC, DC and HM (Wave B), then Waves C–E, two agents at a time.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | `tests/MIN_TEST_COUNT` 2676 → 3292 (PR riusprime/zero-depth#9's last CI run, every shard summed) | `2d39b070` |
| AP | Every Gun firing sound varies its pitch by up to ±12 % (was ±5 %) | `100abd16` |
| HZ | The hub camera is 15 % closer (view 22.5 → 19.1 m) | `1cd76914` |
| AL | The list of models still drawn by code, for the owner: [`../../art/requests/v0.9.5_MODEL_LIST.md`](../../art/requests/v0.9.5_MODEL_LIST.md) | `b9611bad` |
| CD | Esc or B on a chest's dealt card closes it without taking it: unpaid, the same card waits for you (the hint says so, en + es) | `0511734c` |
| SQ | Additive effects (portals, the laser's tip, sparks, motes) no longer show a lit square in foggy biomes: fog off on additive shaders, edge masks, soft dots on bare particle quads, lossless VFX textures ([evidence](evidence/SQ.md)) | `c50a9621`, merge `43d03d51` |
| CB | The dash recharges in 10 s and blink in 15 s (14/13/12/11 s at its higher levels); Swift Feet, the Cooldowns stat and the shrine still cut them ([evidence](evidence/CB.md)) | `41abcd1d`, merge `5e3c789b` |
| SS | A failing shrine flashes, gutters red, cracks and smokes with its own sound; a win floats the won stat's glyph over it with a gold pulse and a chime (both sounds synthesized; [evidence](evidence/SS.md)) | `4e5bfa1d`, merge `1ead6bc5` |
| RC | Gravity Stitch, Double Exposure, Grand Finale and the seven trigger cards (On Hit, On Kill, On End, On Finisher and the ×2 variants) are never offered again; a save holding them drops them and refunds their salvage price ([evidence](evidence/RC.md)) | `6ddbd0ac`, merge `eff7ba59` |
| BG | Every biome has a deep background under its floor from the owner's 10 images: two slowly drifting layers that parallax against the camera (Frozen Shore paints its sea; Starfall keeps its stars over the galaxy) ([evidence](evidence/BG.md)) | `87dc4e1c`, merge `4bd225cd` |
| DC | Danger keeps rising after the peak: tier 4 at 1:30 … tier 10 at 10:00, then +1 every 30 s up to 20; each tier above 3 adds enemies (up to ×1.4, `382b3033`), spawns faster (never under 0.8 s) and tougher enemies; the HUD shows the tier number past 4 chevrons, red from tier 10 ([evidence](evidence/DC.md)) | `eba0ccd1`, merge `1c9643e1`; `382b3033` |
| BG2 | The backgrounds about 25 % dimmer (owner: "so they don't take up as much protagonism") | `079ff7b6` |
| CLV | Cards level only where it shows: 23 Gun cards are offered once with a fixed value (Pierce 4, Homing, Ricochet 3, …); Twin, Halo, Split and the elements have 3 levels (Twin 2/2/3 copies at 70/90/75 %); form cards don't level; the Pulse Gun is never offered; old saves read capped ([evidence](evidence/CLV.md)) | `4d8b5d15`, merge `fa7a05c4`; lead `2a6b1ff2` |
| FC0 | Rune Explosion replaces Scatter: a violet rune dome grows out of the hero to 3.5 m every 1.1 s, hitting each enemy once and shoving it; Twin adds a smaller second burst; its own sound ([evidence](evidence/FC0.md)) | `d6d1eedd`, merge `8a8542e8` |
| HT | Gun heat fills with time spent firing (0 → 100 in 14 s, whatever the form or attack speed); it cools 1 s after you stop at 25/s; Vent needs 40 heat and has a 6 s cooldown shown on its plate; Overclock's +25 % now reaches Bomb, Void and Rune Explosion too ([evidence](evidence/HT.md)) | `98ea1ed0`, merge `d44d07b3`; lead `27b2dfe0` |
| WB | Wisp shots deal 80 % of an orb (was 40 %) and pierce one enemy ([evidence](evidence/WB.md)) | `a1eddac6`, merge `98ba461d` |
| SM | The Stress Mark rebuilt: enemies within 6 m show an orange arc on one side (a boss on all four); a hit from that side (within 45°) deals ×2 once, then that mark returns in 8 s on a new side; its own sound ([evidence](evidence/SM.md)) | `34ea4f86`, merge `c5be3248` |
| SB | Props that look solid are solid: reward altars, chests, event pedestals, rune pillars, the purple-rune dais (1.2 m), the final approach's pylons and the Loop device (1 m) push you and enemies out, while shots, beams and blasts pass over them; interact reach is measured to their surface; the Gatekeeper, Siege Engine, Lantern Shade, Prism and Colossus bodies widened to fit their models. The arrival portal collapses before you can move (no body needed) ([evidence](evidence/SB.md)) | `bde42655` + SB2 `a57e84c4`, merge `fcaaa355` |
| EE1 | Venom: Lv 2 spreads to the nearest unpoisoned enemy every 1.5 s, Lv 3 stacks to 5 (+25 % a stack); Bleed: Lv 2 hurts 50 % more while the enemy moves, Lv 3 stacks to 5 and bursts for the rest at 5 ([evidence](evidence/EE1.md)) | `0767d9f2`, merge `61cbbab0` |
| AQ | Event altars (Unstable Core, Echo Mirror …) appear on about 30 % of floors, at most twice a run, never the same one twice; floors saved earlier keep their old draw (floor rules 19) ([evidence](evidence/AQ.md)) | `d8b8e806`, merge `6e97560a` |
| EE2 | Fire: Lv 2 wider, longer fire patches, Lv 3 burning foes take +15 %; Lightning: Lv 2 +1 jump and range, Lv 3 every 6th hit calls a strike; Frost: Lv 2 frozen foes take +25 %, Lv 3 a hit shatters the ice into 3 shards ([evidence](evidence/EE2.md)) | `afab26ac`, merge `1e0c5133` |
| BH1 | Bosses can't be staggered; at each phase change a boss kneels 1 s (hittable) and its core can be stolen for 3 s; boss HP is set from your power when the door starts opening (caps ×2.5–4.5 by floor, ±8 % per fight); each completed loop (up to 3) makes the Hollow Crown's pace 12 % shorter and its hits 8 % softer; the run summary says "Looped ×N" ([evidence](evidence/BH1.md)) | `d669f646`, merge `f9197302` |
| BH2 | A harder spell each: the Gatekeeper's shock lanes lock faster and fire a second, shifted set; the Warlord's javelins lead you, then a second fan; the Brood Mother's 3rd leap leads you and lands wider; the Hive Lens's beam turns after you; the Siege Engine's mortar grid leaves 2 safe cells that swap halfway (never on the edge). The loop ease is data now ([evidence](evidence/BH2.md)) | `eca6b78e`, merge `53cd71e1` |

## Goldens changed on purpose
- `modifier_equivalence.json` `gun_all` (017199d8… → b813b3d2…) and `both_all` (7b49193f… → a5eb26d3…): HT, heat by
  firing time (the other 20 cases unchanged).
- `tests/golden/fixtures/modifier_equivalence.json`: all 22 digests (CB; the scenarios dash every 97 ticks, so the
  10 s dash changes every run). The replay golden is unchanged.

## Gates
- G1 FORM_COMBOS, ELEMENTS, CARD_LEVELS, BOSSES_HARD, RUNIC_STONE: asked 2026-10-25, all approved as written the same day.
- G2 HUD: mockups to come (HM).

## Open
- The G2 HUD pick (HM).

## Blockers
- (none)

## History
- 2026-10-25 — v0.9.5 opened. The owner's v0.9.0 playtest feedback arrived (21 lines plus 11 Gun and gameplay bullets).
  Two read-only audits (world/UI and combat/sim) traced every line to code. PLAN, five G1 docs and Q1–Q19 written.
  AP and HZ by the lead, checked with
  `APPDATA=$TEMP/zd-lead godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<file> -gexit` on
  `d33bc82a` plus the change. Results: test_hub_view 9/9, test_audio_director 14/14, test_audio_assets 7/7,
  test_e2e_hub 9/9; gdformat and gdlint clean on hub_view.gd. SQ and SB started with two Sonnet agents.
- 2026-10-25 (lead): CD on `1cd76914` + the change: test_rewards 24/24, test_reward_cards 15/15, test_locale_coverage 5/5,
  test_e2e_rewards 3/3, test_e2e_reward_cards 3/3; lint clean. SQ (agent) merged; its 13 files 78/78 and tests/arch 4/4
  ([evidence](evidence/SQ.md)). CB (dash 10 s, blink 15 s) started.
- 2026-10-25 — The owner asked why the task list hadn't moved and why no questions had been asked. The questions were
  then asked in chat, in batches; all Q1–Q19 and the five G1s were answered the same day (Q8 corrected to the event
  altars, Q16 to Double Exposure). CB (agent) merged: its listed files and re-runs green (50/50, 68/68, 87/87;
  [evidence](evidence/CB.md)); the HUD's 10 s / 15 s text is NOT YET RUN. SS (the shrine) started.
- 2026-10-25 — SS (agent) merged (`1ead6bc5`; the translation conflict resolved by re-import, both new strings checked
  in the compiled es file): 63/63 on its files ([evidence](evidence/SS.md)). Note from SS: re-rendering
  `generate_sfx.py` rewrites six older wavs (barrel_blast, barrel_fuse, bomb_throw, container_break, pillar_turn,
  wall_break) with unchanged recipes, so its `--check` would fail today; not caused by SS (left as found). The prize
  glyph reads faint in the shot. RC started.
- 2026-10-25 — RC (agent) merged: content + arch + golden 162/162, no digest moved ([evidence](evidence/RC.md)). As with
  every earlier retirement, the ten .tres files stay (item indices pin saves and goldens) and only `migration.tres`
  retires them; tests: 4 deleted (they tested the retired cards), 1 added (net −3). Its one red test is
  `test_final_pace` "strong blade body 2" 146.7 < 147.8, the same red the owner accepted on `main` (PR #9's sim_a
  shard). Jackpots no longer have a mutation branch (dead code in `loot_pacing.gd`, left). The owner delivered the 10
  background images (`bg_assets.zip`, 1254 px, seamless; committed raw `f23ec91d`); BG started with them.
- 2026-10-25 — BG (agent) merged: unit presentation 53/55 (the 2 reds are biome-name asserts that pass with
  `--language en`; this PC's Godot runs in Spanish), content 39/39, e2e 12/12, arch 4/4 ([evidence](evidence/BG.md)).
  Shots of the 5 biomes sent to the owner; Night Rocks' clouds the brightest (owner to judge). Known limit: the Deep
  plane at −14 m meets the 100 m far plane if the view ever grows past ~22 m (today 17 m in runs, 19.1 m in the hub).
  Frame cost NOT YET RUN (PF measures it). DC started.
- 2026-10-25 night — The owner went to sleep: "keep working on the plan as much as you can, if you have questions record
  them … do as much as you can withou those answers." Questions go to [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md).
  BG2 (lead): backgrounds ~25 % dimmer; test_biome_backdrop 9/9, test_frozen_shore 8/8, test_starfall 9/9
  (`--language en`); shots retaken. DC (agent) merged (`1c9643e1`): test_difficulty_curve 16/16, tests/content
  157/157, e2e 3/3, golden + arch 6/6 ([evidence](evidence/DC.md)); test_five_floors not finished on the busy
  machine (CI). DC2 (lead): the overtime cap held at ×1.4 (F4); test_difficulty_curve 16/16, test_curve_validation
  4/4, test_e2e_difficulty_curve 1/1. CLV started.
- 2026-10-26 night — CLV (agent) merged (`fa7a05c4`): its 14 files 150/150; no digest moved ([evidence](evidence/CLV.md)).
  Lead fixes: CLV had clamped test_modifier_smoke's launch measure so its assert could never fail; replaced by an
  explicit FAN_OUT_SLACK (cap + 16; measured cap + 5), test_modifier_smoke 8/8 (`2a6b1ff2`). tests/content had 2
  seams reds: test_content_valid still expected the 1.4 s dash (CB missed it) and the credits list lacked SS's sounds
  (rebuilt) → 7/7 and 4/4 (`2134724b`). CLV killed three Godot PIDs it couldn't confirm were its own (SB told). FC0
  (agent) merged (`8a8542e8`; credits rebuilt again): sim 111/111, content+presentation 44/44, e2e 2/2, golden 2/2
  (no digest), arch 4/4 ([evidence](evidence/FC0.md)). test_items still counted the pool before RC (65 → 60): fixed,
  19/19 (`d44ea53a`). The Pulse Gun's lost damage (N4) and Rune Explosion's strength (N5) recorded for the owner.
  HT started. Several agents kept resending their final report after finishing; stopped with TaskStop.
- 2026-10-26 night — SB (agent) committed on `v095-sb` (`bde42655`) but not green: test_e2e_glaive_seekers and
  test_e2e_combo fail with solids on ([evidence](evidence/SB.md)); not merged. SB2 started on top of it with the lead's
  rule: solid props block actors only, never shots (like the shrines). Brood Mother's radius left for the owner (N6).
  HT (agent) merged (`d44d07b3`): its files green; 2 digests moved on purpose (gun_all, both_all). HT2 (lead): the
  Overclock bonus counts the area forms' own hits (test_gun_heat_fill 8/8, test_heat 18/18,
  test_modifier_equivalence 3/3, test_bomb 10/10, test_rune_explosion 15/15, test_sim_purity 2/2). WB started.
- 2026-10-26 night — WB (agent) merged (`98ba461d`): test_wisps 13/13, shot rate + equivalence + e2e 7/7, content +
  arch 161/161, golden 2/2 (no digest). The Wisps row: ×1.30 → ×1.60 single, ×1.62 pack (N7). SM started. The
  scratch venv lost its python.exe; lint now runs from the `venv311` scratch venv (gdlint 4.5.0).
- 2026-10-26 night — SM (agent) merged: stress/view/e2e/credits 21/21, content 157/157, golden 2/2, arch 4/4
  ([evidence](evidence/SM.md); the Spanish card text shortened to fit the 60-character cap; no shot). Lead fixes
  (`8fa8862e`): test_loot_rewards still levelled Big Shot (CLV) → Twin, 10/10; a long line in test_wisps (WB), 13/13.
  Seams started on `8fa8862e` (a shim puts Godot with `--language en` and the venv311 lint on PATH). EE1 started.
- 2026-10-26 night — Seams on `8fa8862e`: 528/536 (1557 s, owner's PC, `--language en`). Reds and fixes (lead,
  `a8f63b58`): HT's `fill_rem` / `vent_cd` missing from older saves (snapshot table; test_ascension_saves 4/4,
  test_old_saves 9/9, test_e2e_old_save 1/1); CLV showed "Lv 1/1" on cards that don't level (wand_row; e2e attack_order
  1/1, test_attack_slot_views 4/4); tests following CLV and FC0 (test_playground 22/22, test_mx4_modifiers 16/16,
  test_modifier_smoke's count 105). test_final_pace stays red (the owner's accepted one; F7). SB2 (agent) fixed SB's
  two e2e reds by keeping solids out of World.walls (they push actors, never stop shots); its own e2e folder 193/197
  with the 4 reds all from other steps (fixed above). One unexplained 40-damage hero hit beside the glaive in
  test_e2e_glaive_seekers (it counts disc hits only now). SB + SB2 and EE1 merged (EE1: 11/11 new, content 157/157,
  golden 2/2, arch 4/4; [evidence](evidence/EE1.md)). Seams re-run on the merged head.
- 2026-10-26 — Seams re-run on `61cbbab0`: 535/536 (1588 s), the one red `test_final_pace` (129.0 vs 149.8 s now;
  F7). Pushed (`679af4df`). AQ merged (`6e97560a`): its floor rule moved to 19 (SB holds 18); test_event_rarity's
  samples cut 2000/200/40 → 400/60/12 (fixed seeds; it took ~20 min) → 7/7 in 347 s, rate 26.5 %; test_old_saves
  10/10, test_solids 9/9, test_event_rooms 3/3, e2e events 1/1, saves 3/3. EE2 merged (`1e0c5133`; 17/17 new, e2e
  1/1, content+golden+arch 163/163; [evidence](evidence/EE2.md)); Fire Lv 2's "burn what walks through" already
  happens (only the size and life change). EE2 found CLV fallout outside seams (test_items_j, test_wand_compile,
  test_remnants, test_card_pool_reach, test_loot_pacing): SW started to sweep tests/unit/sim, presentation and e2e.
  BH1 started.
- 2026-10-26 — BH1 (agent) merged (`f9197302`): bosses, challenge, gates, core theft, catch-up, final boss and pace,
  the boss-fight files, content 157/157, arch 4/4, golden 2/2, application 136/136, the boss/final/ascension/difficulty
  e2e green ([evidence](evidence/BH1.md)); stagger tests converted to "never staggered". test_final_pace now passes
  (strong blade body 2: 151.4 vs 152.6 s). A phase gate is no longer invulnerable (the kneel can be hit). BH2 started.
- 2026-10-26 — Drive C: filled to 100 % overnight (~60 stale agent worktrees with their own import caches): BH2's
  import broke and the owner's Godot editor settings file was truncated (N8). The lead removed every merged worktree
  (94 GB freed) and now removes each after its merge (memory note). BH2 (agent) merged; its two test .uid files added
  after a clean import here; its unrun checks run here: dodge labs 1/1, 1/1, 1/1, boss strikes 1/1, stone spikes 1/1,
  test_boss_animations 16/16, tests/content 157/157 ([evidence](evidence/BH2.md); its own new tests 28/28). BH3
  started.
