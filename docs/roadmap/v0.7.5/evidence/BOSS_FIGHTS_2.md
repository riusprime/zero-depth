# v0.7.5 Step BF2: the Brood Mother and the Hive Lens fight dodge-first (evidence)

Owner N15 (verbatim in [`../../../design/BOSS_FIGHTS.md`](../../../design/BOSS_FIGHTS.md); picks "About 1.5×",
"Track, then lock 0.8 s", "Shielded during big patterns"; "Approve all", 2026-10-13), built on BF1's engine
([`BOSS_FIGHTS_1.md`](BOSS_FIGHTS_1.md)). Branch `v075-bf2`, from `81a07b5`. The agent's readings are in PLAN
"BF2". The runs below are on the WIP commit `9196146` plus the working-tree edits that the final
`v0.7.5 Step BF2` commit holds (tests, docs, the screenshot plan and one test fixed on purpose; no sim or data change
after the runs named "final").

## What was built
- **Engine additions (sim, additive; BF1's tests stay green):**
  - `marks` + an optional `pattern_id` (a BURST): each circle is an egg's landing. While it is locked, its telegraph
    item carries `lob` (the view's egg flies onto it). As it strikes, `BossDodge.burst_mark` fires the pattern's
    waves from it, `egg_r` (half the circle) out, aimed at the player then. The pattern's aim offset puts the player
    in a gap, and BF1's fairness and caps apply. The attack stays active until the last egg's burst has fired
    (`PatternCompiler`).
  - `burrow` with `lock_seconds` (`BossDodge.tracked_burrow`): the eruption circle stays on the player's exact
    position while the boss tracks underground (BossStore point 0; the telegraph is a tracked `disc`). It then locks:
    the boss burrows to it and erupts there after `erupt_seconds`. An optional `pattern_id` (a RING) bursts from the
    eruption with its gap on the player (`burst_eruption`, `eruption_ticks`).
  - `BossSchemas.MOVES[move]["optional"]`: params a move may take (the validation still rejects any other key).
  - No new state is hashed: the boss points, the lock and the attack's clock.
- **The two fights (data)**, per the design table:

| Boss | Phase 1 (100 %) | Phase 2 (66 %, opens with) | Phase 3 (33 %, opens with) |
|---|---|---|---|
| Brood Mother | Egg Storm (3 tracked circles 0.45 s apart, each an egg bursting into an 8-point star; shielded), Web Spiral (2 arms, 80°/s, reversing at 1.5 s), Leap (tracked, locked 0.8 s), Burrow (tracked eruption, locked 0.8 s, a 14-glob ring with its gap on you), Brood (3 Hatchlings) | Egg Storm ×5 (two stars each), Web Spiral, Leap ×2, Burrow, Brood ×4 — opens with Egg Storm ×5 | Egg Storm ×5, Web Spiral fast (−110°/s, faster globs), Leap ×2, Burrow with two rings, Brood ×4, Pounce chain — opens with the fast Web Spiral |
| Hive Lens | Prism Spiral (3 arms, 70°/s, reversing halfway; the eye closed, shielded), Petal Bloom (a 5-petal flower, 3 blooms turned 36°), Glare Ring (3 rings of 20 with 2 gaps, turned 30°), Focus Beam (a line that tracks you, locks 0.8 s), Lens Flare (the close slam ring, kept), Dive (tracked, locked) | the same with the fast Glare Ring (4 rings, faster) — opens with the split (3 Lens Drones) | Prism Spiral fast (−95°/s, faster orbs; shielded), Petal Bloom fast (4 blooms), Glare Ring fast, Focus Beam ×3 lines, Lens Flare, Dive — opens with the fast Prism Spiral |

  HP: Brood Mother 1600 → 2000, Hive Lens 1650 → 2063 (×1.25 from v0.7.0's `a20850f`, 2062.5 rounded up). Gates
  66 / 33 % kept; `radius_m`, `arena_cells` and `legacy_arena_cells` as BF1 set them for N18. Punish: the Pounce chain
  (tracked leaps); the Focus Beam. Gap-closer: the Leap; the Dive.
- **Presentation:**
  - `FireballViews.LOOKS` gains `acid_glob` (`#C8FF6A` core, `#142A08` edge, a short `#6FA02A` trail, size 1.1)
    and `prism_orb` (`#FF78D0` core, `#3A0626` edge, a long `#C02A78` trail, size 0.9).
  - `BossShieldView` draws an egg (a pale shell glowing green) per locked Egg Storm circle, besides BF1's burst lob.
  - The Brood Mother's avatar poses the Egg Storm and the Web Spiral as its brood (the sac swells). The Hive Lens's
    avatar poses a pattern as its prism fan (the crown spins up) and the Focus Beam as its beam. Its eye closes
    through BM's `shielded` pose, which reads `WorldReader.boss_shielded`.
- **Strings (en + es):** `CAUSE_BROOD_EGGS`, `CAUSE_BROOD_WEB`, `CAUSE_HIVE_SPIRAL`, `CAUSE_HIVE_BLOOM`, and
  `BOSS_BROOD_MOTHER_DESC` / `BOSS_HIVE_LENS_DESC` rewritten for the new fights (the Codex text). `CAUSE_HIVE_SWEEP`
  and `CAUSE_HIVE_PRISM` are now unused and were left in place.

## Tests (raw)
Lint, on the final tree:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
783 files would be left unchanged
Success: no problems found
```
New tests:
- `tests/unit/sim/test_boss_fights_2.gd` (16):
  - both phase scripts and HP;
  - the egg circles track, then lock in turn, each with its egg in the air;
  - each egg bursts into an 8-point star from its circle, no glob straight at you, slow and green;
  - no glob spawns on you, and standing in the circle is hit;
  - shielded through the Egg Storm, open after;
  - Egg Storm determinism (two runs, one hash);
  - the Web Spiral reverses;
  - the Leap tracks exactly, then locks;
  - the Burrow's eruption tracks, locks and erupts a ring with you in its gap (stay: hit; moved after the lock:
    missed);
  - the Prism Spiral's 3 arms reverse halfway;
  - the eye is shielded through the spiral;
  - five petal gaps;
  - two Glare Ring gaps;
  - the Focus Beam tracks, then locks, and a step aside escapes;
  - the shots of each look are slow.
- `tests/unit/presentation/test_boss_fights_2_views.gd` (5): globs and orbs drawn in their looks; the looks read apart;
  an egg per locked circle; the Hive Lens's shielded pose from the sim; the avatars' move mapping.
- `tests/e2e/test_e2e_boss_dodge_2.gd` (1): through `main.tscn` with real input only. The dev panel summons the Brood
  Mother; a Leap's circle tracks the player and locks on where they stand; the stick walks out; she lands where it
  locked and misses; her acid globs are drawn.

Tests changed on purpose (the fights changed):
- `tests/unit/sim/test_boss_challenge.gd` "aimed attacks lead a moving player": the shipped leap is now locked and
  exact, which the test asserts. The lead rule is tested on the same leap with its lock set to 0 (a fixture).
- `tests/unit/presentation/test_boss_telegraph_parity.gd` "brood burrow erupts where it marked": "far: it falls
  short" became "far: the tracked eruption still finds you". The drawn circle is still the hit.

### Runs
Each run is `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gtest / -gdir ...> -gexit` on a
shared machine (three agents). The GUT totals as printed:

| Run | Tree | Raw totals |
|---|---|---|
| `tests/content` | `81a07b5` + BF2 code/data before tests | `Scripts 26`, `Tests 132`, `Passing Tests 132` |
| the 8 boss sim files (`test_bosses`, `_2`, `boss_challenge`, `boss_gates`, `boss_pressure`, `boss_fights`, `boss_markers`, `bullet_patterns`) | same | `Tests 99`, `Passing Tests 97`, `Failing Tests 2`: `test_aimed_attacks_lead_a_moving_player` (`expected to equal [2.1]`: the leap no longer leads, on purpose; fixed as above) and `test_the_shipped_patterns_each_leave_a_gap_the_hero_fits` (`[0.897…] expected to be >= than [0.9]: hive_petal_bloom wave 0`; petal cut raised 300 → 400 per mille, gap 2.15 m) |
| `test_boss_fights_2.gd` | `9196146` | first run `Tests 16`, `Passing 13`, `Failing 3`: a misnamed BossTable field in the test (`gap_close_attack`) and an off-by-one in the test's gap count. Fixed in the test; then `Tests 16`, `Passing Tests 16` |
| `tests/unit/presentation` (whole folder) | `9196146` | `Scripts 76`, `Tests 491`, `Passing Tests 490`, `Failing Tests 1`: `test_brood_burrow_erupts_where_it_marked` "far: it falls short" (changed on purpose, above) |
| `test_boss_telegraph_parity.gd` + `test_boss_fights_2_views.gd` | final | first `Tests 14`, `Passing 13` (the views test's `apply_state` fixture lacked `tick`), then `Scripts 2`, `Tests 14`, `Passing Tests 14` |
| e2e: `test_e2e_boss_dodge_2`, `test_e2e_boss_dodge`, `test_e2e_bosses`, `test_e2e_bosses_2`, `test_e2e_boss_challenge`, `test_e2e_after_boss` | final | `Scripts 6`, `Tests 8`, `Passing Tests 8` |
| `tests/content`, `tests/arch`, `tests/golden` | final | `Scripts 29`, `Tests 138`, `Passing Tests 138` |
| the 8 boss sim files + `test_boss_fights_2.gd` | final | `Scripts 9`, `Tests 115`, `Passing Tests 115` |
| `tests/unit/application`, `tests/unit/debug` | final | `Scripts 13`, `Tests 80`, `Passing Tests 80` |

`tests/golden` passed unchanged (no golden fixture changed). Not run by the agent:
- the rest of `tests/unit/sim`, including the every-card soak (it is in the lead's seams);
- the full suite (GitHub);
- the bot sims;
- the sim bench and the hitch probe.

## Screenshots
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path .
--audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_fights.gd` (xvfb + llvmpipe, `exit 0`, 19 shots),
copied from `build/shots/v0.7.5-dev/boss_fights/` with a `bf2_` prefix so BF1's files stay:
- [`bf2_6_brood_egg_storm_shielded.jpg`](shots/boss_fights/bf2_6_brood_egg_storm_shielded.jpg): the green shell, an
  egg in the air, a star bursting on its circle
- [`bf2_7_brood_egg_storm_5.jpg`](shots/boss_fights/bf2_7_brood_egg_storm_5.jpg)
- [`bf2_8_brood_web_spiral.jpg`](shots/boss_fights/bf2_8_brood_web_spiral.jpg)
- [`bf2_9_brood_leap_locked.jpg`](shots/boss_fights/bf2_9_brood_leap_locked.jpg)
- [`bf2_10_brood_burrow_locked.jpg`](shots/boss_fights/bf2_10_brood_burrow_locked.jpg): the locked eruption circle on
  the hero, the boss hidden
- [`bf2_12_hive_prism_spiral_shielded.jpg`](shots/boss_fights/bf2_12_hive_prism_spiral_shielded.jpg)
- [`bf2_13_hive_petal_bloom.jpg`](shots/boss_fights/bf2_13_hive_petal_bloom.jpg)
- [`bf2_14_hive_glare_ring_fast.jpg`](shots/boss_fights/bf2_14_hive_glare_ring_fast.jpg)
- [`bf2_15_hive_focus_beam_locked.jpg`](shots/boss_fights/bf2_15_hive_focus_beam_locked.jpg): three locked lines,
  cut short by the pillars

Shot 11 (`brood_burrow_eruption_ring`) isn't kept. The still hero stood on the eruption's centre, so the fairness
rule left out the whole ring (no shot spawns on the player), and it showed only the boss risen against the wall. The
ring itself is covered by the unit test.

## Not measured / open
- **Fight length ≈ 1.5×: NOT YET RUN** (the bot sims, or the owner's playtest). OWNER ONLY: whether it feels 1.5× and
  whether the dodging is fun.
- All numbers are starting values (F10: `data/bosses`, `data/bullet_patterns`).
- The Lens Drones' own "small rings" are EF's (`data/enemies/lens_drone.tres`, not touched here).
- The Hive Lens avatar doesn't tell the Glare Ring from the Prism Spiral or the Petal Bloom: any pattern spins its
  crown. A per-pattern pose could read `WorldReader.boss_pattern` later.
- Merge notes for the lead:
  - `scripts/shots/boss_fights.gd`'s PLAN gained ten rows between the Gatekeeper's and the Warlord's.
  - `FireballViews.LOOKS` gained two entries (EF and BF3 add theirs too).
  - The PLAN's BF row names BF2 Done.
