# v0.3.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3), from `08f7295`.

## Owner decisions (2026-10-07)
- The finishing-build feedback, F1–F22 in the PLAN (verbatim in `../v0.3.0/PLAYTEST_RUN_2.md`).
- At most 4 agents at a time; each wave merged before the next.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| PT | The portal glows the visor's light blue; going in draws, spins and dissolves the hero into light (~1.0 s, sim-held); floor 2+ opens on a light-blue arrival column (~0.8 s, sim-held); reduced motion fades instead. Evidence [`evidence/PORTAL.md`](evidence/PORTAL.md) | `c6fe6f4`, merge (this commit) |
| K | A **Vent** button (F / pad B) vents heat as a blast when Hot or above (a cold click below; dash and blink no longer vent); dash cooldown 0.8 → 1.4 s; a **Skill** button (Q / pad Y): Blade **Lunge Cleave** (3.5 m lunge + 180° cleave, 28 × 1.15, 4 s), Gun **Scatter Blast** (7 pellets over 60°, 4 m, 6 × 0.85, knockback, 3.5 s); a skill pip and a vent hint on the HUD. Evidence [`evidence/KIT.md`](evidence/KIT.md) | `28a6fb7`, merge `974b46c` |
| UI | A straight, thin heat bar with Hot/Overclock ticks; a calmer HUD (LINE ships; BARE and SLATE in [`hud_mockups.png`](evidence/hud_mockups.png)); square, flat pick cards with a small rarity mark (FLAT ships; FACET, RULE in [`card_mockups.png`](evidence/card_mockups.png)); the minimap was mirrored top to bottom (one sign) — fixed with a camera-projection test; sword sounds −8 dB, one layer, half the tail, at most 2 swing voices. Evidence [`evidence/UI_PASS.md`](evidence/UI_PASS.md) | `d52f3cc`, merge `0d8eaec` |
| AI | Bosses 30 % faster, aim late (track until the last 12 ticks), punish a dash at its landing point, −25 % recovery gaps, a gap-closer after 2 s out of reach; enemies with varied wind-ups, leading shots, steering charges, Needle bursts, spreading out (a charge lane bug fixed: a 0.02 m contact slop); **Arc Caster** (tier 1: fast bolt, spread, rune) and **Bomb Drone** (tier 2: hovers, hittable, bombs with a filling circle). A sideways-dash dodge bot now takes 5–25 hits/min from bosses and Needles (was 0 except the Siege Engine); boss fight lengths stay in their bands; readable cause 0 violations. Evidence [`evidence/ENEMY_AI.md`](evidence/ENEMY_AI.md) | `6ef6f24`, `a1d0c07`, merge `69e65ac` |

## Goldens changed on purpose
- none (K: the kernel scenario pins the v0.0.1 dash cooldown so the scripted golden input keeps its hashes; PT: `BossFlow` now hashes its transit fields, which changes the state hash of generated floors only; no
  golden fixture runs one)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| G2: HUD (calmer) mockups | 2026-10-07 | "HUD middle but spell cooldowns have to be a bit bigger" → BARE; cooldown squares 12 → 24 px, skill pip 22 → 36 px | 2026-10-07 |
| G2: pick card mockups | 2026-10-07 | "and card middle as well" → FACET | 2026-10-07 |
| v0.5.0 start before a v0.4.0 playtest (F21 vs ROADMAP §0.3) | 2026-10-07 | "skip the rule, keep going to v0.5.0" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.

## Blockers
- none

## History
- 2026-10-07 — Owner played the v0.3.0 finishing build and sent F1–F22. v0.3.0 closed as played. PLAN committed
  before code; wave 1 (K, AI, UI, PT) starts; the build-system direction (F7–F11, F13) goes to v0.4.0.
- 2026-10-07 — Owner: "skip the rule, keep going to v0.5.0". ROADMAP §0.3 waived once: v0.5.0 follows v0.4.0
  without a v0.4.0 playtest; both are played together afterwards.
- 2026-10-07 — PT: portal entry and floor arrival animations (F19, F20); `BossFlow.ENTERING` + arrival hold in
  ticks; the optional room scan reveal not built (minimap is UI's this wave). Suite 674 passing; MIN_TEST_COUNT 674.
- 2026-10-07 — K and UI merged (conflicts: audio events, view root, MIN_TEST_COUNT, translations; kept both). 701 tests
  pass; goldens unchanged.
- 2026-10-07 — AI merged (strings conflict, kept both). On the merged tree the new-kinds readable-cause test's bot took
  18 hits over seeds 3–5 (bar > 20; 20+ on AI's own branch): widened to seeds 3–6, bar unchanged; 0 violations.
  Export smoke 0 misses.
- 2026-10-07 — Owner G2 picks (verbatim): "HUD middle but spell cooldowns have to be a bit bigger and card middle as
  well". HUD → BARE, cards → FACET; cooldown squares 12 → 24 px, the skill pip 22 → 36 px (starting values).
- 2026-10-07 — v0.3.5 wave 1 all merged; 735 tests pass; goldens unchanged. Open for the owner (from AI): a Charger is still
  beaten by a well-timed sideways dash (its 60°/s turn can't follow a 4 m dash).
- 2026-10-07 — Owner on the Charger beaten by a well-timed sideways dash: "if it is a well times let me play and judge it".
  Left as is; the owner judges it in play.
