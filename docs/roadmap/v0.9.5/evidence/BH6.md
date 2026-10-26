# v0.9.5 Step BH6 evidence

The Fallen's two interphases and its dashes between moves (BOSSES_HARD.md HC4, HC5, HC6). Owner: "for phase 3, here is
where the spice comes ... some interphases to him where he dissapears and then he makes different kind of patterns,
with rays, balls, and thing that come out of the ground that make you dodge for about 15 seconds, this should feel like
a 6/10 difficulty not impossible and then he comes back and the fight continues, I liked the darkness ability of the
newer boss so we could also reuse that ... the fight should be more dynamic and fun."

- Machine: the owner's PC (Windows 11, i7-10700K, Godot 4.7.2 console build, headless, `--fixed-fps 60 --language en`),
  several runs in parallel while other agents' Godot jobs ran too (so wall times here are noise), each with its own
  `APPDATA`.
- Build: base `890334b4affbe3f8dcf79fd06715eb9bddf5943c` (branch `v095-bh6`, cut from the worktree HEAD, then merged
  `claude/v095-feedback`: a fast-forward) plus this step's working tree. The step's own commit is the branch head.
- Import: `godot --headless --path . --editor --import --quit` after the new `class_name`s: no parse errors.
- Lint: `gdformat` then `gdlint` over every touched `.gd`: `Success: no problems found`.
- Command per file: `APPDATA=$TEMP/zd-bh6-<n> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://<file> -gexit --language en`
  (folders: `-gdir=res://tests/content` etc. with `-ginclude_subdirs`).

## What changed (every number is data in `data/final_boss/nemesis.tres`, validated)

- **HC4/HC5 Two interphases** (`BossInterphase`, new). At 66 % and at 33 % of the Fallen's HP (`interphase.first_permille`,
  `second_permille`; each once: `FinalFight.ip_done`) it finishes the move it is on (at most `finish_seconds` 1.0 s, then
  the move is cut), vanishes in a burst of violet runes (`STATUS_APPLY fallen_vanish`) and for `seconds` 15.0 s the arena
  runs one pattern set. The body stands in a new BossAi state (`BossInterphase.STATE` = 11 = `FinalBoss.INTERPHASE`):
  invulnerable every tick, hidden (`BossAi.hidden`), passes through bodies, `FinalBoss.clamp_damage` takes any hit not
  the world's own to 0, so its HP is frozen. The set is drawn from the named stream `boss:interphase`
  (`RngStream.derive(seed, "boss:interphase:<floor>:<loop>:<interphase>:<draw>")`, stateless: the draw counter is saved)
  with the last interphase's set left out, so the second never repeats the first.
  - **Rays:** 3 beams (0.6 m wide, from the arena's centre to its edge: `ip_r`, measured from the walls) shown still
    for the 0.8 s telegraph (`fallen_rays` carrier) then turning at 25 degrees a second (4740 / 4096 turns a tick x 1000),
    direction and first angle from the stream; a ground eruption under the hero every 2.0 s (0.8 s telegraph ring,
    1.4 m, `fallen_erupt` carrier). An eruption's place is the hero's, or nudged 1.5 / 3.0 m (eight ways) when a beam
    would touch it within 0.5 s of its strike, or left out.
  - **Rain:** ball rings from 4 points on the edge, the pair north + south then east + west every 1.2 s: 16 slots over a
    half circle opening inward, two gaps of 3 slots (so 10 balls a point, the gap runs alternate every second ring),
    2.8 m/s, radius 0.3. The next pair's points glow for the 0.8 s before they fire. Lines of ground spikes walk across
    the arena every 3.0 s (1.0 m wide, 10.0 m long, 4 m/s, 0.8 s telegraph strip first, a way and a middle drawn from the
    stream; the arena stays open either side of it). All the lines are drawn at the set's start, and **no ball is fired
    onto a line's path** (`BossInterphase.crosses_line`: it holds a ball back if its flight would be on a line's
    footprint within 0.5 s of the line standing there).
  - **Lights Out:** the Lantern Shade's darkness: `WorldReader.boss_light` (so `ShadeViews` draws it) returns the
    interphase's dark (`BossShade.state` falls back to `BossInterphase.light`): 4 lanterns on the edge, the hero's own
    3.5 m light, a lantern's 3.0 m pool, 8 s of burn, relit by walking within 1.5 m. Slow drifting balls (1.6 m/s, at
    most 6 alive: one spawns every life / 6 ticks, from the edge toward the hero, never within 4 m of them) and
    eruptions every 2.5 s (their ring glows only where the light reaches: the view reads the light).
  - **Fair:** every hit is a carrier attack's damage (`fallen_rays`, `fallen_rain`, `fallen_dark`, `fallen_erupt`,
    `fallen_return`: 15 each, `move = &"interphase"`, in no attack list); every telegraph the carrier's windup (0.8 s,
    the return's 1.0 s; `HardRules.MIN_INTERPHASE_TELEGRAPH_TICKS` = 48 refuses less); at most one interphase hit lands
    in any 0.5 s (`grace_seconds`; the hero's own hurt i-frames are 0.5 s too).
  - **The return:** after the 15 s the shots and hazards go, the room relights, a 2.5 m ring shows at the centre for 1.0 s,
    then the slam (15 damage inside it unless dashing), the body is back there, hittable, in MOVE with a 0.5 s cooldown.
    No second interphase for 5 s.
  - **Pace left alone** (`FinalPace`, `FinalBoss`): while vanished the mimic window is OFF and its clock is held
    (`FinalFight.ip_total` is subtracted in `window_at` / `window_clock`), the rate cap's bucket does not fill, the
    damage meter's second does not run (`FinalBoss.measuring`).
- **HC6 Movement.** After every move (`BossNemesis.after_attack`) a dash is due; once the Fallen is free it draws a spot
  (up to 12 draws from the `ai` stream: 6-9 m, a clear run, the end 3 m from every wall in eight ways, the line at least
  1 m from the hero's edge), stands still showing a 0.4 s line (`BossNemesis.state()["reposition"]`), then dashes the
  distance in 0.2 s (the Nemesis's own dash movement). `mimic_window_seconds` 7.0 -> 5.6 (336 ticks).
- **Causes (3).** `CAUSE_FALLEN_RAYS`, `_RAIN`, `_DARK`, `_ERUPTION`, `_RETURN` (en and es, `locale/strings.csv`):
  `w.killer_attack` is the carrier's index (tested for all five).
- **View (4).** `InterphaseViews` (new; `WorldViewRoot.interphase`): the vanish (an expanding ring and a lifting burst of
  violet rune quads where it stood), the beams (the Prism's `BossSignatureShaders.BEAM` cylinders, thinner, violet, aim
  lines through the telegraph, a burning floor strip), eruptions (a rune ring that fills over the telegraph, then spike
  clusters), the rain's points and spike rows, the return (a falling streak, the ring filling, a flash on the slam), the
  darkness through `ShadeViews`. The floor shader is unshaded, `fog_disabled`, edge-masked; Low density halves the spikes
  and drops the rune quads; reduced motion holds the pulses. Honest note: the eruption and line spikes are the view's
  own cone MultiMesh (a StoneSpikeViews strike is fed by a boss's attack telegraph, which a vanished body has none of);
  the Prism's cross beam shader and the Shade's whole dark pass are the reuse.
- **Sound (5).** Existing cues only (`AudioEvents._fallen_cue`): vanish `boss_phase`, rays `boss_laser`, eruptions and
  lines `boss_floor_burst`, dark `boss_shade_snuff`, rain `boss_mortar`, slam `boss_slam`.
- **Saves (6).** `FinalFight` gains 27 fields (`ip_*`, `er_*`, `sl_*`, `lamp_t`, `rd_*`), all in `ADDED_SINCE_V05` and
  hashed only once an interphase or a dash has begun (`_hash_interphase`).

## Sampled difficulty (test_fallen_interphase, `gut.p`)

Each set run for its whole 15 s and its return ring with the hero walking a slow circle, two seeds, sampled every tick
for overlaps and every 15 ticks for the gap. The gap is the widest free circle in the arena (radius 15 m) between the
walls and every damage zone, doubled:

| Set | narrowest widest-gap | beam x eruption overlaps | ball x eruption | ball x spike line |
|---|---|---|---|---|
| Rays | 12.34 m | 0 | 0 | 0 |
| Rain | 6.82 m | 0 | 0 | 0 |
| Lights Out | 12.34 m | 0 | 0 | 0 |

(overlap = two different damage zones standing on one spot, an eruption counted from 0.5 s before to 0.5 s after its strike.)
The first Rain build overlapped balls and lines 7165 times across the two seeds; that is why a ball is now held back
rather than fired onto a line's path and why the lines stopped spanning the whole arena (a full-width line with a gap met
every ball of a ring once).

## final_pace (test_final_pace.gd, 16/16)

Body 3 (the Fallen) in seconds, interphase time left out (`FinalFight.ip_total`); the table's other bodies unchanged. Before =
BH5's evidence table (the base's tree); after = this tree. Raw = the whole body 3, the Fallen's interphases in brackets.

| Build | Body 3 before | Body 3 after | Raw after [interphases] |
|---|---|---|---|
| base blade | 156.4 | 152.3 | 184.3 [32.0] |
| strong blade | 149.4 | 132.6 | 164.6 [32.0] |
| absurd gun (loop 3) | 49.1 | 48.0 | 80.0 [32.0] |
| absurd blade (loop 3) | 91.0 | 88.7 | 120.7 [32.0] |

The bots hit only inside the Fallen's windows, so the shorter windows (5.6 s, less time nerfed) and the dashes move them:
-2.6 % to -11 %. The interphase's 32.0 s (2 x (15 s + the 1 s ring)) is outside every figure above; the floor (60 s x
the loop ease) holds in every row (48.0 s against 45.6 s for loop 3). `NOT YET RUN`: the "before" column was not re-run on
the base tree (Keep steps fast: no baseline copies); it is BH5's table.

## Runs (raw totals)

| Batch | Tests | Result |
|---|---|---|
| New `tests/unit/sim/test_fallen_interphase.gd` (data and hard rules, bad numbers refused, thresholds once each, a move cut within 1 s, untargetable / frozen HP / pace paused, windows undisturbed, 5.6 s windows, sets never repeat and follow the seed, rays / rain / lights-out numbers, hit once per grace, no ball into a line, the gap and overlap sampling, the return slam, the dash (24-tick line, 6-9 m, walls, never through the hero), snapshots mid-interphase for all three sets, an older save, hashing, the five causes) | 22 | 22 pass (final tree, run with test_nemesis 26 and test_final_boss 22: 70 / 70, 2411 asserts) |
| New `tests/unit/presentation/test_interphase_views.gd`, with test_final_boss_views and test_boss_animations (final tree) | 7 + 26 | 33 pass, 2574 asserts |
| `tests/e2e/test_e2e_nemesis.gd` (new: the Fallen vanishes and slams back, through main.tscn), `test_e2e_final_boss.gd`, `test_e2e_final_approach.gd` | 6 | 6 pass, 872 asserts |
| `tests/unit/sim/test_final_pace.gd` | 16 | 16 pass |
| `tests/unit/sim`: test_prism, test_lantern_shade, test_boss_hard, _hard_2, _hard_3, test_hollow_crown_hard, test_readable_cause, test_world_snapshot | 8 files | 113 pass, 21621 asserts |
| `tests/content` (folder) | 157 | 157 pass, 12701 asserts |
| `tests/golden`, `tests/arch` | 2 + 4 | all pass |
| `tests/unit/debug` (folder), `tests/unit/application` (folder) | 16 + 137 | all pass |
| `test_five_floors`, `test_curse_room`, `test_modifier_smoke`, `test_event_rarity`, `scripts/ci/seams.sh`, the full suite | - | not run (the brief; GitHub runs the full suite) |

## Tests changed because a pinned number is the data's old one (no bar lowered)

- `test_final_pace.gd`: windows 420 -> 336 ticks (7 -> 5.6 s); the fight helper subtracts the interphase time from body 3.
- `tests/unit/debug/test_dev_nemesis.gd`: `mimic_window_seconds` 7.0 -> 5.6. `test_dev_prism.gd`: the Cross's `window_seconds`
  2.5 -> 3.5 (a stale pin left by BH5, which did not run the debug folder).
- `tests/content/test_boss_pace.gd`: the five carriers join `UNCLASSED` (owner-set 15 damage chip hits, as `crossing_wave`).
- `test_final_boss_views.gd`, `test_boss_animations.gd`: an `interphase` carrier has no animation clip (never picked).

## Not done / notes

- A whole-folder run of `tests/unit/presentation` was started and stopped by me after hours on a loaded machine (about a
  third of the folder had run, no summary). Failures it printed, none in a file or system this step touched, none
  investigated: `test_attack_visuals.gd` `test_only_the_shock_lanes_raise_spikes` ("sweep raises no spikes", the
  Gatekeeper), the Tidecaller's `crossing_wave` marker look / strike tick / style checks (BH4's wave), and
  `test_gun_pulse.gd` "Big Shot doubles the pulse" (already red in BH1's evidence). `NOT YET RUN` to completion.
- The seams, the full suite and the whole presentation folder are for GitHub.
