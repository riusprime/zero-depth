# v0.12.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0120`, cut from `main` at `feedd802`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-14, evening.)

- **The Clockwork Judge's new fight is built and waits for the owner to play it** (steps 1–3d, head `f4a4d2ab`,
  not pushed): the Time Wave and three hour orbs, the stopped gears and slow fields from phase 2, the Rewind with
  the Bell's own Verdict, the Judge's one return. Nobody has watched it move: stills, bots and tests only.
- **Seams on `92c51874`** (clean worktree, owner's PC, 2026-11-14): **729 of 730, 1,180 s of tests, exit 1.** The
  one failure, `test_readable_cause.gd` `test_every_cause_line_exists_in_both_languages`, was the Time Wave having
  no cause-of-death line; a cast that never hits needs none (CONTENT_SCHEMA), and the test now says so (`f4a4d2ab`).
  Re-run of that file with `test_attack_visuals_2.gd`: 15 of 15, exit 0. The whole seams set was not run again.
- **For the owner to judge on the Judge** (`OWNER ONLY`): whether it is "difficult but learnable"; 0.45 s to leave
  the Bell's Verdict (the bot that plays is still hit on 7 of 26 throws, not traced); the gears' height (1.64 m, so
  the hero shows over them); the hint arrows (first two runs only); the faint rings on the Ruins floor; the stand-in
  clock and cogs; the borrowed sounds. Bot numbers: [`evidence/JUDGE_BOTS.md`](evidence/JUDGE_BOTS.md).
- **Not measured:** the Judge at floor-5 scaling (the bots fight it unscaled).
- **Next (owner, V2):** every other boss is built before the playtest: Tidecaller, Twin Wardens, Siege Engine and
  Foundry first, then the Warlord and Hive Lens, The Fallen last. Nothing is pushed to GitHub until the owner has
  played them all.
- **Not approved yet:** the lead's rows for the Warlord, Siege Engine, Foundry and Hive Lens (asked when each
  boss's step starts), and the lead's default answers listed in the PLAN.
- **The owner's folder** is on `claude/v0120`. `project.godot` has an uncommitted change that is not the lead's
  (the editor re-saved it); left alone.

## Owner decisions (2026-11-14)
- "v0.12.0 (Recommended)": the boss rework is its own version on a new branch from `main`.
- "25 per orb (Recommended)": three hour orbs return the Time Wave's 75 %.
- "One pool, 3 bars (Recommended)": the Twin Wardens keep one HP pool; no chain.
- "Remembers your run (Recommended)": The Fallen casts mechanics of the bosses killed this run; the 15 s vanishing
  goes.
- "push it locally, i'll test all the bosses at the same time, then after playtest we decide if they are ready for main
  at github" (after the Judge was built): no push to GitHub before the playtest; all bosses are built first (PLAN V2).
- "missing some signature mechanics that make it difficult and rememberable" → BOSS_BRIEF §5b; then, asked whether
  those were the kind meant: "Yes, go on".

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| 0 | Plan and docs | `b020a3bd` |
| 1 | Nothing the player sees yet: a boss can slow the hero's attacks (`BossSlow`), place pickups that return it (`BossPickups`) and lay fields that slow the hero's shots (`BossShotFields`). No boss uses them; contracts in SIM_CONTRACTS §10n | `c7f292e7` |
| 2 | The Clockwork Judge fights with time, in the sim only (nothing of it is drawn until step 3): a Time Wave every 25 s takes 75 % of your attack speed; three hour orbs give it back, 25 each; from phase 2 stopped gears stand across the ways to the orbs, slow fields are laid between you and the Judge (it side-steps a shot crawling through one), and the Bell throws you back to where you stood 4 s ago, with the Verdict aimed at that spot; in phase 3 the orbs last 10 s, the copy trails 6 s, the Bell tolls twice, and the Judge returns once to its own past. Numbers in `data/bosses/clockwork_judge.tres` (`time`); contracts in SIM_CONTRACTS §10o, CONTENT_SCHEMA §4; the two bots in [`evidence/JUDGE_BOTS.md`](evidence/JUDGE_BOTS.md) | this commit |
| 2b | Still in the sim only: the Judge's Bell now throws you onto a Verdict you must leave. Each toll locks a Verdict square of its own where your copy stands and drops it 0.45 s after the throw (the Verdict's damage, once; phase 3's two tolls bring two). The Judge's ordinary Verdict follows you again in every phase, so the punish and the gap-closer threaten a hero who keeps away. New `time` key `bell_verdict_delay_seconds`; `WorldReader.boss_time()` gains `bell_squares`; SIM_CONTRACTS §10o, CONTENT_SCHEMA §4; the bots after it in [`evidence/JUDGE_BOTS.md`](evidence/JUDGE_BOTS.md) | this commit |
| 3 | You can see the Judge's new fight: its cast (a clock dial under it, a ring closing on it) and the golden ring that crosses the room when the Time Wave lands; each hour orb as the pack's Basic Area 04 with a small clock above it (in phase 3 the clock's hand and the effect run down with the orb's 10 s) and a hint arrow the first two runs; the attack speed lost and the orbs won back on the HUD, over the HP plate ("Attacks slowed 75 %", three pips); each stopped gear as a brass cog standing on its wall's footprint, rising when placed and sinking at its end; each slow field as a cool rippling disc; your pale copy where the Bell would throw you, the Bell's ring closing on it with a line from you to it, and a flash at both ends of the throw and of the Judge's own return. Borrowed sounds for the wave, the Bell, the throw, the return and an orb taken. Presentation only; shots in `build/shots/v0.10.5/judge_time/` (`scripts/shots/judge_time.gd`) | `b06f79c5` |
| 3b | You can now see the Verdict the Bell throws you onto: each toll's square is drawn on the ground as the Judge's own Verdict square is (a dull outline while it follows your copy, the lock's flash once it is locked, in the same gold light), and when it drops it strikes with the same column of light and the same slam sound as the ordinary Verdict. Presentation only; no shot taken | this commit |
| 4 | The Tidecaller's dance, in the sim only (nothing of it is drawn yet, so until its views exist the new damage is invisible): its Pull drags you at 75 % of your own run speed and its push throws you 6 m in half a second; from phase 2 Riptide floods three strips of four, four casts in a row in the written order (35 % of max HP a hit); the last third is the Maelstrom, which carries you round the Tidecaller and inward for the rest of the fight, with an eye that takes 40 % and throws you out, and High Tide on top of it (one dry circle, 6 % a second outside it for 6 s); each crossing wave leaves a slowing tide pool, five at most. Numbers in `data/bosses/tidecaller.tres` (`dance`, `hazard`); contracts in SIM_CONTRACTS §10p, CONTENT_SCHEMA §4. **The two bots do not show that ignoring it costs clearly more:** [`evidence/TIDE_BOTS.md`](evidence/TIDE_BOTS.md) | this commit |

## Goldens changed on purpose
None (step 1: the golden tests pass unchanged; step 2: `tests/golden` passes unchanged, no golden pins a Judge
fight; step 2b: `tests/golden` passes unchanged; step 3: presentation only, no golden test run). Step 4: `tests/golden` passes unchanged; no golden pins a
Tidecaller fight.

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
- 2026-11-14 — Step 2b: the Rewind's teeth, sim and tests only. Each Bell toll brings a Verdict of its own
  (`BossRewind`: follows the copy while the toll is awaited, locks at the toll, drops `bell_verdict_delay_seconds`
  = 0.45 s later, hits once through the Verdict's damage and death cause, whatever the Judge is doing); the ordinary
  Verdict is back on the hero in every phase. `boss_time()` gained `bell_squares` (no key renamed or removed); a
  new event `judge_bell_verdict`. No C++ change, goldens unchanged. Choices for the lead to confirm: the square locks
  on the copy's spot even when the hero landed beside it (the copy's spot was in a gear or the Judge); it drops
  during a phase gate too; a boss with `time` must now hold a `verdict` attack; the bot that plays now leaves only
  the Bell's square, not the ordinary Verdict. The bots: the Bell's Verdict hit the bot that ignores on 59 of 67
  throws (5 of 68 in step 2) and the bot that plays on 7 of 26; why those 7 was not traced.
- 2026-11-14 — Step 3: the Judge's time mechanics drawn (`JudgeTimeViews`, `JudgeRewindViews`, `AttackSlowHud`,
  the pack rows `data/vfx/pack_fx_cj.tres`), 13 unit tests and the Judge's e2e extended through a Time Wave and an
  orb. No sim change. Choices for the lead to confirm: the orbs' hint follows the brief's row CJ2 (the first two
  runs that meet it) and is drawn like the pillars' (an arrow, no text), not at every meeting as the pillars'
  is; the cast plays the model's `spread` (the echo's arms), no new clip; a gear's wheel is set low (its top 1.6 m)
  so the hero shows over it, and the copy is drawn through anything in front of it. Stand-ins: the clock over an
  orb and the gears' cog are built in code (OWNER_TODO §3.5), the five sounds are existing cues re-pitched
  (OWNER_TODO §4); a gear and a slow field have no sound. Nobody has seen it move: the owner's playtest judges
  whether it reads. The Bell's Verdict square (the sim's follow-up) is not drawn. Next: the lead's merge.
- 2026-11-14 — Step 3b: the Bell's Verdict squares are drawn (TelegraphViews.draw_extra, owned by JudgeRewindViews) and their drop strikes like the Verdict (BossStrikeViews reads the `judge_bell_verdict` event; JudgeTimeCues gives it the slam). Three new view tests pass with the Judge's presentation tests, the arch tests and the Judge e2e. `test_attack_visuals_2.gd` has three failures on its `time_wave` row that were there before this step (the wave has no look): not touched. Not looked at on screen. Next: the lead's merge.
- 2026-11-14 — Step 4: the Tidecaller's dance in the sim (`BossDance`, `BossMaelstrom`, the boss-agnostic `SafeArea`, `BossTide.rate_of`), its data (`dance`, validated by `DanceRules`; tide pools through the existing hazard store) and 32 unit tests; no C++ change, no presentation, no new string (a Riptide death names the crossing wave's line, a High Tide or eye death the Pull's; the pools draw as venom until a view gives them a look). `test_tidecaller.gd` (the old 1.7 / 1.4 m/s Pull, the 2 s push, phase 3's opening Pull) and `test_boss_hazard.gd` (four bosses with hazards now) were updated to the new rule. Two decisions the lead should look at: the eye is 1.5 m, not the brief's 2.5 m, because the Blade reaches 2.2 m; and a High Tide step ignores the hurt invulnerability (a 0.5 s step was otherwise skipped every second time). **The bot expectation is not met** (TIDE_BOTS.md): the Gun bot that ignores the dance loses 14 % more HP, not 30 %, and the Blade bot that ignores it loses less and wins sooner; the Tidecaller still walks at the hero in the Maelstrom, so its eye moves onto the dry circle. Reported as a pending test, nothing retuned. Not looked at on screen. Next: the lead's read of the numbers, then the views.
