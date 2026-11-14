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
| 0 | Plan and docs | `b020a3bd` |
| 1 | Nothing the player sees yet: a boss can slow the hero's attacks (`BossSlow`), place pickups that return it (`BossPickups`) and lay fields that slow the hero's shots (`BossShotFields`). No boss uses them; contracts in SIM_CONTRACTS §10n | `c7f292e7` |
| 2 | The Clockwork Judge fights with time, in the sim only (nothing of it is drawn until step 3): a Time Wave every 25 s takes 75 % of your attack speed; three hour orbs give it back, 25 each; from phase 2 stopped gears stand across the ways to the orbs, slow fields are laid between you and the Judge (it side-steps a shot crawling through one), and the Bell throws you back to where you stood 4 s ago, with the Verdict aimed at that spot; in phase 3 the orbs last 10 s, the copy trails 6 s, the Bell tolls twice, and the Judge returns once to its own past. Numbers in `data/bosses/clockwork_judge.tres` (`time`); contracts in SIM_CONTRACTS §10o, CONTENT_SCHEMA §4; the two bots in [`evidence/JUDGE_BOTS.md`](evidence/JUDGE_BOTS.md) | this commit |
| 3 | You can see the Judge's new fight: its cast (a clock dial under it, a ring closing on it) and the golden ring that crosses the room when the Time Wave lands; each hour orb as the pack's Basic Area 04 with a small clock above it (in phase 3 the clock's hand and the effect run down with the orb's 10 s) and a hint arrow the first two runs; the attack speed lost and the orbs won back on the HUD, over the HP plate ("Attacks slowed 75 %", three pips); each stopped gear as a brass cog standing on its wall's footprint, rising when placed and sinking at its end; each slow field as a cool rippling disc; your pale copy where the Bell would throw you, the Bell's ring closing on it with a line from you to it, and a flash at both ends of the throw and of the Judge's own return. Borrowed sounds for the wave, the Bell, the throw, the return and an orb taken. Presentation only; shots in `build/shots/v0.10.5/judge_time/` (`scripts/shots/judge_time.gd`) | this step's commit |

## Goldens changed on purpose
None (step 1: the golden tests pass unchanged; step 2: `tests/golden` passes unchanged, no golden pins a Judge
fight; step 3: presentation only, no golden test was run or moved).

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
- 2026-11-14 — Step 1: the Judge's three building blocks in the sim with their unit tests, no C++ change, no boss
  using them, goldens unchanged. Found while building: a Gun form counts attack speed at half (the Laser, the
  Lance), so the cut is applied after that share and every weapon loses all of it; the Blade's rate floor (25 %) is
  exactly the Time Wave's 75 %, so Heavy Hands on top adds nothing for a Blade. The boss data fields (content →
  tables) are left for step 2, where the Judge declares them. Next: step 2.
- 2026-11-14 — Step 2: the Judge's fight in the sim (`BossTime`, `BossGears`, `BossRewind`), its data fields
  (`BossDefinition.time`, `TimeRules`, `TimeCompiler`, the `time_wave` move), 24 unit tests and two bots. No C++
  change, goldens unchanged. Built as the step's brief, with these choices for the lead to confirm: the Time Wave is
  an attack on its own cadence (the Judge stands and casts), the Bell is cast beside its attacks (so a toll can fall
  inside a Verdict's windup); the Verdict aims at the copy in phases 2-3, which also means the punish and the
  gap-closer (both the Verdict) no longer aim at a hero who keeps moving; the side-step and the Judge's return happen
  only between two of its attacks. The bots: ignoring the mechanics takes 2.45 times as long with the Gun and 1.84
  times with the Blade, and costs about 3.5 times the HP; a throw by itself seldom lands in a Verdict's square (5 of
  68 throws for the bots that ignore). Nothing of the new mechanics is drawn yet: the gears are walls you cannot see
  and the throw has no warning on screen until step 3. Next: step 3.
- 2026-11-14 — Step 3: the Judge's time mechanics drawn (`JudgeTimeViews`, `JudgeRewindViews`, `AttackSlowHud`,
  the pack rows `data/vfx/pack_fx_cj.tres`), 13 unit tests and the Judge's e2e extended through a Time Wave and an
  orb. No sim change. Choices for the lead to confirm: the orbs' hint follows the brief's row CJ2 (the first two
  runs that meet it) and is drawn like the pillars' (an arrow, no text), not at every meeting as the pillars'
  is; the cast plays the model's `spread` (the echo's arms), no new clip; a gear's wheel is set low (its top 1.6 m)
  so the hero shows over it, and the copy is drawn through anything in front of it. Stand-ins: the clock over an
  orb and the gears' cog are built in code (OWNER_TODO §3.5), the five sounds are existing cues re-pitched
  (OWNER_TODO §4); a gear and a slow field have no sound. Nobody has seen it move: the owner's playtest judges
  whether it reads. The Bell's Verdict square (the sim's follow-up) is not drawn. Next: the lead's merge.
