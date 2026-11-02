# v0.10.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0100-cleanup` (v0.10.5 builds on v0.10.0 there until the release step).

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-01.)

- The owner's v0.9.5 + v0.10.0 feedback and the theory audit are answered and planned (PLAN, THEORY_AUDIT,
  P1_ELEGANCE, O1_REMOVAL_LIST).
- **Merged:** wave 1 except S7: S1–S6, S5b, S8–S15, S15b (S15, S13 check only), and O2a.
- **Building:** S7 (Sonnet), O1 removal (Opus). Wave 2 drafts start as the Opus slot frees.
- **Next:** O1's removal (approved), then the rest of wave 1.
- **Waiting on the owner:** which Ring (S10); cracked walls per-floor chance (S15b); the G1/G2 drafts as they land.

## Owner decisions (2026-11-01)
All in PLAN "Every owner line → where it lands", THEORY_AUDIT "Decisions" and P1_ELEGANCE "Owner's answers".

## Done
| Step | Commit | Evidence |
|---|---|---|
| S1 a snappier Blade: combo hit-stop 3,3,3,5 ticks, view hold 2 frames, kick 0.06 m | 2561df09 | agent (wt-s1, base 48f5c616): 7 files, 66/67 then test_content_valid 7/7 after its fix; golden re-recorded |
| S2 the Warden's slam band near-white again | d316f220 | see Verification 1 |
| S3 the path refresh every 12 ticks | 3625d1a8 | see Verification 1 |
| S4 the hero stands on the arrival receiver | cf0cd9e1 | see Verification 1; arrival shots looked at by the lead |
| S5 + S5b a curse room you can see in; the altar shows its details | 3a80cafd, d9aa581f, fef99113 | Verification 3; S5b close-up shown to the owner |
| S6 a boss core is Legendary 35 % of the time | 92668a8b | agent: test_core_theft 10/10 (200 seeds: 40 % legendary); Verification 2 |
| S9 calmer walls (Night Rocks, Frozen Shore) | 04b1ed04 | agent: test_procedural_wall 13/13, content 16/16; busy-ness Night Rocks −28 %, Frozen Shore flat; shots shown to the owner |
| S10 the plain Pulse bolt back; the shock Ring's sparks smaller, orbiting | 96a87b71 | agent: test_vx6_lightning 16/16, test_vx2_forms 15/15; which Ring the owner meant: asked |
| S14 no rune puzzle room; an old save's rune room dropped cleanly | 7d265ab2, 6a5c4e8b | agent: 9 rune/save/schema files all pass (e.g. test_world_snapshot 15/15, test_old_saves 11/11) |
| S15 cracked walls counted and framed (check only) | fae62444 | [evidence/S15_CRACKED_WALLS.md](evidence/S15_CRACKED_WALLS.md) |
| S8 + S11 OWNER_TODO trimmed; streams locked (EI-05) | 6035194a | docs only |
| S12 a perfect Vent (≥ 90 heat) refunds the dash | 0a8e69bd | agent: test_heat 19/19, player kit 6/6, skill 13/13, e2e heat 1/1, golden 2/2 |
| S13 room density measured (check only) | 3ceb5eaa | [evidence/ROOM_DENSITY.md](evidence/ROOM_DENSITY.md): none flagged; closest room_1x1_2 (75.9 % open) |
| S15b cracked walls you can see (cracks on 4 faces, seam glow, cutaway fade); chance unchanged | fbd4b8b9 | agent: cracked rooms 2/2, schema 5/5, 2 e2e 1/1 each, golden 2/2; shot shown to the owner. Floor rates 3 / 21 / 8 % (no single chance reaches 1 in 3) |
| S15c cracked walls subtle; runes shine on every face within 3.5 m | f3b0c3d0, efd79f9e | agent: breakables view 2/2, 2 e2e 1/1 each, cracked rooms 2/2; far/near shots shown to the owner |
| S15d cracked walls: a chance per floor (1000 / 350 / 750 ‰) | 4778b7ba | agent: 200 seeds → 11.5 / 28.5 / 31.0 %; cracked rooms 3/3, schema 5/5, content 7/7, e2e 1/1, golden 2/2 |
| O18 a Lore page in the Codex (9 lines, en + es) | dc2c6404 | agent: 8 files all pass (codex 12/12, lore 3/3, locale 6/6, e2e codex 3/3); shot `build/shots/v0.10.5/codex_lore_es.png` |
| S7 about 12 % more chests and altars (extra_chest/altar_permille 120) | 59182df2 | agent: 200 seeds → altars +9–12 %, chests +10–15 %; five floors 8/8, rewards 24/24, loot 10/10, rarity 9/9, golden 2/2; lead re-ran the skipped e2e: test_e2e_floor 2/2, test_e2e_combo 1/1 pass; **test_e2e_card_pool fails** (walk_to altar 8, line 87; the test grants retired abilities) → handed to O1 with a reachability check of S7's extras |
| O7a kill shards grow for at least 3 min a floor, then hold (the peak or 180 s) | 38aa3de7, cb5d8555 | agent: floor 1/2 shards per min 150 240 270 360 360… (was rising to 600 at min 8); rewards 26/26, heal orbs 11/11, loot 10/10, golden 2/2 |
| O2b floor boss fights last 1–2 min at your power (HP × pace × min(P, 3E)/E at the door) | 6e816924 | [evidence/O2B_BOSS_PACE.md](evidence/O2B_BOSS_PACE.md): weak/expected/strong 72–103 s, extreme 6× 43–57 s (was 8–65 s); unit 154/157 (3 failures pre-existing on its base: test_deep_bite locale, 2 test_ascension loop-HP expectations), e2e all pass, content 166/166, arch 4/4, golden 2/2 |
| O1 retired cards, 12 old combos and 5 flat curses removed (152 files, 154 strings rows), saves keep loading (CardOrder tombstones) | 97142a3f…09aba0c4 | agent: seams.sh 580/582 → the 2 fixed and re-run 1/1 each; test_card_order (an old save with removed cards, combo and curse loads and plays); no golden re-recorded; modifier_equivalence lost 17 cases with deleted cards. Lead re-runs seams on the merged branch |
| O3 the Prism's last phase (from 50 %): Facet Lances and the Shattered Kneel | 55144d6c | [evidence/O3_PRISM.md](evidence/O3_PRISM.md): phase length base 112.4 → 111.9 s, strong 72.2 → 78.1 s; boss/prism batch 196/196, e2e 3/3, golden + dev 18/18, arch 4/4, content 246/246 after 2 fixes; shots `build/shots/v0.10.5/prism_*.jpg` |
| O4 the director reads your HP and kills live (struggling: earlier, lower peak, longer quiet, smaller packs); quiets end on time | 0874505a | [evidence/O4_DIRECTOR.md](evidence/O4_DIRECTOR.md): all 98 quiets end on time (was 88/88 forced to 20 s); alive while sending 15 → 12.5; strong kills −3 %. **Partly met:** the weak hero is still the most crowded (16.4 vs 13.6), and the room refills within ~5 s after a quiet. Director 28/28, golden/saves/spawn etc 74/74, e2e 6/6 |
| O4 the director reads your HP and kills live (struggling: earlier, lower peak, longer quiet, smaller packs); quiets end on time | 0874505a | [evidence/O4_DIRECTOR.md](evidence/O4_DIRECTOR.md): all 98 quiets end on time (was 88/88 forced to 20 s); alive while sending 15 → 12.5; strong kills −3 %. **Partly met:** the weak hero is still the most crowded (16.4 vs 13.6), and the room refills within ~5 s after a quiet. Agent: director 28/28, golden/saves/spawn 74/74, e2e 6/6. Merge conflict with O1 (Swarm Call line) resolved by the lead |
| O14 floor 2: an Elite set-piece Lockdown near the main path's middle (33/50 seeds); floor 3: no new packs in the room before the boss; FLOOR_RULES 23 gates it for old saves; cracked walls back to floors 1–3 only | 357eb22b, c50c07ab | agent: interest curve 3/3, lockdowns 8/8, first 3/3, elite rooms 7/7, spawn director 19/19, horde 6/6, special room rules 3/3, cracked 3/3, schema 5/5, old saves 11/11, golden 2/2 |
| Q1 three stale tests follow today's data (deep bite locale, ascension EP3 ease, lance scatter pack burst) | 5acaebaf | agent: 5/5, 15/15, 2/2 |
| O6 a hazard-striped danger bar replaces the triangles (green → red, blinks when full at tier 10); "The depths answer ×N" tag when the catch-up is above ×1 (D4 flipped) | ad0815e4 | [evidence/O6_DANGER_BAR.md](evidence/O6_DANGER_BAR.md): variant C picked of 3; HUD tests 17/17, HUD e2e 2/2; `test_ascension_views` recap test fails on the Spanish locale (pre-existing, queued); shots `build/shots/v0.10.5/danger_bar_*.png` |
| O15 six enemy duos (pairings.tres), announced "New: <duo>" | 0bc1151e | agent: test_pairings 7/7, spawn director 19, horde 6, intensity 20, interest curve 3, closed fights 8, golden 2/2; 100-seed appearance table in the agent report (e.g. Slam and shoot 82–85 %, Shield wall 73–84 % from floor 3). The .translation merge conflict was regenerated by an import; locale coverage + pairings + depths tag + codex lore 22/22 after it |
| O5a + O5b loops: robes earned at loops 3 and 5, records (deepest loop, fastest true ending) in the hub and recap, achievements loop 3/5, fragments ×(1 + 0.5 per loop), one rule mutation a loop (5 rules), HP step ×6 → ×3.5 | c40ce826, 9f59d7ed, bb16343c | [evidence/O5_LOOPS.md](evidence/O5_LOOPS.md): agent content/arch/golden 172/172, 12 unit files 109/109, 6 e2e 21/21. Merge conflicts with O6/O15 (pause menu, main.gd, strings) resolved by the lead keeping both; after it: pause/loops/HUD/depths 20/20 |
| Locale pins: test_ascension_views sets en | bbd92c8f | agent 5/5; found test_health_bars failing (the Prism's new gate-less phase counted as a shield, from O3) → fixed in b26f2318 (boss_shields_left is 0 for rotation bosses, the rule BossGates.begin uses): health bars 10/10, prism last 8/8, prism views 12/12, golden 2/2 |
| D1 the wand-build replay mismatch was the test's: SaveLab never set the element-pair table (Thermal Shock); fixed, plus a guard test; fixture back to the old cards | e0312a46, 60334911 | [evidence/D1_REPLAY.md](evidence/D1_REPLAY.md): wand build 3/3, guard 1/1, world snapshot 15/15, golden 2/2. It found test_old_saves failing (O15's World.pairs_seen not registered) → fix queued |
| O10 the stress matrix: every enemy weak (×1.25) to one form/element and resists (×0.75) another, 7 ids × 2/2; weak and resisted numbers shown; Codex "Weak to / Resists" | 67cc462f, 0763d4cf | [evidence/O10_STRESS_MATRIX.md](evidence/O10_STRESS_MATRIX.md): no form best or worst everywhere; Venom best on 9/14 (was 12); matchups 13/13, content+golden 168/168, arch 4/4, batch 113/114 (test_e2e_damage_soak orphans only in a shared run, passes alone) |
| O9 7 rule cards (Close Quarters, Third Strike, Reflex, Adrenaline, Vent Mend, Heat Shield, Scavenger) replace 8 flat stat cards (crit damage, area, cooldowns, move speed, regen, armour, pickup range, shard gain: weight 0, saves keep them); damage, attack speed, max HP, crit chance stay | b276734d, e607ea04 | [evidence/O9_RULE_CARDS.md](evidence/O9_RULE_CARDS.md): rule cards 10/10, content/arch/golden/app 381/381 after fixes, sim+e2e 326/326 after fixes; pool Blade 58, Gun 62. Its leftover test_catch_up failure was O6's: the test still asserted D4 "hidden"; rewritten by the lead to guard the shown rule (42c4c273), 18/18 |
| O17 a Training Room behind a door at the bottom of the hub (27 × 23 m): an endless dummy with a DPS meter, a terminal (spawn met enemies 1/3/8, clear, weapon, add any seen wand card at level 1–5, wand order, reset), HP floors at 1, nothing counts | 8c4fe18a | [evidence/O17_TRAINING_ROOM.md](evidence/O17_TRAINING_ROOM.md): 75/75 (unit 8, e2e 2 through real input from the hub, hub, playground, locale, content) + golden/arch 6/6; shots `build/shots/v0.10.5/training_room*.png` |
| pairs_seen joins the save snapshot (O15 regression) | 4bdee461 | agent: old saves 11/11, world snapshot 16/16, pairings 7/7, golden 2/2 |
| O12 the hero's effects have a budget (sprites 160/110/60, bolts 96/64/32 by Effects density; dim past 75 %, skip past the cap; fade to 60 % when > 4 threats); hostile effects never touched | 1530c95a | [evidence/O12_EFFECT_BUDGET.md](evidence/O12_EFFECT_BUDGET.md): budget 10/10, e2e/content/arch/readable 27/27; **fps unchanged** (60 enemies, heavy wand, i7-10700K + RTX 3060: p50 54–63 ms, ~16–17 fps; render is ~14 ms of the frame, the main thread is the cost). Presentation folder 1271/1276: 4 stale tests from S1/O1/FX → fixed in 2e3d6b82 (blade feel 19/19, item visuals 1/1 after deleting 2 tests whose items O1 removed, seekers 5/5); test_item_cards fails only in the full folder run (not reproduced in chunks) |
| O13 the wand forecast: a FORECAST block under the wand on the Build page (and "AFTER THE SWAP" on the Swap panel): the spell read left to right and its numbers, computed by the sim's own compile | e90fd495 | [evidence/O13_WAND_FORECAST.md](evidence/O13_WAND_FORECAST.md): 76/76 incl. test_wand_forecast (numbers = outcome for 6 wands, read-only, en+es) and the wand-build e2e through real input; arch+golden 6/6; shot `build/shots/v0.10.5/wand_forecast.png` |
| O11a how each verb feels today (timings from the code) | 55eb28da | [evidence/O11A_FEEL_TODAY.md](evidence/O11A_FEEL_TODAY.md) |
| O11 feel: hits push normal enemies back (Blade 0.15 m, finisher 0.45, bolt 0.06, crit 0.12; elites half, bosses none); a dash cancels a Blade swing's recovery; the finisher's recovery 24 → 18 ticks | 10ffc848 | agent: hit feel O11 9/9, combo 16, kit 6, skill 13, hit feel 3, blade combos 13, wand blade 16, content 7, golden replay 2, e2e blade feel/combo/wand blade pass |
| O16 the economy map (docs/balance/ECONOMY_MAP.md: 12 loops, sign/speed/strength) and the three curves over 20 seeds × 5 floors (evidence only) | 541fa5ee | [evidence/O16_ECONOMY.md](evidence/O16_ECONOMY.md): shards are a dead-ish loop (the bot spends 27 % and still empties every chest; the bank grows 671 → 2088 by floor 5); power is a staircase, challenge a ramp; floor 5 challenge/P 0.69 (a spike); the catch-up is ×1 on floors 1–3 and stretched on 4–5 (3 table entries for 5 floors); boss fights median 66–94 s |
| ~~O4b~~ **not merged**: a refill ramp (×2.5 → ×1 over 10 s after a quiet) and a struggling cap (800 ‰) missed both targets | c22022d6 on branch `v0105-o4b` (kept, worktree `wt-o4b`) | agent: tests 59/59, golden 2/2; probe: weak alive 16.2 → 11.5 (still highest), **strong kills −22.5 %** (target ±10 %): the bot reads as struggling a third of the time. Not merged, per "if a target is missed, report and stop" |
| Q5 where the frame time goes (measure only) | b0c9dabc | [evidence/PERF_Q5.md](evidence/PERF_Q5.md): 60 enemies 55.6 ms avg (18 fps), 20 enemies 12.6 ms (79 fps), 0: 4.75 ms; views sync every tick (3.6 ticks a frame × 9.3 ms) |
| O7b kill shards lie on the floor (merge within 0.5 m, at most 24 a floor) until you come within 1.2 m × pickup range; left-over shards collected at the portal; bosses, chests, events stay instant | d36482f2 | [evidence/O7B_SHARD_PICKUPS.md](evidence/O7B_SHARD_PICKUPS.md): shard drops 12/12; batches 268/274, 32/34, 97/98, the failures pre-existing cross-step regressions (O17 player_hp_floor not in old saves, test_arenas altar cap from S7, a reward view colour) → fix queued; shot `build/shots/v0.10.5/shards_on_the_floor.jpg` |
| Q7 the catch-up and boss pace have floor 4–5 entries (E 7000/11000, caps 3000/3500, boss E 11000/16000, pace 5130/5810) | 88026905 | evidence/O16_ECONOMY.md "Q7": floor 4 bosses 97.4 / 69.0 s (in band); **floor 5 bosses 57.7 / 58.4 s, under the 60 s target** (not retuned; a pace near 9000 would land ~90 s); catch-up + boss pace 23/23, content 166/166, golden 2/2 |
| O2a the Lantern Shade and the Clockwork Judge hittable more often | f59ee0f2 | [evidence/O2A_INVULNERABLE.md](evidence/O2A_INVULNERABLE.md): invulnerable share 37 → 13 % and 30 → 8 %; 23 scripts 198/198 |

## Verification
1. **S2–S4 re-tested on this branch** (the agents' own runs were on an old base, `d33bc82a`, see History). Lead,
   on the owner's PC, at `48f5c616`:
   - `gdformat --check` + `gdlint` on `warden_avatar.gd`, `floor_receiver.gd`, `nav_field.gd`: "3 files would be
     left unchanged", "Success: no problems found".
   - `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_warden_avatar.gd,res://tests/unit/presentation/test_floor_receiver.gd,res://tests/e2e/test_e2e_arrival.gd,res://tests/unit/sim/test_chase_field.gd,res://tests/unit/presentation/test_melee_strikes.gd,res://tests/unit/presentation/test_windup_tells.gd,res://tests/unit/presentation/test_twin_warden_views.gd -gexit`:
     Scripts 7, Tests 42, Passing Tests 42, Asserts 12691.
   - `... -gdir=res://tests/golden -gexit`: Scripts 1, Tests 2, Passing Tests 2, Asserts 4.

2. **S6 on this branch** (lead, at `6adc22e2`): `... -gdir=res://tests/golden -gexit`: Scripts 1, Tests 2, Passing
   Tests 2, Asserts 4 (no golden moved). `... -gtest=res://tests/e2e/test_e2e_reward_cards.gd,res://tests/e2e/test_e2e_codex.gd
   -gexit`: Scripts 2, Tests 5, Passing Tests 5, Asserts 112.

3. **S5 on this branch** (lead, after the S5 merge, before S5b): `... -gtest=res://tests/e2e/test_e2e_curse_room.gd,res://tests/unit/presentation/test_curse_room_view.gd,res://tests/unit/sim/test_curse_room.gd
   -gexit`: Scripts 3, Tests 23, Passing Tests 23, Asserts 2527. S5b changed only the altar material and light
   energy; its agent ran test_curse_room_view 10/10.

4. **Lead seams after merging S1–S15d, O1, O2a, O2b, O7a, O18** (clean worktree `wt-seams` at `bdb2ec79`, the
   owner's PC; godot/gdformat/gdlint put on PATH): `bash scripts/ci/seams.sh`: lint ok; Scripts 103, Tests 582,
   Passing Tests 582, Asserts 70020; "check_gut_log: ok (582 passing, minimum 1)".

5. **Lead seams after O3–O6, O9, O10, O14, O15, D1, Q1, the locale/health-bar/pairs_seen fixes** (`wt-seams` at
   `76c587e8`; the first try at `dc1f6294` stopped on one lint line length, fixed in 76c587e8): `bash scripts/ci/seams.sh`:
   lint ok; Scripts 106, Tests 603, Passing Tests 603, Asserts 70981; "check_gut_log: ok (603 passing, minimum 1)".

## Goldens changed on purpose
- `tests/golden/fixtures/modifier_equivalence.json` (S1: the combo hit-stop 4,4,5,8 → 3,3,3,5 ticks; Blade-all now hits 139, damage 4160, kills 14)
- `tests/golden/fixtures/modifier_equivalence.json` again (O11: the knockback and the finisher's recovery; blade_plain, gun_plain, both_plain, blade_wildfire_rider, gun_frost_core regenerated)

## Gates (owner)
| Gate | Where | State |
|---|---|---|
| G1 theory audit | THEORY_AUDIT.md | answered 2026-11-01 |
| O1 removal list | O1_REMOVAL_LIST.md | approved 2026-11-01 (4 live combos kept) |
| P1 worksheet | P1_ELEGANCE.md | partly answered |

## History
- 2026-11-01: PLAN written from the owner's answers. The first Sonnet agents (S1–S4, S14, S15) were given worktrees
  cut from `main` (`d33bc82a`, v0.9.0) instead of this branch; S2–S4 were merged (clean, tiny) and re-tested here
  (Verification 1); S1, S14, S15 were stopped and restarted on worktrees the agents make from this branch's SHA.
  S1's target was corrected (the combo's hit-stop, not Lunge Cleave's).
- 2026-11-01: S5 merged (d9aa581f); the owner looked at the close-up: "it is like white weird, it is not right, you
  should be able to see the details no it is like whited out". Next: S5b (the altar's self-glow removed; its
  albedo brightened instead; the light softened) with a close-up for the owner.
- 2026-11-01: after S15b the owner: "the secret room is to obvious now, can't we make it like a rune shine when you
  pass by on both sides of the wall inner and outter just in case you can not see the inner due to perspective?"
  → S15c: cracks subtle again, no always-on seam; runes on both faces shine when the hero is within 3.5 m.
- 2026-11-01: the owner on cracked-wall frequency: "Yes, per floor" → S15d: a chance per floor index (floor 1
  1000 ‰, capped ~13 % by free dead ends; floors 2 and 3 tuned to ~30 %).
- 2026-11-01: which Ring (S10): the owner: "The shock Ring", the one S10 changed (sparks ×0.33, at most 6, orbiting
  the rim). The motion doesn't show in a still; the owner judges it in play.
