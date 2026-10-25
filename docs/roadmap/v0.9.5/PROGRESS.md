# v0.9.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v095-feedback`, cut from `main` at `d33bc82a` (v0.9.0, PR
riusprime/zero-depth#9).

## Where we are
(The lead keeps this block current at every push; the SessionStart hook prints it. Updated 2026-10-25.)

- **Phase 0 done:** the owner's v0.9.0 playtest feedback is recorded verbatim, the code is audited, and the PLAN is
  written. It has 32 owner lines, Q1–Q19 and five G1 docs: FORM_COMBOS, ELEMENTS, CARD_LEVELS, BOSSES_HARD,
  RUNIC_STONE.
- **Wave A (direct fixes) is running.** AP (gun pitch) and HZ (hub zoom) were done by the lead. AL (model list) was
  written. CD (chest refusal) by the lead; SQ (lit squares) merged. SB (solid bodies) and CB (dash 10 s, blink 15 s) with agents.
- **Agents working:** SB and CB (Sonnet, worktrees). At most 2 at a time (owner rule, 2026-10-25).
- **Waiting on the owner:** Q1–Q17 and the five G1s.
- **Next:** Wave B: SS, RC, MC, DC and the HM mockups, two at a time.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | `tests/MIN_TEST_COUNT` 2676 → 3292 (PR riusprime/zero-depth#9's last CI run, every shard summed) | `2d39b070` |
| AP | Every Gun firing sound varies its pitch by up to ±12 % (was ±5 %) | `100abd16` |
| HZ | The hub camera is 15 % closer (view 22.5 → 19.1 m) | `1cd76914` |
| AL | The list of models still drawn by code, for the owner: [`../../art/requests/v0.9.5_MODEL_LIST.md`](../../art/requests/v0.9.5_MODEL_LIST.md) | `b9611bad` |
| CD | Esc or B on a chest's dealt card closes it without taking it: unpaid, the same card waits for you (the hint says so, en + es) | `0511734c` |
| SQ | Additive effects (portals, the laser's tip, sparks, motes) no longer show a lit square in foggy biomes: fog off on additive shaders, edge masks, soft dots on bare particle quads, lossless VFX textures ([evidence](evidence/SQ.md)) | `c50a9621`, merge `43d03d51` |

## Goldens changed on purpose
- (none yet)

## Gates
- G1 FORM_COMBOS, ELEMENTS, CARD_LEVELS, BOSSES_HARD, RUNIC_STONE: asked 2026-10-25.
- G2 HUD: mockups to come (HM).

## Open
- Q1–Q19 (Q18 and Q19 FYI).

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
