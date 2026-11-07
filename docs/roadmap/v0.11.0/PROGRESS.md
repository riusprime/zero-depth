# v0.11.0 — progress

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-07, lead session 1.)

- **Wave 1 merged** (S1 Voids, S2 Shade wisps hidden, S3 Siege volley 2 + no smoke, S4 Lens Drone on VAT, S7 model
  prompts). Seams green at d4c0d878 (637/637). Pushed.
- **Q1–Q30 answered.** Q8: the Laser is straight without Homing. Q13: the owner designs the other boss fights
  themselves and sends a brief; Q9–Q11 (Gatekeeper, Lantern Shade, Twins) stand. No BOSS_AUDIT.
- **G1s approved 2026-11-07** (every row): [`SPELLS.md`](SPELLS.md), [`ENEMIES.md`](ENEMIES.md),
  [`PIERCE.md`](PIERCE.md) (P2: the flag), [`WISP_GAPS.md`](WISP_GAPS.md) (wider: hero + 0.7 m).
- **Next:** Wave 2 O2–O5 (hint arrow, Gatekeeper, Lantern Shade, Twins) can start from Q9–Q12; O1 (Laser) sim can
  start, its look waits for the sketch; S2b and S6 are unblocked; O9–O13 (hordes, spells, enemies) are unblocked; O6–O8 after the owner's boss brief.
- **Wave 2 so far:** S6, S2b, O2, S7b, O1 + O1c (Laser lance), O3 (Gatekeeper pillars), O4 (Lantern Shade) merged.
  **Building:** O4b (the Lights Out shield back; Sonnet, wt-o4b), O5 Twins + their animation (Opus, wt-o5). O6–O8 wait
  for the owner's boss brief; the Laser's look waits for the sketch.
- **Agents (owner, 2026-11-07):** at most 3 Sonnet (light, exact briefs) + 2 Opus at once.
- **Local note:** `project.godot` has an uncommitted editor rewrite (it drops the `[rendering]` settings and
  `locale/fallback`). It is not the lead's change; don't stage it. `wt-seams` is the lead's clean seams worktree.

## Done
| Step | Outcome | SHA |
|---|---|---|
| S1 | Voids stop jumping: a cap end is quiet (no Split/Echo/Ring), minis are culled first, queued spawns count toward the cap, Mine stops on each Twin lane. Note: Twin Lv 5 + Split Lv 4 at the cap opens 35 of 108 queued minis (the rest dropped, by design) | 0830fa41 |
| S2 | The Lantern Shade's wisps draw as the MultiMesh again, so the dark hides them outside light (4 m outline stays) | 9a7e625d |
| S3 | Siege Engine: volley 2 (and phase 3's 3rd) hidden until the one before lands, then shown 1.2 s; Mortar Grid bursts drop the pack Smoke | e3caade9 |
| S4 | The Lens Drone draws through VAT (SoloVat), hover height matching the live avatar | ff54e50a |
| S6 | A held card the current form doesn't compile shows "Does nothing with this form" on the wand screen (owner: PIERCE.md P2) | 3d790012 |
| S2b | Wisp Bloom 2 and 3 at 24 shots (lane 1.59 m at 4 m, was 0.91), Bloom 1 at 25 (2.47 m, was 1.18); test pins ≥ 1.40 m | 20113849, d86bf471 |
| O2 | Hint arrow + ping (sim ObjectiveMarkers, HUD ObjectiveHints), first 2 meeting runs per mechanic (Codex `mechanics` page), Options → Accessibility → Boss hints | 32d98682 |
| S7b | OWNER_TODO §3.2: prompts for the 5 horde critters and 10 new enemies | a62d881b |
| O1 | The Laser fires an instant lance every 3 s while held, through every enemy; 3 hits' worth of status; Rapid Fire / Echo / Big Shot per Q6; Pierce and Mine off its row; Homing plans one smooth path through up to 5 targets (no leg turns > 12°). forms_dps one target 1400 → 1350 (−3.6 %), a line 500 → 2250, Homing pack 500 → 2250; owner then chose falloff (O1c). Minimal view until the sketch | b941fd61, c08e5196, bec1c43e |
| O3 | Gatekeeper: 3 quake pillars from phase 2 (back in phase 3), a 3 % ring pulse every 3 s; Shock Lanes through a pillar shatters it, stun 2 s at ×1.5, at most 2 a phase; hint arrow; "STUNNED · VULNERABLE" on the bar. Two ways (seed 5): `lure ticks=5690 seconds=94.8 stuns=4`, `ignore ticks=2299 seconds=38.3` | 2233f520 |
| O1c | The lance's damage falls 15 % per enemy after the first (floor 40 %); full speed while held; Homing's tail runs to the first wall (40 m cap). forms_dps: one target 1350, line 1662, Homing pack 1662 (old beam 1400 / 500 / 500); owner: keep 15 % | df497de4 |
| O4 | Lantern Shade never immune: 40 % in the dark, 150 % in a lit pool (100 % in your own light and in full light); lanterns lit 6 s; dark 9 s / light 4 s; bar tag + coloured numbers; hint at unlit lanterns. Bots: `lanterns ticks=1081` (18.0 s), `ignore ticks=2341` (39.0 s), both `zero 0` | 99d92b20 |
| S7 | OWNER_TODO §3.2: prompts for the 8 code-made enemies in the Charger's style, palette-A role colours | cc0d326f |

## Goldens changed on purpose
—

## Gates
| Gate | State |
|---|---|
| Questions Q1–Q30 | all answered 2026-11-07 |
| Owner's boss brief (bosses besides Gatekeeper, Shade, Twins) | waiting on the owner |
| G1 SPELLS, PIERCE, ENEMIES, WISP_GAPS | approved 2026-11-07 (row by row) |
| G2 purpose rooms | not made |

## History
- 2026-11-07: Phase 0 (five read-only audits), PLAN draft, owner questions answered in six batches. The owner asked
  for a fresh session to continue from this PLAN.
- 2026-11-07 (lead session 1): Q8 and Q13 asked and recorded (Q13: the owner will brief the other boss fights). Wave 1
  (S1, S2, S3, S4, S7) built by agents from 8dc654a0 and merged. `bash scripts/ci/seams.sh` in the clean `wt-seams`
  worktree at d4c0d878 (owner's PC, i7-10700K): `Scripts 110, Tests 637, Passing Tests 637, Asserts 76190, Time
  1264.497s`, `---- All tests passed! ----`, `check_gut_log: ok (637 passing, minimum 1)`. G1s SPELLS, ENEMIES,
  PIERCE and WISP_GAPS written for the owner. The S2 shot (`build/shots/v0.9.0/nb4/1_lantern_shade_dark.jpg` in the
  agent's worktree) was not looked at; S3 and S4 have no shot (NOT YET RUN).
- 2026-11-07: the owner went through the four G1s row by row (questions): all approved; Pierce P2; wisp lanes wider
  (hero + 0.7 m).
- 2026-11-07: S6, S2b, O2, S7b merged (the two `.translation` files conflicted between S6 and O2; rebuilt by an import
  from the merged `strings.csv`, both new lines checked in en and es). `bash scripts/ci/seams.sh` in `wt-seams` at
  74912d36: `Scripts 111, Tests 641, Passing Tests 641, Asserts 76219, Time 1491.386s`, `---- All tests passed! ----`,
  `check_gut_log: ok (641 passing, minimum 1)`. The hint arrow's look not yet seen (no shot).
- 2026-11-07: O1 and O3 merged (the `.translation` files rebuilt by an import after each merge: O1 hadn't committed
  them, O3 conflicted). Owner on the Laser: falloff per enemy, full speed, Homing's tail to the wall (O1c). O3 notes for
  the owner: phase 3's replacement pillars rise in new spots; pillars reuse the spike model; the luring bot is slower
  than ignoring them (the bot waits for the cross), not a balance verdict.
- 2026-11-07: seams at 8a724f12 (O1 + O3): `Scripts 111, Tests 642, Passing Tests 642, Asserts 76250, Time 1365.441s`,
  `---- All tests passed! ----`, `check_gut_log: ok (642 passing, minimum 1)`. O1c and O4 merged after it; O3 and O4
  both scale boss damage in `damage.gd` (`tick_dot`): the conflict kept both; the Gatekeeper, Shade, bots,
  boss-challenge and readable-cause tests on the merge: `Tests 62, Passing Tests 62`. Owner: keep the 15 % falloff;
  bring back the Lights Out shield (O4b).
