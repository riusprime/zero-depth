# v0.1.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Owner decisions (2026-10-06)
- Q1 primary: swing + charged shot. Q2 utility: guard and blink, picked before play. Q3 enemies: as proposed.
  Q4 delivery: playable fight first.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| 0 | Plan | `8861071`, `a05da60` |
| 1 | Damage, health and death in the sim (dash and post-hit invulnerability, hit-stop on being hit) | `d6b67b6` |
| 2 | The primary: click to swing (3-hit combo), hold to charge, release to fire a bolt | see `git log` |

## Goldens changed on purpose
- **Step 1** (new actor state in the hash: max HP, invulnerability, dead flag, behaviour state; projectile damage
  and tags):
  - replay golden `tests/golden/fixtures/replay_ground_plane.json`: final `cc9224c8…cdcd8b2` → `d242c8af…2edb37`;
  - export-smoke hash: `c40131c6…bf8489` → `72b32e0d…b065eb`.
- **Step 2** (the primary's state is hashed: held buttons, swing, combo, hold):
  - replay golden final `d242c8af…2edb37` → `0b162e72…5cc2c9`;
  - export-smoke hash `72b32e0d…b065eb` → `ced2e569…dcd51e`.
  The kernel scenario's behaviour is unchanged (its dummies' shots still do 0 damage); the Windows job re-checks
  the new golden cross-OS.

## Deviations from the PLAN
- `PrimaryDefinition` replaces CONTENT_SCHEMA §8's generic `AttackDefinition` for the primary (the schema is
  updated): the owner's primary is a combo plus a charge, not one attack.
- The swing starts on the press (no delay); holding past 0.2 s then charges, so every charged bolt starts with a
  swing. A starting rule for the owner to judge.
- `tests/unit/application/test_settings_profile.gd` fails when only `tests/unit` runs (it needs the audio buses
  and the input map that earlier suites set up); it passes in the full suite. Pre-existing; to fix in Step 10.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Design questions Q1–Q4 | 2026-10-06 | see Owner decisions | 2026-10-06 |
| Fight build check | after Step 7 | pending | |
| Options mockups (G2) | Step 10 | pending | |
| Fun without loot | after Step 12 | pending | |

## Open
- O3 `main`. O4 credit line.

## Blockers
- None.

## History
- 2026-10-06 — Owner answered Q1–Q4. PLAN committed. Next: Step 1 (damage, health, death).
- 2026-10-06 — Step 1: `Damage` pipeline (HIT → DAMAGE → one KILL with provenance), actor HP and state arrays,
  dead enemies removed in phase 9, the dash invulnerable for 0.15 s, 0.5 s invulnerable and 4 ticks of hit-stop
  after a hit. 89 tests pass; goldens re-recorded on purpose.
- 2026-10-06 — Step 2: `PlayerKit` (swing arc via `AttackShapes`, combo, charge at 50% speed, bolt 12–36 damage,
  hit-stop 3/5 ticks), `PrimaryDefinition` in `runner.tres`, `KitView` (swing fan from the same numbers, charge
  ring), cyan player bolts. 97 tests pass; goldens re-recorded on purpose.
