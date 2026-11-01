# v0.10.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0100-cleanup` (v0.10.5 builds on v0.10.0 there until the release step).

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-01.)

- The owner's v0.9.5 + v0.10.0 feedback and the theory audit are answered and planned (PLAN, THEORY_AUDIT,
  P1_ELEGANCE, O1_REMOVAL_LIST).
- **Merged:** S1, S2, S3, S4, S5, S6 (verified here), S5b, S9, S10, S14, S15 (check only), O2a.
- **Building:** S7, S12, S15b (Sonnet), O1 removal (Opus).
- **Next:** O1's removal (approved), then the rest of wave 1.
- **Waiting on the owner:** the G1/G2 drafts as they land.

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
