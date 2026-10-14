# v0.8.0 Step BS2: the Hive Lens's Gaze, the Siege Engine's ricochet shells, the Foundry's lava (evidence)

Owner O5 (2026-10-14, verbatim in [`../PLAN.md`](../PLAN.md)): "the fight seem, feels pretty similar … Something
that actually stands out for each boss." G1 [`../BOSS_SIGNATURES.md`](../BOSS_SIGNATURES.md) approved 2026-10-14
("boss OK": rows S1–S6 as proposed). BS1 built S1–S3 ([`BOSS_SIGNATURES_1.md`](BOSS_SIGNATURES_1.md)); this step
builds S4–S6.

Build: branch `v080-bs2` from `94c691e`. Every command below ran on that branch's working tree before the
`v0.8.0 Step BS2` commit (its SHA is in the hand-off report, not here). Machine: a shared cloud container, Godot
4.7.2.stable; shots on llvmpipe (software Vulkan) under xvfb, not the owner's hardware. The machine restarted once
mid-step (background runs killed); every run listed below was run again after it, to its end.

## What was built

| Row | Boss | Mechanic, as built | Trimmed | Starting values (data, F10 Bosses page) |
|---|---|---|---|---|
| S4 | Hive Lens | **The Gaze**, a new `gaze` move (`BossGaze`). Through its windup the start angle is re-aimed every tick straight away from the player (it never starts on you); the eye brightens and a thin aim line shows. Then a beam from its eye's edge turns a quarter turn every `quarter_seconds`, the way the ai stream picked, reversing every `reverse_seconds` (an integer triangle wave), stopped by walls (`clear_run`), burning a player it touches once per `burn_seconds`; its orbs (the Petal Bloom) fire again every `orb_every_seconds`. The boss faces along the beam | Glare Ring (+ fast) | 0.8 s windup, 12.0 s long, a quarter turn every 2.0 s, reversing every 8.0 s (one whole turn each way), 30 m, 0.9 m wide, 14 dmg every 0.5 s, orbs every 3.0 s; phase 3 `gaze_fast`: 1.6 s / 6.4 s / 11.2 s, orbs every 2.6 s (Petal Bloom fast) |
| S5 | Siege Engine | **Ricochet shells** (`BossRicochet`): the Turret Cross's embers bounce off a wall once (the existing Ricochet Core bounce: reflected on the hit face's normal, an exact flip for axis-aligned walls); from phase 3 the turrets its `deploy` drops shoot shots that bounce once. Fair: a hostile shot does not bounce when its way back would touch the player within 0.5 s (30 ticks, a swept circle); it breaks on the wall | Turret Cross Reversing; phase 3 now opens with `deploy` (its turrets ricochet) and runs `turret_cross_fast` | `bounces` 1 (both crosses), embers' range 26 m (was 20, so they come back), `bounce_phase` 3 |
| S6 | Foundry | **The floor is lava** (`BossLava`). Molten Flood lanes stay molten from the tick after they stood, cut by fords at the boss's x and where the way from the room's centre to its door crosses each lane; laid only if a flood over the flow field's cells (keeping the hero's radius off all molten floor) still joins the boss to the player and to the door; enemies path round it (`NavField.set_extra`). Phase 3 opens with a new `melt` move: its windup is a roar while the outer ring glows; then the floor beyond the room's inscribed radius − `ring_m` melts for good and creeps in `step_m` every `step_seconds` (each step glowing `warn_seconds` first), never under `min_radius_m`; a bridge `ford_m` wide to the door stays cool; the Foundry keeps to the cool ground | Furnace Waves' fast ring | lava 5.0 s, 6 dmg every 0.5 s, fords 2.0 m; melt: windup 2.0 s, the outer 4.0 m, 2.0 m closer every 8.0 s, warned 2.0 s, never under 7.0 m, 8 dmg every 0.5 s, a 2.0 m bridge |

**Picks made here (documented, for the owner to change in F10):**
- The Gaze is **not shielded**: the G1 row doesn't ask for it, the Prism Spiral stays the shielded signature, and the
  open eye during a 12 s sweep is the time to hit it (its recovery opens the weak point).
- The meltdown is a **phase-3 entry attack** (`melt`), so its announcement is a real telegraph (the 2 s roar and the
  glowing ring) on top of the phase gate's roar. The first melt depth is a ring of the room (`ring_m`), not a fixed
  radius: the floor-3 boss rooms are 48–55 m across, where a fixed 8 m radius would have melted almost all of it.
- The closing-arena band (v0.3.0 BX) still runs for the Foundry as for every boss; the melt's minimum (7 m round the
  centre) and the band's safe half (5 m) overlap; both are starting values.
- A turret's ricochet death names "A turret's shot bounced off the wall into you." through the live boss's deploy
  attack (`BossAi.cause_key` falls back to the live boss's table for a late cause).

**Sim (pure; no trig, the ai stream only for the gaze's turn way):** new `src/sim/ai/boss_gaze.gd`,
`boss_ricochet.gd`, `boss_lava.gd`; `BossAttackTable` (moves `GAZE`, `MELT` appended; the new numbers);
`BossAi` (lock, windup, active, resolve, telegraph `"ground": false`, the Foundry's `keep_on_ground`, the turret
ricochet's recap); `BossDodge.resolve_pattern` arms the bounces; `EnemyAi` arms a turret's shot; `World`
(`set_pending_bounces`, the bounce fairness and late cause in `_projectile_hits`); `NavField` (`set_extra` takes the
melt shapes, `reach` for the fairness flood); `BossSignatures` (`set_nav_extra` for pillars + lava + melts,
`has_extra`, ticks `BossLava`); `BossStore` (`lava_*`, `melt_*`, `burn_cd`, hashed only while molten floor is down);
`WorldSnapshot` (`ADDED_SINCE_V05` lists them; restore sets the field's extra cells again). Content: `BossSchemas`
(`gaze`, `melt`, the optional params), `BossAttackDefinition` validation, `PatternCompiler`. Rules in SIM_CONTRACTS
§10f; params in CONTENT_SCHEMA §4.

**Readable cause (en + es):** `CAUSE_HIVE_GAZE`, `CAUSE_HIVE_GAZE_ORBS`, `CAUSE_SIEGE_RICOCHET`,
`CAUSE_SIEGE_TURRET_RICOCHET`, `CAUSE_FOUNDRY_LAVA`, `CAUSE_FOUNDRY_MELT`; the three bosses' `*_DESC` lines (Codex)
rewritten. The test-side checker `tests/support/readable_cause.gd` now reads a projectile's carried cause (late
parts) and books molten-floor DoT to the lava's or the melt's line (as it books the arena band).

**Presentation (reads only):** `BossSignatureViews` (in it, not the telegraph or VFX drawers): the Gaze (eye flare and
light brightening, a thin aim line, then a real beam: core + glow cylinders with a scrolling noise shader, a burning
floor strip, an impact flare and light where a wall stops it, scorch marks fading over 2.5 s), ricochet spark bursts,
lava quads (welling up, churning, crusting over their last second), the meltdown plane (molten beyond the radius, the
bridge left cool, the next ring pulsing while warned). Shaders in the new `boss_signature_shaders.gd`. Clips:
Hive Lens `gaze` (charge, then a long steady stare), Siege Engine `pattern_shielded` (braced low for the ricochet
volley, turning to watch the embers come back), Foundry `melt` (rearing roar, slam and pour). The procedural looks
pose `gaze` as the beam and `melt` as the pour. Audio: the gaze uses the laser cue, the melt the floor burst.

## Tests (raw)

Lint, on the final tree:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
858 files would be left unchanged
Success: no problems found
```

New tests:
- `tests/unit/sim/test_boss_signatures_2.gd` (22): the gaze starts straight away and keeps away through its windup
  (never on you, no hit as it opens); turns a quarter every quarter and reverses (and at most a step a tick); burns
  what it touches at most once per burn, and its death line; a wall stops it (and shields you behind it); its orbs
  fly while it turns and carry their line; gaze deterministic + snapshot round trip. A shell bounces once, reflected
  exactly (`(-vx, vy)` off the +x face), and the next wall breaks it; a ricochet that would come back on you within
  0.5 s breaks (1 m from the wall) and one that wouldn't bounces (6 m); the Turret Cross's embers all carry a bounce
  and come back off the walls; phase-3 turrets ricochet (phase index 1: no, 2: yes) and both ricochet death lines;
  a bounced shell kills with its line; ricochets deterministic + snapshot. The flood leaves lava inside its lanes for
  exactly 300 ticks with a ford at the boss's x, then cools and the field reopens; lava burns at most once per 0.5 s
  for `lava_damage`, the cool band doesn't, and its death line; lava cells are off the flow field; on a real floor-3
  boss room, from four spots and both floods, an independent 0.2 m grid flood finds a lava-free way from the boss to
  the player and to the door; lava that would cut the room is refused, with a ford it isn't; the meltdown glows
  through its roar, melts, and shrinks 12 → 10 → 8 → 7 → 7 → 7 m (room half 16), burns outside, not inside, is off the
  field, keeps the Foundry inside, and its death line; on a real floor, phase 3 opens with the meltdown round the
  room's centre with a cool bridge to the door; lava + melt deterministic + snapshot; an older save (the BS2 fields
  erased) restores mid-fight with the same hash and its next flood leaves lava; the trimmed moves are gone.
- `tests/unit/presentation/test_boss_signature_views_2.gd` (5): the aim line then the beam ending where the sim's does,
  the impact flare and light, scorch marks, gone after; a ricochet's spark burst, fading; a lava quad per sim piece,
  gone with them; the meltdown glows then melts at the sim's radius; the three new clips.
- `tests/unit/debug/test_dev_boss_signatures.gd` (1): every new number is a row of the F10 Bosses page with its value.
- `tests/content/test_boss_validation.gd`: + `test_the_signature_params_of_part_2_are_checked` (1).
- `tests/e2e/test_e2e_boss_signatures_2.gd` (4): main.tscn, real input only: the Gaze's beam drawn; an ember's bounce
  throws sparks; the Foundry's lava drawn; F10 → the Foundry's phase-2/3 thresholds typed to 1000 → Restart floor →
  summon: the ring glows through the roar, then melts.

Changed tests (the fights changed on purpose): `test_boss_fights_2.gd` (the Hive Lens's phase script with the gaze;
the Glare Ring's own tests removed), `test_boss_fights_3.gd` (the Siege Engine's and the Foundry's phase scripts, the
bounces), `tests/support/readable_cause.gd` (above). `scripts/shots/boss_fights.gd` lost its Glare Ring row.

`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gtest=a,b,… | -gdir=… -ginclude_subdirs> -gexit`
on a shared machine; GUT totals as printed, final tree:

| Run | Raw totals |
|---|---|
| sim by name: `test_boss_signatures`, `_2`, `test_bosses`, `_2`, `test_boss_fights`, `_2`, `_3`, `test_boss_gates`, `test_boss_pressure`, `test_boss_challenge`, `test_bullet_patterns`, `test_boss_markers`, `test_readable_cause`, `test_enemy_fireballs`, `test_after_boss`, `test_world_snapshot`, `test_enemy_ground_marks`, `test_rewards`, `test_horde`, `test_utility` (flow field), `test_items`, `test_combos` (bounces) | `Scripts 22`, `Tests 289`, `Passing Tests 289` (879 s) |
| `tests/content` | `Scripts 24`, `Tests 121`, `Passing Tests 121` |
| `tests/arch` | `Scripts 2`, `Tests 4`, `Passing Tests 4` |
| `tests/golden` | `Scripts 1`, `Tests 2`, `Passing Tests 2` |
| presentation boss files (18: `test_attack_visuals`, `test_audio_director`, `test_boss_animations`, `test_boss_challenge_parity`, `test_boss_challenge_views`, `test_boss_fight_views`, `_3`, `test_boss_fights_2_views`, `test_boss_models`, `_2`, `test_boss_rigs`, `test_boss_signature_views`, `_2`, `test_boss_telegraph_parity`, `test_boss_views`, `test_bosses_2_views`, `test_enemy_fireball_views`, `test_telegraph_parity`) | `Scripts 18`, `Tests 150`, `Passing Tests 150` |
| application saves (`test_old_saves`, `test_ascension_saves`, `test_run_saves`) | `Scripts 3`, `Tests 20`, `Passing Tests 20` |
| `tests/unit/debug` | `Scripts 3`, `Tests 12`, `Passing Tests 12` |
| e2e (16: `test_e2e_boss_signatures`, `_2`, `test_e2e_stone_spikes`, `test_e2e_after_boss`, `test_e2e_boss_challenge`, `test_e2e_boss_dodge`, `_2`, `_3`, `test_e2e_bosses`, `_2`, `test_e2e_playground`, `test_e2e_dev_panel`, `test_e2e_dev_master_panel`, `test_e2e_dev_live_balance`, `test_e2e_old_save`, `test_e2e_saves`) | `Scripts 16`, `Tests 26`, `Passing Tests 26` |

Failures on the way, raw, and what was done:
- First run of the new sim file: `Tests 22`, `Passing Tests 17`, `Failing Tests 5`: `[0] expected to be > than [0]:
  some have bounced` (the player was hit, the hit-stop held the clock: made untouchable), `no run seed in 1..79 has
  the Foundry on floor 3` ×2 (a later floor opens with its arrival; the helper now waits for the door to seal),
  `[0] expected to be > than [0]:  lava down` and `… and its next flood leaves lava` (the test stepped a fixed tick
  count; a hit-stop on the player held the flood: it now steps until the attack ends). The probe of a real floor-3
  room also showed rooms 48–55 m across, so the melt's first radius became the room's inscribed radius − a ring.
  Re-run: `Tests 22`, `Passing Tests 22`.
- First sim batch (cut short by the machine restart, partial output): `test_readable_cause.gd` `foundry: unreadable
  hit: {"attack":-1,"cause":"","owner_kind":20,"problems":"no recap cause",…,"tags":4,…}` ×3 (lava DoT, which the
  checker didn't know) and `["CAUSE_SIEGE_RICOCHET"] expected to equal ["CAUSE_SIEGE_CROSS"]:  floor 3: the recap
  names the killing hit` (the checker booked a projectile to its attack at birth, not its ricochet). Fixed in the
  checker (above); the full batch re-run is the row above.
- Shots: the first render timed out (`EXIT 124`, one frame a tick on llvmpipe) after 5 of 6 shots, and its aim line
  was hidden behind the eye; the script now runs 6 ticks a frame and the windup shot stands the player so the line
  runs toward the camera. The second and third renders exited 0.

The fight logs the boss tests print (bot fights, not the bot sims): `BOSSFIGHT| hive_lens MELEE ticks=2787
seconds=46.5`, `RANGED_NEAR ticks=4859 seconds=81.0`; `siege_engine MELEE ticks=3369 seconds=56.1`, `RANGED_NEAR
ticks=5405 seconds=90.1`; `foundry MELEE ticks=3494 seconds=58.2`, `RANGED_NEAR ticks=4324 seconds=72.1`;
`BO_CAUSE| foundry seed=9102 ticks=3600 hits=33 violations=0` (11 of them `CAUSE_FOUNDRY_LAVA`); `BO_CAUSE| hive_lens
seed=9100 ticks=3600 hits=10 violations=0`. Not a fight-length measure; NOT YET RUN: the bot sims.

**Goldens:** `tests/golden` passed unchanged. No golden fixture holds a boss fight; the new BossStore lists hash only
while molten floor is down; the bounces column was hashed already.

## Screenshots
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path .
--audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_signatures_2.gd` (exit 0), the real game view of a
real World (the Combat Lab stage, its interior set as the boss room), copied from `build/shots/v0.8.0/bs2/`:
- [`bs_shots/7_hive_gaze_windup_aim_line.jpg`](bs_shots/7_hive_gaze_windup_aim_line.jpg): the eye brightening and the
  thin aim line, aimed away from the player behind it.
- [`bs_shots/8_hive_gaze_beam_sweeping.jpg`](bs_shots/8_hive_gaze_beam_sweeping.jpg): the beam on an inner wall (flare
  and light), its scorch trail along the outer wall, the Petal Bloom orbs flying.
- [`bs_shots/9_siege_ricochet_embers_coming_back.jpg`](bs_shots/9_siege_ricochet_embers_coming_back.jpg): the cross's
  arms reaching the walls and running back along them.
- [`bs_shots/10_foundry_lava_left_by_the_flood.jpg`](bs_shots/10_foundry_lava_left_by_the_flood.jpg): the flood's
  lanes left as lava, a ford at the Foundry's x.
- [`bs_shots/11_foundry_meltdown_ring_glowing.jpg`](bs_shots/11_foundry_meltdown_ring_glowing.jpg): the roar: the outer
  ring glowing.
- [`bs_shots/12_foundry_outer_ring_melted.jpg`](bs_shots/12_foundry_outer_ring_melted.jpg): the ring melted (7 m round
  the centre on this 18 m stage) with fresh lava inside.

## Not measured / open
- OWNER ONLY: whether the three fights now stand out, and whether the gaze, the ricochets and the lava are fun.
- NOT YET RUN: the bot sims, the sim bench and hitch probe (the lava's fairness flood runs once per flood; a melt
  step re-marks the room's cells), the full suite (the lead's, on GitHub), `scripts/ci/seams.sh`.
- Starting values for F10: every number in the table above, the embers' 26 m range.
- The playground stage and the dev summon have no boss room: there the melt rings the Foundry's spot with a 24 m
  stand-in radius and no door bridge (the e2e uses the start floor's room; a real floor-3 room is in the sim tests).
