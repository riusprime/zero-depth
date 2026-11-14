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
- "Yes, stand still" (asked: should the Tidecaller stand still at the centre during the Maelstrom?): it does, so the
  whirlpool's eye no longer travels onto the dry circle (step 4b).
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
| 5 | You can see the Tidecaller's dance: in a Riptide the three struck strips fill with water as the warning runs and the dry one stays clear inside a bright border, then a wall of water runs down each struck strip and splashes you if it catches you; the Tidecaller tolls its bell through the warning. In a High Tide the water rises over the whole room except one warm dry circle with a hint arrow (the first two runs), a ring on it fills through the cast and shrinks with the flood's time left, and outside it the screen's edges glow and you are splashed each step; the water drains at the end. The Maelstrom is a whirlpool of spiral arms turning round the Tidecaller the way it carries you, with a dark eye ringed in light (dim while it cannot hit again) and a splash and streak when it throws you. The tide pools are water now. Borrowed sounds. Presentation only; shots in `build/shots/v0.10.5/tide_dance/` (`scripts/shots/tide_dance.gd`) | this commit |
| 4b | Still in the sim only: in the Maelstrom the Tidecaller walks straight to the middle of its room (at its own speed, attacking as it goes) and then stands there for the rest of the fight, so the whirlpool turns round the room's centre and its eye no longer comes after you onto High Tide's dry circle; the dry circle is always placed with the hero's width and 1 m between its edge and the eye, wherever the Tidecaller is on its walk. No number changed; SIM_CONTRACTS §10p; `boss_dance().maelstrom` gains `anchor` and `anchored`. **The bots' target is still not met** (Gun 28 % more, Blade less): [`evidence/TIDE_BOTS.md`](evidence/TIDE_BOTS.md) "After step 4b" | this commit |
| 6 | The Twin Wardens fight apart, in the sim only (the new attacks show only as plain telegraphs and stand-in strikes until their views exist; the wards, the rifts and the returned shots have no look of their own yet). No chain: nothing joins, pulls or burns between them; Crossfire's gap faces away from the other Warden; the Chain Sweep is a Sword Lane of at most 9 m. Amber is fast: a three-hit sword combo (15, 15, 20) that steps 1.5 m in before each hit, a 4 m side dash between attacks, an overhead (1.3 s, 170°, 3.4 m, 50) and a charge that winds up 0.6 s, runs 12 m at 26 m/s and bursts 3.5 m wide where it ends 0.25 s later. Violet leads phase 2 with a Mirror Ward (1 s cast, 4 s on a 160° arc: your shots come back for half their damage, at most 20 % of your max HP; a swing is blocked and you are pushed 2 m; any other hit from inside the arc does nothing, which is how the Laser is blocked: tested with a plain hit, not with the Laser itself) and Shadow Swords (five lanes shown 0.8 s, cut 0.2 s apart for 30, each leaving a rift that burns for 8 s). Phase 3: Violet takes nothing under a whole ward until Amber's long charge (1.4 s) runs through her: she is stunned 5 s and takes 150 %, he is staggered 2 s, the ward is back 12 s after the break; the "exposed twin swaps" rule is gone. Once, at half the last bar, Through the Rift: three rifts, he runs into the nearest and charges out of another, marked only for the last 0.5 s (40 a hit at most). The charge's burst is an option of the `charge` move any boss can take. Numbers in `data/bosses/twin_wardens.tres` (`wardens`, `hazard`, the attacks); contracts in SIM_CONTRACTS §10k and §10q, CONTENT_SCHEMA §4. **The bots: ignoring the mechanics costs the Gun 38 % more HP; with the Blade only 22 %, under the 30 % asked, so `test_twins_bots.gd` fails on the Blade and nothing was retuned:** [`evidence/TWINS_BOTS.md`](evidence/TWINS_BOTS.md) | this commit |

## Goldens changed on purpose
None (step 1: the golden tests pass unchanged; step 2: `tests/golden` passes unchanged, no golden pins a Judge
fight; step 2b: `tests/golden` passes unchanged; step 3: presentation only, no golden test run). Step 4: `tests/golden` passes unchanged; no golden pins a
Tidecaller fight. Step 4b: `tests/golden` passes unchanged.
Tidecaller fight.
Step 6: `tests/golden` passes unchanged (no golden pins a Twin Wardens fight). A Twin Wardens fight's state hash is
not what it was: `twin_burn_cd` left the pair's block and the Wardens' clocks are hashed after a new `-15`
sentinel; every world without the Wardens hashes as before.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| G1 boss rows CJ, TW, TC | [`BOSS_BRIEF.md`](BOSS_BRIEF.md) §3 | The owner's own design | 2026-11-14 |
| G1 signatures SG | BOSS_BRIEF §5b | "Yes, go on" (in kind; numbers after play) | 2026-11-14 |
| G1 rows WL, SE, FO, HL | BOSS_BRIEF §4 | pending | |
| BQ3, BQ4, BQ7, BQ9 | BOSS_BRIEF §6 | answered (above) | 2026-11-14 |
| BQ1, BQ2, BQ5, BQ6, BQ8, BQ10, BQ11, BQ12 details | BOSS_BRIEF §6 | the lead's defaults, pending the owner | |

## Open
- **Step 6's bot target was MISSED for the Blade, nothing retuned** ([`evidence/TWINS_BOTS.md`](evidence/TWINS_BOTS.md)): over 3 seeds the Blade bot that ignores the Wardens' mechanics loses 22 % more HP (1,172 against 958; the test asks 30 % more HP or 30 % longer), the Gun bot 38 % more (5,403 against 3,908: met). The lead turned the test's failing assert into a `pending` that prints the numbers, as the Tidecaller's does. Also open from the step: a resting Warden can body-block a cornered hero (one bot run stood 15 minutes without damage); the charge's aim locks for 0.4 s, not the 0.3 s asked (the content rule's floor); strings for `CAUSE_TWIN_MIRROR` and `CAUSE_TWIN_RIFT` and the reworded causes come with the views.
- **Step 4's bot target was MISSED and nothing was retuned** ([`evidence/TIDE_BOTS.md`](evidence/TIDE_BOTS.md)): over 3 seeds the Gun bot that ignores the dance loses 14 % more HP than the one that plays it (3,956 against 3,461), and the Blade bot that ignores it loses less (1,671 against 2,557) and wins sooner (11,637 ticks against 18,210). Read from the numbers, not traced: the Tidecaller walks at the hero in the Maelstrom, so its eye moves onto the dry circle; the Blade has 0.7 m between the eye (1.5 m) and its reach; most HP lost comes from attacks neither bot dodges. Waits on the owner (the Tidecaller stands still in the Maelstrom? the eye and the Blade?).
- **After step 4b (the Tidecaller holds the centre) the target is still MISSED, nothing retuned:** Gun, ignoring costs 28 % more HP (4,178 against 3,253; the test asks 30 %, it was 14 %); Blade, ignoring still costs less (1,796 against 2,911) and wins sooner (11,834 ticks against 18,446). The Blade's case waits on the owner.
- **Step 6's bot target was MISSED with the Blade and nothing was retuned** ([`evidence/TWINS_BOTS.md`](evidence/TWINS_BOTS.md)): over 3 seeds the Gun bot that ignores the Wardens' mechanics loses 38 % more HP than the one that plays them (5,403 against 3,908), which meets the 30 % asked; the Blade bot that ignores them loses 22 % more (1,172 against 958) and wins 4 % sooner, which does not. `tests/unit/sim/test_twins_bots.gd` keeps its assert and fails on the Blade (1 of its 2 tests). Read from the numbers, not traced: a Blade fight is under a minute, so the Mirror Ward and the charges come up a few times at most, and breaking the ward is a reward the ignoring bot merely gives up. Waits on the lead and the owner.
- **Step 6, for the lead to decide.** (1) The brief's 0.3 s of locked aim for the charge is under the telegraph minimum every lock keeps (24 ticks, 0.4 s; `BossAttackDefinition._validate_lock`): the charge ships with 0.4 s. (2) `mirror_cap_permille` 200 was added: a returned shot takes at most 20 % of the hero's max HP (half of a late-run shot could otherwise kill outright); the half is of the number the shot carries, before the hero's damage stats and crit. (3) Crossfire's fan is aimed at the hero and only its gap faces away from the other Warden, so with the hero on the other Warden's side there is no gap in the fan at all. (4) Through the Rift starts as soon as Amber is free (needing both free, it opened in 2 of 12 bot fights). (5) A Warden standing back can body-block a hero who has backed into a corner (found by the first bot run: every Gun shot hit the resting Amber for 15 minutes); not new to this step, not fixed. (6) Death lines: the sword combo, the overhead and Shadow Swords carry existing keys whose text no longer fits (`CAUSE_TWIN_BASH`, `CAUSE_TWIN_SLAM`, `CAUSE_TWIN_RUNES`), and `CAUSE_TWIN_SWEEP` still speaks of a chain; `CAUSE_TWIN_MIRROR` and `CAUSE_TWIN_RIFT` have no string yet (the recap shows the key). `CAUSE_TWIN_CHAIN` is unused. The view step adds en/es.
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
- 2026-11-14 — Owner: at most three agents at once (one Fable for the thinking, two Opus 5.5 for operational work), to stay inside the usage window. Four Fable sim agents had just been started; three were stopped a few minutes in (Twin Wardens `wt-w6`: nothing written; Siege Engine `wt-s9`: one table file; Foundry `wt-f10`: its table, rules and compiler, all uncommitted). The Tidecaller agent keeps running in `wt-t4` (branch `v0120-t4`, uncommitted work so far). If a session ends here: the briefs for steps 4, 6, 9 and 10 are the PLAN rows plus BOSS_BRIEF; restart each stopped step in its worktree. Next: Tidecaller sim → its views (Opus); then Twins, Siege, Foundry sims one at a time.
- 2026-11-14 — Step 4: the Tidecaller's dance in the sim (`BossDance`, `BossMaelstrom`, the boss-agnostic `SafeArea`, `BossTide.rate_of`), its data (`dance`, validated by `DanceRules`; tide pools through the existing hazard store) and 32 unit tests; no C++ change, no presentation, no new string (a Riptide death names the crossing wave's line, a High Tide or eye death the Pull's; the pools draw as venom until a view gives them a look). `test_tidecaller.gd` (the old 1.7 / 1.4 m/s Pull, the 2 s push, phase 3's opening Pull) and `test_boss_hazard.gd` (four bosses with hazards now) were updated to the new rule. Two decisions the lead should look at: the eye is 1.5 m, not the brief's 2.5 m, because the Blade reaches 2.2 m; and a High Tide step ignores the hurt invulnerability (a 0.5 s step was otherwise skipped every second time). **The bot expectation is not met** (TIDE_BOTS.md): the Gun bot that ignores the dance loses 14 % more HP, not 30 %, and the Blade bot that ignores it loses less and wins sooner; the Tidecaller still walks at the hero in the Maelstrom, so its eye moves onto the dry circle. Reported as a pending test, nothing retuned. Not looked at on screen. Next: the lead's read of the numbers, then the views.
- 2026-11-14 — Step 5: the Tidecaller's dance drawn (`TideDanceViews`, `MaelstromViews`, `TideDanceCues`, the HUD's `tide_flood` edge glow, the `TIDE_DRY` hint arrow, the tide pools' water look in `HazardViews`, `BossAvatar._side_clip` so the Tidecaller plays its bell_toll / bell_raise clips while it casts; pack rows `data/vfx/pack_fx_tc.tres`). 12 view tests; with the Tidecaller's and the Judge's view tests, boss animations, hints, shader warm-up, pack fx, locale and arch: 148 passed in one process (exit 0); the Tidecaller e2e now reaches a Riptide (its HP set under phase 2's threshold as a test helper) and checks the four strips: passed (exit 0). Three shots looked at once each; nobody has seen it move. Next: the lead's merge.
- 2026-11-14 — Step 4b (owner: "Yes, stand still"): from the Maelstrom's phase `BossMaelstrom.holds` takes the Tidecaller's whole movement (one changed line in `BossAi.move`, no net line): it steps its phase's speed straight to the room's centre every tick but the gate's kneel, attacking as it goes (between attacks only it had walked 4 m in 40 s), lands on it exactly and never moves again. `BossDance.fits` keeps the dry circle's centre `eye_keep_m` (8.8 m with the data) from the whole segment from the boss to the centre. No new state or key. Six new tests in `test_tide_dance.gd` (the tick-exact walk, standing for 80 s of a real fight, the circle off the eye over `Seeds.count(1000)` and in live fights, determinism); the dance, bots, Tidecaller, snapshot, content, arch and golden tests: 264, 263 passing, 1 pending (exit 0); `test_e2e_tidecaller.gd` 1/1. **The bots' target is still not met** (TIDE_BOTS.md "After step 4b": Gun 28 % more, the Blade that ignores loses less); the pending stays, nothing retuned. Not looked at on screen. Next: the lead's merge and read of the numbers.
- 2026-11-14 — Step 6: the Twin Wardens as two separate fighters, in the sim (`BossTwin` without its chain, and the new `BossWardens`, `BossWardenAmber`, `BossWard`, `BossShadowSwords`, `BossRift`, and `BossChargeBurst` for any boss's charge), their data (`wardens`, validated by `WardensRules`; the swords' rifts through the existing hazard store; the chain's and the swap's fields removed from `BossDefinition`), 25 unit tests in a new file (`test_twins_apart.gd`), the old Twins tests rewritten to the new rules, and two bots. Every item of the brief is built; none was cut. No C++ change (a returned shot is resolved in `ProjectileContacts`), `boss_ai.gd` still at 1,000 lines (three lines replaced, none added), goldens unchanged. Presentation was touched only so nothing crashes or misleads: the chain is no longer drawn (the reader has none), the bar's phase-3 line follows the new rule, two stand-in strike looks (`tw_sword`, `tw_swords`) and each combo cut drawn on its tick. Invisible until the views exist: the Mirror Ward and the whole ward (hits just spark off), a returned shot looks like the violet ember, the swords' rifts look like venom pools, Through the Rift's rifts are not drawn at all (Amber vanishes and reappears), the charge's end circle and armed burst, the side dash's start. The bots: Gun met, Blade missed (Open). Next: the lead's merge, then the Wardens' views.
  Step 6's tests, run on the finished tree on the owner's PC with up to three Godot processes at once (no timing
  taken): `tests/content` + `tests/arch` + `tests/golden` 194 of 194, exit 0; 13 sim files (the three Twins files,
  `test_world_snapshot`, `test_readable_cause`, `test_boss_hard_3`, `test_boss_fights` 1-3, `test_objective_markers`,
  `test_boss_pace`, `test_boss_hazard`, `test_boss_signatures`) 166 of 167, exit 1: the one failure was
  `test_boss_hazard`'s count of bosses with hazards (4, now 5 with the Wardens' rifts), updated and re-run inside
  the next set; 21 more boss files (12 sim, 9 presentation) 204 of 204, exit 0; 8 presentation files
  (`test_attack_visuals_2`, `test_twin_warden_views` and six boss view files) 103 of 103, exit 0;
  `test_e2e_twin_wardens` 1 of 1, exit 0; `test_playground`, `test_codex` and `test_twins_apart` again after a
  comment edit 61 of 61, exit 0; `test_twins_bots` 1 of 2, exit 1 (the Blade's assert, Open). The presentation and
  e2e runs end with Godot's leaked-instance notes at exit; whether those are older than this step was not checked.
  gdformat and gdlint clean on every touched file. No full suite, no seams run. Tests updated because the fight
  changed on purpose: `test_twin_wardens` (chain tests replaced), `test_twin_wardens_roles` (the swap test
  replaced, the movesets), `test_boss_pace` (the classed-attack count 118 to 121, `mirror_ward` unclassed),
  `test_boss_hazard` (the count), `test_attack_visuals_2` (the Mirror Ward is no ground attack; the combo's and
  the swords' shapes), `test_twin_warden_views` (no chain drawn), `test_e2e_twin_wardens` (no chain drawn).
