# v0.12.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0120`, cut from `main` at `feedd802`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-14.)

- **Planned, nothing built.** The owner's boss brief is written up in [`BOSS_BRIEF.md`](BOSS_BRIEF.md) and this
  version's PLAN follows it: one boss at a time, the Clockwork Judge first.
- **Decided by the owner (2026-11-14):** the version (v0.12.0), 25 % per hour orb, the Twins on one HP pool with
  three bars, The Fallen "remembers your run", the signatures approved in kind.
- **Next:** step 1 (the Judge's building blocks: the attack-speed debuff, floor pickups, slow fields for shots),
  then step 2 (the Judge's fight).
- **Not approved yet:** the lead's rows for the Warlord, Siege Engine, Foundry and Hive Lens (asked when each
  boss's step starts), and the lead's default answers listed in the PLAN.
- **The owner's folder** is on `claude/v0120`. After this checkout the native library must be rebuilt before the
  game or a test runs (`bash scripts/native/build.sh all`): `main` brought a change in `native/`.
  `project.godot` has an uncommitted change that is not the lead's (the editor re-saved it); left alone.

## Owner decisions (2026-11-14)
- "v0.12.0 (Recommended)": the boss rework is its own version on a new branch from `main`.
- "25 per orb (Recommended)": three hour orbs return the Time Wave's 75 %.
- "One pool, 3 bars (Recommended)": the Twin Wardens keep one HP pool; no chain.
- "Remembers your run (Recommended)": The Fallen casts mechanics of the bosses killed this run; the 15 s vanishing
  goes.
- "missing some signature mechanics that make it difficult and rememberable" → BOSS_BRIEF §5b; then, asked whether
  those were the kind meant: "Yes, go on".

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| 0 | Plan and docs | this commit |

## Goldens changed on purpose
None.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| G1 boss rows CJ, TW, TC | [`BOSS_BRIEF.md`](BOSS_BRIEF.md) §3 | The owner's own design | 2026-11-14 |
| G1 signatures SG | BOSS_BRIEF §5b | "Yes, go on" (in kind; numbers after play) | 2026-11-14 |
| G1 rows WL, SE, FO, HL | BOSS_BRIEF §4 | pending | |
| BQ3, BQ4, BQ7, BQ9 | BOSS_BRIEF §6 | answered (above) | 2026-11-14 |
| BQ1, BQ2, BQ5, BQ6, BQ8, BQ10, BQ11, BQ12 details | BOSS_BRIEF §6 | the lead's defaults, pending the owner | |

## Open
- See PLAN "Open items".

## Blockers
- None.

## History
- 2026-11-14 — The boss brief arrived (spoken), was written up with two read-only code surveys, gained the
  signatures, and four questions were answered. Branch cut, PLAN and PROGRESS written. Next: step 1.
