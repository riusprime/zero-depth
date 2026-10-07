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
| 2 | The primary: click to swing (3-hit combo), hold to charge, release to fire a bolt | `f7f8c88` |
| 3 | Pick Guard or Blink before play; hold to guard, press to blink | `26c4601` |
| 4 | Charger, Warden and Needle fight you, each attack telegraphed on the ground | `1574783` |
| 5 | Three waves; die and see why, or clear the arena; restart; a HUD | `fb3caa3` |
| 6 | Hits feel like hits: hit-stop, a white flash, camera shake (with an option), shards on a kill | see `git log` |

## Goldens changed on purpose
- **Step 1** (new actor state in the hash: max HP, invulnerability, dead flag, behaviour state; projectile damage
  and tags):
  - replay golden `tests/golden/fixtures/replay_ground_plane.json`: final `cc9224c8…cdcd8b2` → `d242c8af…2edb37`;
  - export-smoke hash: `c40131c6…bf8489` → `72b32e0d…b065eb`.
- **Step 2** (the primary's state is hashed: held buttons, swing, combo, hold):
  - replay golden final `d242c8af…2edb37` → `0b162e72…5cc2c9`;
  - export-smoke hash `72b32e0d…b065eb` → `ced2e569…dcd51e`.
- **Step 3** (blink state hashed): replay golden final `0b162e72…5cc2c9` → `ff866d29…e654f`; export-smoke hash
  `ced2e569…dcd51e` → `bb9c2594…e91839`.
- **Step 4** (the charge/burst lock length is hashed): replay golden final `ff866d29…e654f` → `5044b77b…0b0871`;
  export-smoke hash `bb9c2594…e91839` → `a0bff684…66c972`.
- **Step 5** (wave, outcome and killer state hashed): replay golden final `5044b77b…0b0871` →
  `5ee10daf…ba4a14`; export-smoke hash `a0bff684…66c972` → `8cff6cad…d04b0c`.
  The kernel scenario's behaviour is unchanged (its dummies' shots still do 0 damage); the Windows job re-checks
  the new golden cross-OS.

## Deviations from the PLAN
- `PrimaryDefinition` replaces CONTENT_SCHEMA §8's generic `AttackDefinition` for the primary (the schema is
  updated): the owner's primary is a combo plus a charge, not one attack.
- The swing starts on the press (no delay); holding past 0.2 s then charges, so every charged bolt starts with a
  swing. A starting rule for the owner to judge.
- One `UtilityDefinition` with a `kind` (as CONTENT_SCHEMA §8 already says) instead of the PLAN's separate
  `GuardDefinition` and `BlinkDefinition`; data in `data/utilities/`.
- Enemies follow CONTENT_SCHEMA §3 (`EnemyDefinition` + `behaviour_id` + schema-checked `behaviour_params` +
  `AttackDefinition`), not a flat definition. The param schemas and `MIN_TELEGRAPH_TICKS` live in
  `src/content/behaviour_schemas.gd` (content may not name the sim; the schema doc is updated).
- Added a flow field (`NavField`, BFS on a 0.5 m grid, rebuilt every 10 ticks) after a render showed the Warden
  stuck behind a slab. It is derived state (rebuilt from hashed state on fixed ticks), not hashed itself.
- The Needle won't start a burst inside its flee distance: it backs off first ("backs off when you close in").
- The "Arena cleared" panel is proved by a sim test (the last wave cleared sets `cleared`) and a panel test, not
  by an e2e that clears three waves through real input (that needs a scripted fighter; Step 9's bot can do it).
- CI: Step 1's Verify run failed on gdlint (`WorldReader` over 20 public methods); Step 2 allowed the wide reader
  facade, and every run since is green on Verify, Windows (cross-OS golden) and Shots.
- **The Warden commits to its slam** (no turning during windup, slam and recovery). Found with a scratch bot
  (`build/bot.gd`, not evidence): at the starting turn rate (≈ 132°/s) you can't circle it from outside the
  slam's reach (6 m/s at 2.9 m ≈ 118°/s), so the shield could never be flanked, against the owner-approved
  design ("you flank it"). With the change, baiting the slam opens its back for ~0.7 s. The bot then cleared
  2/20 seeds with Guard and 3/20 with Blink (before: 0/40). A tuning call for the owner to judge.
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
- 2026-10-06 — Step 3: guard (front ±60° cut to 20%, 40% speed, no attacks) and blink (≤ 5 m toward the aim,
  stops before walls, 2.5 s cooldown, 0.1 s invulnerable) in `PlayerKit`; `UtilityDefinition` data; the
  `UtilityPicker` between Play and the arena, remembered in the profile; shield and blink-streak visuals.
  104 tests pass; goldens re-recorded on purpose.
- 2026-10-06 — Step 4: `EnemyAi` (Charger lane charge + daze, Warden shield + slam, Needle spacing + 3-bolt
  burst), `EnemyDefinition`/`AttackDefinition` data validated against behaviour schemas (≥ 24-tick telegraphs),
  `TelegraphViews` (outline + filling area), per-behaviour silhouettes, HP bars that drain, `NavField` pathing.
  Telegraph parity tests (drawn area == hit area) pass for all three. 118 tests pass; goldens re-recorded.
- 2026-10-06 — Step 5: `EncounterDefinition`/`WaveDefinition`/`WaveSpawn` (CONTENT_SCHEMA §4) with
  `data/encounters/combat_lab.tres`; `WaveDirector` in phase 9 (shuffled slots ≥ 6 m away, delays, cleared);
  the killer's kind kept for the death screen; `Hud` (HP, dash and utility readiness, wave, enemies left) and
  `EndPanel` (You died + cause / Arena cleared, Restart with the next seed, Main menu). 123 tests pass;
  goldens re-recorded.
- 2026-10-06 — Step 6: `HitFeel` reads the event log (flash on DAMAGE, shake when you're hit or land a full bolt,
  sparks on blocked/guarded hits, shards on a kill from a cosmetic RNG); `IsoRig.shake` with a "Screen shake"
  option (on by default; off means none). Sim hit-stop unchanged (3 / 5 / 4 ticks). 128 tests pass; goldens
  unchanged.
- 2026-10-07 — Step 4 fix: the Warden stops turning once it commits to a slam, so it can be flanked (see
  Deviations). 128 tests pass.
