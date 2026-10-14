# v0.8.0 Step FB2: the Prism, the final boss's second body (evidence)

Owner O17 (2026-10-14, verbatim in [`../FINAL_BOSS.md`](../FINAL_BOSS.md)): "the second phase is the one that doesn't
have big arms and that would be a ranged fight … we would have rays that go in a cross and turn with her in the middle
around the room so you have to move away … a lot of uh, small balls like we did with other bosses … quick, fast attacks
that you also have to dodge". G1 FINAL_BOSS row F5 ("Approve all") and the owner's F7 pick "Phase-by-phase mix": "the
Prism is a skill phase: hittable only in short windows between beam rotations, and her HP is set from your measured
damage per second so she always lasts about 60 s however strong you are" (2026-10-14).

Build: branch `v080-fb2` from `5bd7616`. Every command below ran on that branch's working tree before the
`v0.8.0 Step FB2` commit (its SHA is in the hand-off report, not here). Machine: a shared cloud container, Godot
4.7.2.stable; shots on llvmpipe (software Vulkan) under xvfb, not the owner's hardware. The shared disk was full when
the step began (1.3 MB free); the import waited until space came back.

## What was built

| Row | As built | Starting values (data; F10 Bosses page) |
|---|---|---|
| F5, the body | **The Prism** floats: she glides back to the fight's centre (where the first body rose) at 1.5 m/s and stays there; she never pursues. Six shards orbit her (the sim's points that fire) | `data/final_boss/prism.tres`: radius 1.5 m, 6 shards 2.3 m out, turning 50°/s |
| F5, **the Cross** | A new move, `cross` (`BossPrism`). Four beams in a plus from her edge to the walls (stopped by walls). Through the 1.0 s spin-up thin aim lines show where they will open, re-aimed every tick so you stand midway between two arms (45° off each): it never opens on you. Then they turn a quarter turn every 2.4 s at full HP, down to 1.2 s at no HP (set as each spin-up begins: faster as she weakens), reversing every 3.0 s, for 5.0 s; each Cross turns the other way from the last. A beam burns 14 once per 0.5 s | three Crosses (`cross_ring`, `cross_spiral`, `cross_flower`), each: 4 arms, 40 m, 0.9 m wide, quarter 2.4 → 1.2 s, reverse 3.0 s, spin 5.0 s, window 2.5 s, burn 0.5 s, 14 damage |
| F5, **orbs** | While the beams turn, every 1.6 s a volley from the next shard, aimed at you: dense slow **rings** (32 orbs, 4 gaps of 3), **spirals** (5 arms) and **flowers** (6 petals) in her own look (`crown_orb`: deep red crystal gems), woven through the beams. The pattern engine's fairness holds (no orb spawns on you or in a wall; its caps) | `data/bullet_patterns/prism_crown_{ring,spiral,flower}.tres`: 2.6–2.8 m/s, 0.2 m, 20 m |
| F5, **fast shots** | Every 1.1 s, through the spin and the window, a shard locks a **0.4 s aim line** at where you stand, then a fast bolt (`crown_bolt`, a long crystal spear) flies down it: it doesn't track, you sidestep. None fires while you stand on its shard | `prism_bolt` (a `bolt_fan`): 22 m/s, 0.22 m, 32 m, 12 damage, lock 0.4 s |
| F5 + F7, **shield and window** | Shielded through the spin-up and the spin (hits spark off); then the beams go out for a **2.5 s window** with the shield down (a gold ring pulses round her feet): the only time she can be hurt. The next Cross follows the window | — |
| F7, **HP from your DPS** | The fight measures your damage per second (below); as she rises her HP is set from it, so at your measured DPS in every window she lasts about 60 s however strong you are. Loops and the hidden catch-up don't change her HP (their damage scaling still applies). Her stagger meter is 100,000 (a stagger would open her outside a window) | `hp_from_dps`, measured 20 s (at least 5), target 60 s, 600..250,000 HP, own HP 1,400 (scaled as the floor's) when under 5 s were measured |
| F8 (part) | Deaths named, en + es: "The Prism's turning Cross burned you." (`CAUSE_PRISM_BEAM`), "The Prism's orbs caught you between the beams." (`CAUSE_PRISM_ORBS`), "A fast bolt from the Prism's shards struck you." (`CAUSE_PRISM_BOLT`). Her Codex line (`BOSS_PRISM_DESC`) rewritten for the real fight | — |
| F9 (part) | The Cross opens on the laser cue (as the Gaze) | — |

### The HP formula (owner F7)

The meter (`FinalFight`): a ring of 60 one-second buckets of the damage the player deals (`Damage._apply`: the hit's
damage before the HP and phase-gate clamps; any target but the player; damage over time included) while the fight is
measured: the fight not won, the player alive, the body fighting neither rising, gated nor shattering, and not itself
a body whose HP comes from the meter. In the real fight that is the Colossus's fight (the shatter and the Prism's own
fight aren't counted). As the Prism rises (`FinalBoss.dps_hp_of`):

```
n   = min(20, seconds measured)                     (dps_measure_seconds)
dps = damage of the last n seconds / n
hp  = dps × 60 s × window share                     (dps_target_seconds; integer maths)
    window share = Σ window / Σ (windup + active + recovery + cooldown) over her Crosses = 2.5 / 8.5 = 0.294
hp  = clamp(hp, 600, 250000)                        (dps_hp_min, dps_hp_max)
if n < 5: hp = clamp(her own hp, 600, 250000)       (dps_min_measured_seconds: a fight jumped straight to her)
```

So `hp = 17.64 × dps`: 100 dps → 1,764 HP (the test's case); the floor 600 is reached under 34 dps, the ceiling
250,000 over ~14,170 dps. The meter measures your fighting DPS against the Colossus (dodging included); in her windows
you can hit more often than that, so she will usually fall sooner than 60 s of fight — a starting value (F10), for the
owner's playtest.

**Read for the owner:** the owner's F7 line says "she always lasts about 60 s"; the lead's brief for FB2 says "about
60 s of windows". These differ by the window share (60 s of windows at 2.5 s per 8.5 s cycle would be ~204 s of
fight). Built as the owner's written line (rank 1): about 60 s of fight. One number (`dps_target_seconds`) moves it;
**OWNER ONLY** to confirm which was meant.

### Presentation (reads only)

- **`PrismViews`** (new, in `WorldViewRoot`): the spin-up's four thin aim lines brightening; the four beams (a hot core
  and a glow cylinder with the Gaze's scrolling beam shader, a burning strip on the floor, a flare and a light where
  each strikes the wall); the window's gold ring; a bolt's thin red aim line in the air through its 0.4 s; a flash and
  a light at the shard that fires.
- **Her shards** (`BossRig._prism`): the owner's mesh has 21 connected pieces; the biggest is the body, its centre the
  orbit's axis (a `core` bone); every piece at least 0.2 of her height off that axis is a shard with its own bone (15
  of them), the crystals hugging the body stay with it. `PrismAvatar` orbits them with the sim's shard ring (its first
  shard's angle each tick, carried on between ticks), turns each on itself (faster with the clips' "spin"), drifts them
  wider in the window, and swells the one nearest the sim shard that fires.
- **Clips (`PrismClips`, placeholders the owner's animations replace by name):** idle float, walk glide, `cross` (the
  spin-up: rising and opening, the shards racing; the spin aloft; the window: sagging open), `cast` (a shard firing),
  `shielded`, `flinch` (a hit), `stagger`, `roar`, `rise` (from the Colossus's shards), `death`, `shatter`, and
  `bolt_fan` (her lone bolt when the dev panel starts it alone).
- **Looks:** `crown_orb` (deep red crystal gems, faceted) and `crown_bolt` (long white-hot crystal spears, a long red
  streak), redder and darker than the Hive Lens's magenta prism orbs.

### Old saves

`FinalFight.home` and the meter (`dps_secs`, `dps_head`, `dps_closed`, `dps_acc`, `dps_t`) are in
`WorldSnapshot.ADDED_SINCE_V05`: an FB1 save mid-phase-2 restores with the arena's centre and a fresh meter (test
below). Her HP is the actor's, saved as it was: an FB1 save taken at her start (FB1 saves at each body's start) keeps
the stand-in's HP and resumes with the new fight (the stand-in's attack indices are never mid-attack at a body's
start).

### Sim and content

New: `src/sim/ai/boss_prism.gd`, `src/application/final_body_compiler.gd`. Changed: `BossAttackTable` (`CROSS`
appended; `fast_quarter_ticks`, `spin_ticks`, `window_ticks`, `bolt_attack`, `bolt_every_ticks`), `BossTable` (the
DPS HP, the float, the shards), `BossAi` (windup, lock, active, move, resolve, telegraph), `BossDodge.shielded` (the
window), `FinalBoss` (home, the meter, the HP at the rise), `FinalFight`, `Damage._apply` (the meter's hook),
`WorldReader` (`boss_cross`, `boss_shards`, `final_dps`, `MOVE_CROSS`), `WorldSnapshot`; content: `BossSchemas`
(`cross`), `BossAttackDefinition` (its checks), `FinalBossDefinition` (the DPS HP and shards, their checks),
`PatternCompiler`. Rules in SIM_CONTRACTS §10g, params in CONTENT_SCHEMA §4. `FinalStubClips.prism()` is no longer
used (left in place: FB3 edits that file).

## Tests (raw)

Lint, on the final tree:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
911 files would be left unchanged
Success: no problems found
$ bash scripts/ci/gut_shard.sh --check
gut_shard: ok (323 test files in 6 shards)
```

Each batch ran as
`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gtest=a,b,… | -gdir=…> -gexit` (GUT totals as
printed).

1. Sim: `test_prism, test_final_boss, test_colossus, test_boss_signatures, test_boss_signatures_2, test_world_snapshot,
   test_bosses, test_bosses_2, test_bullet_patterns, test_readable_cause, test_boss_gates, test_damage,
   test_state_hasher, test_ascension` (tests/unit/sim):
   ```
   Scripts              14
   Tests               195
   Passing Tests       194
   Failing Tests         1
   Asserts           102222/103846
   Time              543.386s
   ```
   The one: `test_world_snapshot.gd` `test_every_hashed_store_is_snapshotted`, **not FB2's**:
   ```
   [Failed]:  World.shop_table.rooms[starfall] is a ShopRoomTable: add it to WorldSnapshot.STATE_CLASSES or LOADOUT_CLASSES
   [Failed]:  World.shop_table.rooms[starfall].layout is a RoomLayoutTable: add it to WorldSnapshot.STATE_CLASSES or LOADOUT_CLASSES
   … (the same for every group and piece of the shop rooms' layouts)
   ```
   Reproduced at the base `5bd7616` (this worktree switched to it detached, imported, then
   `-gtest=res://tests/unit/sim/test_world_snapshot.gd -gunit_test_name=test_every_hashed_store_is_snapshotted`):
   ```
   Scripts               1
   Tests                 1
   Passing Tests      none
   Failing Tests         1
   ```
   (SR's shop-room tables, reachable from `World.shop_table`, are in neither class list. Left for the lead: FB2 doesn't
   touch the shop.)
2. `tests/content`, `tests/arch`, `tests/golden`, `tests/unit/application` (the saves, the final achievements),
   `tests/unit/debug`:
   ```
   Scripts              45
   Tests               243
   Passing Tests       243
   Asserts           20685
   Time              84.127s
   ```
3. Presentation: `test_prism_views, test_final_boss_views, test_boss_signature_views, test_boss_signature_views_2,
   test_attack_visuals, test_attack_visuals_2, test_boss_animations, test_boss_rigs, test_boss_models,
   test_boss_models_2, test_audio_director, test_enemy_fireball_views, test_boss_fights_2_views, test_boss_views`.
   First run `Tests 133`, `Passing Tests 132`, `Failing Tests 1`:
   ```
   [Failed]:  [0.12604044377804] expected to be > than [0.15]:  spear_ember and crown_orb read apart
   ```
   (`test_boss_fights_2_views.gd`: the orbs' first core colour, #FF5A6E, was too near the Warlord's spear embers.) Now
   #F02848 (at least 0.35 from every other look's core); the whole batch again on the final tree:
   ```
   Scripts              14
   Tests               133
   Passing Tests       133
   Asserts           39766
   Time              129.509s
   ```
4. E2e: `test_e2e_prism, test_e2e_final_boss, test_e2e_playground, test_e2e_bosses_2, test_e2e_boss_signatures_2,
   test_e2e_old_save, test_e2e_saves, test_e2e_achievements, test_e2e_codex, test_e2e_dev_master_panel` (run before
   the colour change above, a view constant no e2e reads):
   ```
   Scripts              10
   Tests                17
   Passing Tests        17
   Asserts             467
   Time              135.864s
   ```

Failures on the way (the new files' first runs, fixed before the batches above): the arms' "midway" check was exact
(512) but the player moves a tick after the re-aim (513–514; the check allows a tick's walk); the burn test counted
the orbs' and bolts' hits too (now only the beams' area hits, one per burn window); the flower's petal gaps were 1.0 m
at 4 m out, under the hero's width + 0.3 m (its `petal_cut_permille` 400 → 550 in data: 1.7 m); the meter test assumed
the raw 30 a hit (the build's damage stats scale it; it now sums the DAMAGE events dealt); the FB1-save test's world
had counted one tick in the meter (the Colossus's first acting tick, which an FB1 world never counts; zeroed as such).

New tests:
- `tests/unit/sim/test_prism.gd` (24): her data; she floats home and stays; the Cross never opens on the player (8
  places, walking through the spin-up) and keeps them midway; a quarter per quarter, reversing, at most a step a tick;
  each Cross the other way; the speed-up from her HP; the walls stop the beams; one burn per window; shielded through
  the spin-up and spin, open in the window, shielded again; open ~29 % of two whole cycles; the orbs leave her shards,
  never on the player, with their line; every orb pattern's every wave leaves a gap the hero fits; a bolt's line shows
  24 ticks, then it flies down the locked line at 22 m/s with its line; no bolt fires on the player; the HP formula
  (100 dps → 1,764), its clamps (600, 250,000, her own under 5 s), the same meter → the same HP; the meter counts the
  Colossus's fight as dealt, not the shatter, the rise or her own fight; the three death lines and a beam kill;
  determinism over 900 ticks; a snapshot mid-Cross round trip (400 ticks on); an FB1 save mid-phase-2 (the FB2 fields
  erased) restores with the same hash and plays on the same.
- `tests/unit/presentation/test_prism_views.gd` (8): her shards are their own pieces (15 bones); they orbit with the
  sim's ring; the shard that fires flares; the Cross drawn where the sim's beams are (aim lines, beams, the window's
  ring); a bolt's aim line exactly while the sim aims; reduced motion keeps it; her clips; her looks.
- `tests/unit/debug/test_dev_prism.gd` (1): her numbers are F10 rows with their values.
- `tests/content/test_boss_validation.gd`: + `test_the_prism_cross_and_dps_hp_are_checked` (1).
- `tests/e2e/test_e2e_prism.gd` (1): main.tscn, real input only: the Playground (the Gun), F1, God, "Phase 2": the
  Prism; with the Gun's fire held on her through a whole Cross: four aim lines, four beams, a bolt's aim line, no HP
  lost while the Cross turns, HP lost in the window, the hero standing.

Not run locally: the full suite (CLAUDE.md: once per version, on GitHub); bot balance sims (not asked).

**Goldens:** `tests/golden` passed unchanged (batch 2). No golden fixture holds the final fight; the new `FinalFight`
fields hash only where a fight is (with it).

## Shots

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss_2.gd -- <n>   (n = 1..6, one at a time)
final_boss_2: res://build/shots/v0.8.0/fb2/1_prism_floating_shards_orbiting.jpg (tick 210)
final_boss_2: res://build/shots/v0.8.0/fb2/2_cross_spin_up_aim_lines.jpg (tick 162)
final_boss_2: res://build/shots/v0.8.0/fb2/3_cross_turning.jpg (tick 276)
final_boss_2: res://build/shots/v0.8.0/fb2/4_orbs_between_the_beams.jpg (tick 330)
final_boss_2: res://build/shots/v0.8.0/fb2/5_fast_bolt_aim_line.jpg (tick 261)
final_boss_2: res://build/shots/v0.8.0/fb2/6_window_beams_out_strike_now.jpg (tick 503)
```
Each exited 0, rendered on the final tree; copied to [`fb_shots/`](fb_shots/) as `fb2_<n>_<label>.jpg` (1280×720, the
boss bar on top). The world is the final arena as the game builds it (`FinalLab`), the fight jumped to the Prism (as
the dev panel and the Playground do); the hero is held still and invulnerable; her own picks are off and each shot
starts the Cross it shows (ring, spiral or flower):
- [`fb2_1`](fb_shots/fb2_1_prism_floating_shards_orbiting.jpg): her float at the centre, the shards round her.
- [`fb2_2`](fb_shots/fb2_2_cross_spin_up_aim_lines.jpg): the spin-up: four thin aim lines, the hero midway between two.
- [`fb2_3`](fb_shots/fb2_3_cross_turning.jpg): the Cross turning, each beam striking the wall; the shield round her; a
  bolt in flight.
- [`fb2_4`](fb_shots/fb2_4_orbs_between_the_beams.jpg): a spiral of orbs from a shard woven through the beams; a bolt's
  aim line.
- [`fb2_5`](fb_shots/fb2_5_fast_bolt_aim_line.jpg): a fast bolt's aim line from a shard toward the hero.
- [`fb2_6`](fb_shots/fb2_6_window_beams_out_strike_now.jpg): the window: the beams out, the gold ring at her feet, the
  last volleys' orbs flying.

A first render of shot 3 caught a beam crossing the held hero (the hero is invulnerable in renders); the shot now waits
for a tick with the hero between two arms. All six were rendered again after the orbs' colour change below.

## Owner only

- The fight's feel, pace and difficulty, the beams' speed, the windows' length, her look and clips: **OWNER ONLY**.
- Which "60 s" F7 meant (60 s of fight, as built, or 60 s of windows): **OWNER ONLY**.
- Frame rate on the owner's hardware with her orbs, beams and the arena: **OWNER ONLY** (not measured here).
