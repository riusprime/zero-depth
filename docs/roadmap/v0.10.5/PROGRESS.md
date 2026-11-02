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

## Goldens changed on purpose
- `tests/golden/fixtures/modifier_equivalence.json` (S1: the combo hit-stop 4,4,5,8 → 3,3,3,5 ticks; Blade-all now hits 139, damage 4160, kills 14)

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
