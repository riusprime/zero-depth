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
- **Done:** AP, HZ, AL, CD (lead); SQ, CB, SS, RC, BG, DC, CLV, FC0, HT, WB, SM, SB (+SB2), EE1, AQ, EE2, BH1, BH2, BH3, BH4, BH5 and BH6 (Wave D done), SW, EE3, DR, FC1, TS, FC2, BK, FC3, HM, HU and FC4 merged.
- **Agents working:** FC5 (the Rune Explosion's combinations) and FC6 (the Glaive's combinations) (Sonnet, worktrees). At most 2 at a time (owner rule, 2026-10-25).
- **Waiting on the owner:** [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) (none block).
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
| EE3 | Two level-3 elements wake a named pair (Thermal Shock, Toxic Fumes, Ignition Arc, Boiling Blood, Cold Circuit, Black Ice, Brittle, Neurotoxin, Arterial Arc, Sepsis), announced on the combo card with both element icons ([evidence](evidence/EE3.md)) | `7da137b5`, merge `25500066` |
| DR | Only two sealed kinds: the locked room (its enemies in one burst of 2 formations 1 s apart, a free altar; the old arena rooms are locked rooms now) and the Overrun (its waves); every seal drops the iron bars; the Overrun's doorway shows a small red floor rune instead of the glowing frame; locked-room clears count for the sealed-room achievements ([evidence](evidence/DR.md)) | `62cc306c`, merge `388e5517`; `37462b02` |
| FC1 | The Laser takes 11 more cards: Homing curves the beam to the nearest enemy (with Pierce it threads the 5 nearest), Halo fans its tip, Ring rides its tip, Backfire, Ricochet off a wall, Echo's path strikes again, Big Shot, Rapid Fire, Split forks it, Mine drops mines, Spiral wiggles it ([evidence](evidence/FC1.md)) | `e7c6084e`, merge `31ecb531` |
| TS | Timed-door switches sit in two different rooms 1–2 rooms from the door (on different sides when the map allows); the timer is 20 s (the walk always fits in 60 % of it); a lever inside the secret room reopens the door for 5 s (floor rules 21) ([evidence](evidence/TS.md)) | `de3c3bfe`, merge `2ba37f64` |
| FC2 | The Bomb takes 10 more cards: Halo drops four in a cross, Ring leaves a growing lightning ring, Backfire drops one at your feet, Ricochet skips it on, Homing lands it on the nearest enemy, Echo bursts it again, Big Shot, Rapid Fire, Split throws bomblets, Mine leaves it waiting; Laser + Rapid Fire now ramps its tick damage down (×1.3 of a plain beam, was ×2) ([evidence](evidence/FC2.md)) | `4527ece2`, merge `dafddf30` |
| BK | Crates, urns and barrels are solid until you break them (they push you and enemies, never shots); no breakable within 1.5 m of a doorway (floor rules 22) ([evidence](evidence/BK.md)) | `a6a7b490`, merge `461b630a` |
| FC3 | The Void takes 10 more cards: Ring collapses it in lightning, Backfire, Ricochet bounces it, Homing drifts it to the biggest group, Echo opens a smaller one, Big Shot, Rapid Fire, Split into minis, Mine holds it in place, Orbit circles you first ([evidence](evidence/FC3.md)) | `70b11adf`, merge `2c189081` |
| HU | HUD design A (owner pick): four 76 px ability squares bottom-right (Attack, Skill, Dash, Blink) with a falling cooldown cover and seconds, glyphs from the last device used; the HP plate 15 % bigger, the blue pips gone; plate and squares on one bottom line 20 px up (owner: "match the spells to the same height as the health bar, but lower both about 2 cm"); the Skill on the left trigger ([evidence](evidence/HU.md)) | `3de67891`, merge `00870f07` |
| FC4 | The Lance takes nine more cards (N1–N9); the Void's Mine tamed (pack ×4.55) and Big Shot cut (aura 1.3 m, pull 4.0 m, +20 %): its pack ×7.93 misses the ×6.0 target, asked as N11 ([evidence](evidence/FC4.md)) | `2fc1d68b`, merge `41bff38d` |
| BH1 | Bosses can't be staggered; at each phase change a boss kneels 1 s (hittable) and its core can be stolen for 3 s; boss HP is set from your power when the door starts opening (caps ×2.5–4.5 by floor, ±8 % per fight); each completed loop (up to 3) makes the Hollow Crown's pace 12 % shorter and its hits 8 % softer; the run summary says "Looped ×N" ([evidence](evidence/BH1.md)) | `d669f646`, merge `f9197302` |
| BH2 | A harder spell each: the Gatekeeper's shock lanes lock faster and fire a second, shifted set; the Warlord's javelins lead you, then a second fan; the Brood Mother's 3rd leap leads you and lands wider; the Hive Lens's beam turns after you; the Siege Engine's mortar grid leaves 2 safe cells that swap halfway (never on the edge). The loop ease is data now ([evidence](evidence/BH2.md)) | `eca6b78e`, merge `53cd71e1` |
| BH3 | A harder spell each: the Foundry's furnace waves come as two walls at right angles; the Twin Wardens' crossfire lines track you for 1.2 s; the Clockwork Judge adds a counter-turning spiral from phase 2; the Lantern Shade's lanterns burn 4 s, its dark lasts 9 s and Snuff puts out two lanterns ([evidence](evidence/BH3.md)) | `7ff84613`, merge `d788b91f` |
| BH4 | The Tidecaller pulls and pushes harder (1.7 / 1.4 m/s, 2.0 / 1.7 in phase 3) every 8 s; a ring of bubbles leaves it every 2.2 / 1.9 / 1.6 s all fight; every 3.5 s a short wave (2, 3 or 4 m) forms at a wall, foams 0.7 s and rolls across the room (two at once from phase 2) ([evidence](evidence/BH4.md)) | `6cac6eb3`, merge `8ba5aebd` |
| BH5 | The Hollow Crown: the Colossus's fist combo, leap slam (0.55 s telegraph, faster quake ring) and boulders are faster; the Prism's ball patterns have wider gaps (28 per ring with 3-wide gaps, 52-ball flower, 8-arm spiral: always ≥ 1.4 m to slip through mid-arena), its window after the lasers is 3.5 s and it can be hurt for 2 s after each ball pattern ([evidence](evidence/BH5.md)) | `15bf89e4`, merge `890334b4` |
| BH6 | The Fallen vanishes at 66 % and 33 % HP for 15 s of one pattern set (rotating rays with eruptions, edge ball rains with walking spike lines, or the Lantern Shade's darkness with drifting balls), then slams back down; it dashes to a new spot between moves and its mimic windows are 5.6 s ([evidence](evidence/BH6.md)) | `3b7532ee`, merge `625eb87c` |

## Goldens changed on purpose
- `modifier_equivalence.json` `gun_all` (017199d8… → b813b3d2…) and `both_all` (7b49193f… → a5eb26d3…): HT, heat by
  firing time (the other 20 cases unchanged).
- `tests/golden/fixtures/modifier_equivalence.json`: all 22 digests (CB; the scenarios dash every 97 ticks, so the
  10 s dash changes every run). The replay golden is unchanged.

## Gates
- G1 FORM_COMBOS, ELEMENTS, CARD_LEVELS, BOSSES_HARD, RUNIC_STONE: asked 2026-10-25, all approved as written the same day.
- G2 HUD: three mockups (HM, `scripts/shots/mock_hud.gd`, [evidence](evidence/HM.md)); **the owner picked A, the Risk of Rain
  row** (2026-10-26, in chat). Built in HU.

## Open
- (none blocking; see OWNER_QUESTIONS.md)

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
- 2026-10-26 — BH3 (agent) merged: test_boss_hard_3 14/14, sim batches, content 157/157, golden + arch 6/6,
  presentation 63, e2e dodge/twin/lantern/judge 14 ([evidence](evidence/BH3.md)). Phase 3's two Snuff circles can now
  darken all four lanterns at once (owner to judge in play). BH4 started.
- 2026-10-26 — BH4 (agent) merged: test_tidecaller_streams 19/19, test_tidecaller 15/15, view tests 6/6, golden + arch
  6/6, e2e tidecaller and dodge labs green, test_boss_pace 6/6 (its Tidecaller lab is new) ([evidence](evidence/BH4.md)).
  The bot's damage a minute 54 → 116 (N9). Lead tried longer Undertow / Shell Slam cooldowns (+1.3 s: 91 a minute but
  The Pull slipped to every 12 s, test_tidecaller red; +0.6 s: 119): reverted, left to the owner's play. BH5 started.
- 2026-10-26 — BH5 (agent) merged (`890334b4`): its unit files, test_hollow_crown_hard 7/7, e2e prism / final / approach,
  content + golden + arch 163 (test_boss_pace's pin updated) ([evidence](evidence/BH5.md)). The leap slam's telegraph
  sits on the 0.55 s floor; the ring turns 45° a wave so waves don't overlap; the Prism's HP rises with its open share,
  so its fight time holds (−10 % to +15 %). BH6 started.
- 2026-10-26 — BH6 (agent) merged (`625eb87c`): test_fallen_interphase 22/22, nemesis + final boss 70/70, final_pace
  16/16, e2e 6/6, content 157/157, golden 2/2, arch 4/4, debug 16/16, application 137/137 ([evidence](evidence/BH6.md));
  sampled gaps ≥ 6.8 m and no overlapping hits. Presentation reds it saw outside its files (attack_visuals' Gatekeeper
  sweep, BH4's wave looks, test_gun_pulse) left for the sweep. Wave D (bosses) is complete. EE3 started.
- 2026-10-26 — SW (agent) merged (`8ace98be`): on base `1e0c5133` its first runs were tests/unit/sim 1740/1763 and
  presentation + e2e 1235/1238 (8202 s and 3029 s on a loaded machine); it fixed 14 test files that followed CLV, RC,
  FC0, DC and SB (one parse error in test_arenas from SB), re-runs 129/129 and 16/16; no unexplained failure. Seams and
  the whole presentation folder started on the merged head. DR started.
- 2026-10-26 — Seams on `8ace98be` stopped at gdformat (test_boss_hard.gd, BH2) → formatted (`1f48dbb2`). The import
  there had rewritten project.godot (comments, sections, `locale/fallback` dropped): restored, never committed; seams
  runs now restore it if an import rewrites it. The whole tests/unit/presentation folder on `8ace98be`: 1048/1052; the
  4 reds were tests behind BH2/BH4/BH6 (the AI's next pick can be shock lanes; the wave and interphase carriers are
  drawn by their own views) → fixed, test_attack_visuals 16/16, test_attack_visuals_2 11/11. EE3 (agent) merged:
  test_element_pairs 25/25, banner 3/3, e2e 1/1, related batches 112/112 and 58/58, content 157/157, golden + arch 6/6;
  no digest ([evidence](evidence/EE3.md)). Seams re-run on the merged head. FC1 started.
- 2026-10-26 — Seams on `25500066`: **540/540** (1698 s), the first fully green seams of v0.9.5 (test_final_pace passes
  since BH1). Pushed. DR (agent) merged: its files green (locked_rooms 3/3, dr_views 2/2, lockdowns, arenas, overrun,
  old saves, content, golden, arch, e2e lockdown/arenas/saves) ([evidence](evidence/DR.md)). DR2 (lead): the
  achievement tracker counts locked-room clears too (the arena-clear counter would have stopped: arena rooms are locked
  rooms now); test_achievements 15/15 (1 new), e2e achievements 1/1. TS started on top of DR (floor rules 21).
- 2026-10-26 — FC1 (agent) merged: test_laser_mods 19/19, the laser/slots/offers/equivalence/snapshot/content batch
  177/177, presentation + e2e + golden 44/44, content 157/157, golden 2/2, arch 4/4; no digest ([evidence](evidence/FC1.md)).
  Laser + Homing + Pierce: ×5.97 in a line, ×2.42 in a pack. Laser + Rapid Fire doubled the beam's damage (the lead's
  spec shortened the tick without lowering its damage): FC2 adds a per-tick damage ramp to ×0.65. FC2 started.
- 2026-10-26 — TS (agent) merged: its files green (timed door 9/9, rooms 4/4, view 4/4, old saves 11/11, content, golden,
  arch, both e2e) ([evidence](evidence/TS.md)); 200 forced seeds: 194 doors, worst walk 0.599 of the timer; 1000 real
  floors: 231 doors, worst 598 ‰. The door never shuts on a hero inside (N10). BK started.
- 2026-10-26 — FC2 (agent) merged: sim batch 178/178, arch + bomb view + e2e 30/30, presentation + e2e 15/15; no digest
  ([evidence](evidence/FC2.md)). The cards' descriptions still read the same on every form: a later text step (TX)
  will add each form's own line. FC3 started.
- 2026-10-26 — BK (agent) merged: breakables/solids/walls/collision 29/29, golden + arch + content + application
  302/302, e2e 5/5 ([evidence](evidence/BK.md)); 0 of 941 props dropped by the doorway rule (the 2 m approach gap
  already kept them clear). HM started (the HUD mockups for the owner's G2 pick).
- 2026-10-26 — FC3 (agent) merged: test_void_mods 20/20 and its batch, content + golden + arch 163/163 after its last
  edit; no digest ([evidence](evidence/FC3.md)). Void + Mine measured ×7.98 single / ×23.8 pack (held voids stack) and
  Void + Big Shot ×10.6 pack: FC4 tames both (one held void at a time; a smaller Big Shot). HM (agent) merged: three
  HUD mockups sent; the owner picked **A** (the Risk of Rain row). FC4 and HU started.
- 2026-10-26 — Owner, on the HUD: "match the spells to the same height as the health bar, but lower both about 2 cm".
  Passed to HU: the squares and the HP plate share one bottom line 20 px above the screen's edge at 1080p (the plate
  ~70 px lower than today), the squares centred on the bar row; whatever sat above the plate moves down with it.
