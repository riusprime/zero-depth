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
- **Built and merged:** Wave 1; S6, S2b, O2, S7b; O1 + O1c (Laser lance); O3, O4 + O4b, O5 + O16a (Gatekeeper,
  Lantern Shade, Twins); O9 (horde critters + surges, **probe missed 144 fps**); O10 (spell slots + Frost Nova,
  Fireball, Sky Strike). Merged at 5ffee376.
- **Building:** nothing (O9c merged).
- **Merged since:** O11 (all 15 spells), O9b (surge cap 50 at 144 fps), VX (pack effects for the new spells, lance, quake pillars).
- **Waiting on the owner:** the boss brief (O6–O8), the Laser sketch. O16 for the other bosses, O12 balance, O13
  enemies/rosters, O14 Runic Stone, O15 rooms still to come.
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
| O4b | The Lights Out telegraph shield back (1.00 s, the whole windup); bots `lanterns ticks=1201`, `ignore ticks=2611`, `leak 0` | 30a266dc |
| O5 | Twin Wardens: yellow (Shield Bash, Chain Sweep, Charge, Ground Slam) leads P1, purple (Crossfire, Orb Volley, Rune Ring, Blink) P2, both P3 on three full bars (667/333); the resting twin takes 0 with a "not now" spark and casts a bolt every 4 s; P3 turns never overlap, the exposed twin swaps every 10 s (×1.5 / ×0.5); Crossfire unshielded; HP 2500 → 3000. Bots: `melee ticks=4759 seconds=79.3`, `ranged ticks=5369 seconds=89.5` | d3c87976 |
| O16a | The Twins' clips less stiff (anticipation, recoil, idle sway, hit reactions) | 728d80e3 |
| O9 | Five critter kinds on one rule set (contact 3 dmg / 0.5 s, 8 HP, ~5 m/s; the bat flies), one per biome; surges 1–2 a floor, 30–60 over 10 s, never in Overrun/arena/Lockdown/boss rooms, `alive_cap` 120; HUD line + sound. Probe (owner's PC, two other Godot test runs going): `after (crowd full): avg=20.18 ms (49.6 fps) … 1%-low=31.7 fps` — **missed 144** | e6657bac, 08cbb00a |
| O10 | 4 spell slots (Replace the lowest when full); holding an element card adds its spells (altar 350 ‰ chance), rune affinity ×2 weight; runner on 12 s cooldowns, densest-pack aim; Frost Nova, Fireball, Sky Strike Lv 1–5 numbers (Lv 5 extras in O11); HUD squares with sweep and flash. Damage ≈ 60 a cast from the 15 % rule (orbs ≈ 33.2 DPS) | 7647a519, 50dc7916 |
| O11 | The other 12 spells (SpellRoster, SpellZones) and the Lv 5 extras for O10's three; strings en+es; pack effects per spell (PD-13; Spitter Vine's body is a poison bubble, no plant in the packs). Lv 1 ≈ 60 a 12 s cast; Lv 5 2.25–2.95 × Lv 1 (starting values for O12) | d23ab05d |
| O9b | No ring on critters; `Solids.blocks()` distance pre-check (ai.plan 1.85 → 0.58 ms), Codex scan stops once a kind is unlocked; `alive_cap` 120 → 50. Idle probe (owner's PC, tasklist showed only the probe): 50 alive `avg=6.37 ms (157.1 fps) … 1%-low=105.6 fps`, `avg=6.43 ms (155.4 fps)`; 120 alive `avg=14.03 ms (71.3 fps)`. 60 held 144 in 2 of 4 clean runs. A clean run on the final SHA (85d033e5) was not possible (other Godot runs started) | 85d033e5 |
| VX | PD-13: Frost Nova, Fireball, Sky Strike, the Laser lance (the element's pack laser on one tube through the sim's points) and the quake pillars' rings, pulse and shatter now use pack effects; the Shade and the critter spark needed nothing | 467c45b0 |
| O9c | Critters batched: one MultiMesh per kind (`CritterCrowd`), no node per critter; a critter fast path in the sim (`CritterAi`, same rules, critters last in each phase). `alive_cap` 50 → 120. Idle probe (owner's PC, tasklist: no other Godot): 120 alive `avg=6.21 ms (161.1 fps) … 1%-low=121.2 fps`, confirm `avg=6.20 ms (161.4 fps) … 1%-low=120.8 fps`; 90 `176.4 fps`, 1 % low 136.3; 60 `190.2 fps`. Lost for critters: flinch, hit-stop pose, status rings | f21aa5e4 |
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
- 2026-11-07: O5 and O4b merged. O5 vs O4 conflicted in `damage.gd` (both scale boss hits; `_blocked`: O4 dropped the
  Shade's dark, O5 added the resting twin; kept both) and `boss_bar.gd` (both constants kept). On the merge: the
  Gatekeeper, Shade, Twins, boss-challenge, readable-cause, health-bar and boss content tests `Tests 130, Passing Tests
  130`; after O4b `Tests 48, Passing Tests 48`. Owner: Crossfire stays unshielded; resting twin and 3000 HP approved.
- 2026-11-07: seams at b9824eef (O1c + O4): `Tests 642, Passing Tests 642, Asserts 76449, Time 1325.41s`, all passed.
  Seams at 73b9765c (+ O5, O4b): `Tests 642, Passing Tests 641, Failing Tests 1`: `tests/unit/sim/test_boss_pace.gd`
  `test_a_big_attack_is_followed_by_a_still_punish_window` `[17] expected to equal [15]` (O5's Charge and Ground Slam
  are big attacks; O5 updated the content copy, not this one). Count raised on purpose to 17; that file alone: `Tests 5,
  Passing Tests 5`, `---- All tests passed! ----`. O9 (critters, surges) and O10 (spells) building.
- 2026-11-07: O9 merged clean; O10 merged (`strings.csv` both-sides additions kept; translations rebuilt; on the merge:
  locale coverage, spells, surges, world snapshot, rewards `Tests 71, Passing Tests 71`). Owner on the surge miss:
  optimise first, then cap; no team ring on critters (O9b).
- 2026-11-07: seams at 00d3f4e6 (+ O9, O10): `Tests 644, Passing Tests 643, Failing Tests 1`:
  `test_save_lab_loadout.gd` `ARRAY(["spell_tables", "spell_rules"]) != ARRAY([])` (O10 set them in FloorPlan, not in
  SaveLab). SaveLab now sets both; that file + test_spells + e2e old_save: `Tests 16, Passing Tests 16`. Pushed.
- 2026-11-07: O11, O9b, VX merged. Seams at 75b3eb41: `Scripts 111, Tests 644, Passing Tests 644, Asserts 79072, Time
  1294.66s`, `---- All tests passed! ----`, `check_gut_log: ok (644 passing, minimum 1)`. Pushed. O9c (batched
  critters) building.
- 2026-11-07: seams at 5b1d08ca (+ O9c): `Scripts 111, Tests 644, Passing Tests 644, Asserts 79098, Time 1272.864s`,
  `---- All tests passed! ----`, `check_gut_log: ok (644 passing, minimum 1)`. Pushed.
