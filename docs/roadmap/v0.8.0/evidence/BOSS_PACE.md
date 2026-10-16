# BOSS_PACE: are the bosses faster in places, punishable after big attacks, and deadly by hits (O27)?

- **Status:** RUN (sim and content checks); the feel in play is **OWNER ONLY**
- **Build:** the working tree of the commit `v0.8.0 Step BP` on `v080-bp` (parent `f1e2ab1`); Godot
  `4.7.2.stable.official.ed1daf0bf`; a shared Linux cloud container (headless), not the owner's hardware
- **Date:** 2026-10-16
- **Who ran it:** agent

Owner, 2026-10-16 (O27, verbatim in [`../PLAN.md`](../PLAN.md)): "Bosses animations should be a bit faster, not all
of them but you should rely on dashing as a mechanic to not get killed, for example the throwing javelins should come
and go faster or some jumps from bosses not all of them, the bosses mechanics look fine now but difficulty should be
increased and more skill should be brought in, keep an eye on not making them unkillable by the blade because it is
melee, bosses should also kill you in 3-4 strikes, depends on how big the attack is, small balls 4-5 big attacks 2".
O38: built in v0.8.0 as step BP from the lead's proposal.

## The change
- **Hits to kill.** Every boss attack has a `hit_class` (`small` / `medium` / `big`; CONTENT_SCHEMA "v0.8.0 BP").
  Against the base hero (`data/player/runner.tres`: 100 HP) at the data's damage (loop 1, ×1.0): small orbs, shots,
  eggs and bombs **22** (5 hits), the Warlord's javelins **25** (4), medium strikes, lanes, beams, floods **30** (4)
  or **34** (3), big attacks (leaps, the lunge, the burrow, slam rings, single fist slam, single beam / rail) **50**
  (2). An attack whose big hit also fires orbs (a leap's quake ring, a burrow's eruption ring, the eggs' bursts, the
  Gaze's and the Cross's orbs, the boulders' shards) gives its orbs their own `orb_damage` 22 (5 hits): before, the
  orbs dealt the attack's whole damage. Loop scaling (×1.2 damage a loop, O11) and the floor factors still multiply
  both (`RunState.scale_bosses`; a content test checks loop 2's ×1.44 on floor 2).
- **Faster in places** (lock kept: owner N15 "Track, then lock 0.8 s", the Colossus's 0.5 s from FB1; what shrinks
  is the tracking before the lock and the flight after it):
  - Warlord: javelins wind up 0.6 → 0.45 s, fly 4.5 → 6.5 m/s (phase 3's fan 5.0 → 7.0 m/s, the slow-shot cap of
    `BulletPatternDefinition`), waves 0.35 → 0.25 s (0.30 → 0.22 s) apart, stick 1.0 → 0.5 s before they fly back
    (at the same speed, so faster back too); the lunge 1.4 → 1.0 s, 16 → 20 m/s.
  - Brood Mother: leap 1.6 → 1.0 s, leap chain 1.4 → 1.0 s (flight 0.5 → 0.4 s each), pounce chain 1.2 → 0.95 s
    (flight 0.45 → 0.35 s).
  - Hive Lens: dive 1.4 → 1.0 s (flight 0.5 → 0.4 s), focus beams 1.6 → 1.1 s.
  - Gatekeeper: fist slams 1.6 → 1.1 s.
  - Siege Engine: rails 1.5 → 1.1 s, shockwave 1.2 → 0.9 s.
  - Foundry: vent blast 0.8 → 0.6 s, bomb launches 1.0 → 0.7 s.
  - Colossus: leap slams 0.9 → 0.7 s (flight 0.6 → 0.45 s), boulder throws 1.0 → 0.75 s.
  - The Prism: unchanged pace (her Cross is the skill phase F5/F7 designed around its window). The Nemesis: unchanged
    (it copies your pace and its blows come from your build; see "For the owner").
- **Kept slow and readable, per boss** (tests/content/test_boss_pace.gd `KEPT_SLOW`): Gatekeeper rock rings + shock
  lanes; Warlord shield wall + spear lines; Brood Mother egg storm + burrow; Hive Lens prism spiral + the Gaze; Siege
  Engine turret cross + mortar grid; Foundry slag fountain + molten flood; Colossus spike chase + fist combo; Prism the
  Cross.
- **Punish window.** A big attack ends in its recovery: the boss stands still, attacks nothing, its weak point open
  (×2 damage within 2.5 m), for 0.6–0.9 s (36–54 ticks after `recovery_permille`; `BossDefinition` refuses one
  outside, and a big attack may not chain into a follow-up, so the window always comes). Follow-ups dropped for that:
  the Warlord's lunge → bash, the Brood Mother's leap chain → brood and burrows → leap. The Colossus's leap slams
  recovered 0.49 s; now 0.7 s (1.0 s × its 700 ‰).
- **Found and fixed:** a boss's body shove ignored walls, so the faster Colossus leap landing beside a hero at the
  final ring's wall pushed the hero out of the ring (`test_final_boss.gd::test_nothing_leaves_the_ring` failed with
  15.35 m against a 15.0 m ring). `World._shove` now sweeps the shoved body to the first wall; the other pushes are
  unchanged.
- **Animations** follow the sim: `BossAvatar.clip_time` already maps the windup, active and recovery ticks the reader
  gives onto each clip (BA), the leap's height reads the flight's progress and the recall its permille; no view timer
  decides anything. A presentation test checks seven sped-up attacks get the new windup from the reader and strike on
  their first active tick.

## Command
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<the 28 sim files below> -gexit
```
(the sim set: test_after_boss, test_arenas, test_ascension, test_boss_challenge, test_boss_fights{,_2,_3},
test_boss_gates, test_boss_markers, test_boss_pace, test_boss_pressure, test_boss_room_builder,
test_boss_signatures{,_2}, test_bosses{,_2}, test_bullet_patterns, test_catch_up, test_collision, test_colossus,
test_difficulty_curve, test_enemy_fireballs, test_final_boss, test_nemesis, test_prism, test_readable_cause,
test_run_flow, test_world_snapshot)

## Raw output
The `BP` lines `tests/unit/sim/test_boss_pace.gd` prints, and the run's totals:
```
BP dodge gatekeeper fist_slam at 2.9 m: clean by ["left", "right", "away"]
BP dodge gatekeeper fist_slam at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge gatekeeper fist_slam_2 at 2.9 m: clean by ["left", "right", "away"]
BP dodge gatekeeper fist_slam_2 at 8.0 m: clean by ["left", "right", "away"]
BP dodge gatekeeper fist_slam_3 at 2.9 m: clean by ["left", "right", "away"]
BP dodge gatekeeper fist_slam_3 at 8.0 m: clean by ["left", "right", "away"]
BP dodge warlord javelin_fan at 2.6 m: clean by ["left", "right", "away", "toward"]
BP dodge warlord javelin_fan at 8.0 m: clean by ["left", "right", "away"]
BP dodge warlord javelin_fan_fast at 2.6 m: clean by ["left", "right", "away", "toward"]
BP dodge warlord javelin_fan_fast at 8.0 m: clean by ["left", "right", "away"]
BP dodge warlord lunge_dash at 5.0 m: clean by ["left", "right"]
BP dodge warlord lunge_dash at 8.0 m: clean by ["left", "right", "away"]
BP dodge brood_mother leap at 4.5 m: clean by ["left", "right", "away", "toward"]
BP dodge brood_mother leap at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge brood_mother leap_chain at 4.5 m: clean by ["left", "right", "away", "toward"]
BP dodge brood_mother leap_chain at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge brood_mother pounce_chain at 2.8 m: clean by ["left", "right", "away", "toward"]
BP dodge brood_mother pounce_chain at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge hive_lens dive at 4.5 m: clean by ["left", "right", "away", "toward"]
BP dodge hive_lens dive at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge hive_lens focus_beam at 2.5 m: clean by ["left", "right"]
BP dodge hive_lens focus_beam at 8.0 m: clean by ["left", "right"]
BP dodge hive_lens focus_beam_3 at 2.5 m: clean by ["left", "right"]
BP dodge hive_lens focus_beam_3 at 8.0 m: clean by ["left", "right"]
BP dodge siege_engine rail at 3.0 m: clean by ["left", "right"]
BP dodge siege_engine rail at 8.0 m: clean by ["left", "right"]
BP dodge siege_engine rail_3 at 3.0 m: clean by ["left", "right"]
BP dodge siege_engine rail_3 at 8.0 m: clean by ["left", "right"]
BP dodge siege_engine shockwave at 3.0 m: clean by ["toward"]
BP dodge siege_engine shockwave at 8.0 m: clean by ["toward"]
BP dodge foundry vent_blast at 3.1 m: clean by ["left", "right", "away"]
BP dodge foundry vent_blast at 4.5 m: clean by ["left", "right", "away"]
BP dodge foundry bomb_launch at 3.1 m: clean by ["left", "right", "away", "toward"]
BP dodge foundry bomb_launch at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge foundry bomb_launch_3 at 3.1 m: clean by ["left", "right", "away", "toward"]
BP dodge foundry bomb_launch_3 at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge colossus leap_slam at 4.5 m: clean by ["left", "right", "away", "toward"]
BP dodge colossus leap_slam at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge colossus leap_slam_2 at 4.5 m: clean by ["left", "right", "away", "toward"]
BP dodge colossus leap_slam_2 at 8.0 m: clean by ["left", "right", "away", "toward"]
BP dodge colossus boulder_throw at 3.5 m: clean by ["left", "right", "away"]
BP dodge colossus boulder_throw at 8.0 m: clean by ["left", "right", "away"]
BP dodge colossus boulder_throw_3 at 3.5 m: clean by ["left", "right", "away"]
BP dodge colossus boulder_throw_3 at 8.0 m: clean by ["left", "right", "away"]
BP blade gatekeeper: killed=true in 69.9 s, 767 swings, 4 dashes, hits taken 11 (338 damage)
BP blade warlord: killed=true in 80.8 s, 876 swings, 1 dashes, hits taken 4 (136 damage)
BP blade brood_mother: killed=true in 84.0 s, 822 swings, 4 dashes, hits taken 28 (726 damage)
BP blade hive_lens: killed=true in 87.1 s, 1034 swings, 1 dashes, hits taken 13 (118 damage)
BP blade siege_engine: killed=true in 75.7 s, 924 swings, 1 dashes, hits taken 40 (722 damage)
BP blade foundry: killed=true in 136.9 s, 1159 swings, 7 dashes, hits taken 49 (878 damage)
BP blade final: won=true in 155.6 s, bodies [[22, 60], [23, 4609], [24, 8123]], 1675 swings, 0 dashes, hits taken 82 (3282 damage)
[… the other files' lines trimmed …]
Scripts              28
Passing Tests       377
Asserts           548859
Time              1811.936s
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Hits to kill 100 HP at the data's damage | small 4–5, medium 3–4, big 2 | O27; `BossSchemas.HIT_CLASSES` |
| A sped-up attack | dodged by a dash 0.3 s after its telegraph appears (or once its aim stops following), at a near and a far distance, by at least one way | BP brief |
| Punish window after a big attack | 0.6–0.9 s, still, no attack | BP brief (starting value) |
| The Blade at the base build kills each boss | within 180 s (the six) / 360 s (the final boss) | BP brief "reasonable time" (the lead's starting value) |

## Result
- Hits to kill: all 69 classed attacks in their band (content test); the table below.
- Dodge: every sped-up attack (24 across 7 bodies) clean at both distances by at least one way. The Siege Engine's
  shockwave is a ring with a safe middle (inner 4.4 m), dodged only by dashing **toward** it; the beams, rails and the
  lunge only sideways. The Foundry's bomb launches land round the boss (2.8 m out), so the hero was clean every way:
  a weak proof for those two (they don't reach a hero standing 3.1 m or more away).
- Punish window: 11 big attacks of the six bosses hold still 36–54 ticks with the weak point open (sim test); the
  Colossus's two compile to 42 ticks (content test).
- Blade-only kills: the six in 70–137 s (the Foundry slowest), the final boss in 155.6 s (the bodies took over at world
  ticks 60, 4609 and 8123: the Colossus about 76 s, the Prism about 59 s with the shatters and rises, the Nemesis
  the rest). Not a survival proof: the scripted hero dodges only the big attacks and is healed every
  tick; it took 4–49 hits a fight (136–878 damage) and 82 in the final fight. Against the Colossus it stood in melee
  and never saw a leap slam (its 4 m minimum range): 0 dashes.

## Per attack
Damage: the data's (× floor and loop factors in a run). Telegraph (lock) in seconds; recovery in ticks after the
boss's `recovery_permille` (the window after a big attack).

### gatekeeper

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| rock_rings | pattern | small | 12 → 22 (9 → 5) | — | 0.8 (-) | 0.0167 | 57 |
| rock_rings_4 | pattern | small | 12 → 22 (9 → 5) | — | 0.8 (-) | 0.0167 | 54 |
| fist_slam | marks | big | 22 → 50 (5 → 2) | — | 1.6 (0.8) → 1.1 (0.8) | 0.0167 | 36 |
| fist_slam_2 | marks | medium | 22 → 34 (5 → 3) | — | 1.6 (0.8) → 1.1 (0.8) | 0.0167 | 36 |
| fist_slam_3 | marks | medium | 22 → 34 (5 → 3) | — | 1.6 (0.8) → 1.1 (0.8) | 0.0167 | 36 |
| shock_lanes | row_lanes | medium | 20 → 30 (5 → 4) | — | 1.6 (0.8) | 0.0167 | 36 |
| shock_lanes_2 | row_lanes | medium | 20 → 30 (5 → 4) | — | 1.6 (0.8) | 0.0167 | 36 |
| sweep | sweep | medium | 18 → 30 (6 → 4) | — | 0.6 (-) | 0.0167 | 32 |

### warlord

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| shield_wall | pattern | small | 14 → 22 (8 → 5) | — | 0.8 (-) | 0.0167 | 57 |
| shield_wall_cross | pattern | small | 14 → 22 (8 → 5) | — | 0.8 (-) | 0.0167 | 54 |
| javelin_fan | pattern | small | 12 → 25 (9 → 4) | — | 0.6 (-) → 0.45 (-) | 0.0167 | 39 |
| javelin_fan_fast | pattern | small | 12 → 25 (9 → 4) | — | 0.6 (-) → 0.45 (-) | 0.0167 | 36 |
| shield_bash | sweep | medium | 18 → 34 (6 → 3) | — | 0.6 (-) | 0.0167 | 32 |
| spear_lines | flood | medium | 20 → 30 (5 → 4) | — | 1.6 (0.8) | 0.6 | 43 |
| spear_wall | flood | medium | 20 → 30 (5 → 4) | — | 1.6 (0.8) | 0.7 | 39 |
| lunge_dash | charge | big | 24 → 50 (5 → 2) | — | 1.4 (0.8) → 1.0 (0.8) | 0.0167 | 46 |

### brood_mother

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| egg_storm | marks | medium | 14 → 30 (8 → 4) | 22 (5 hits) | 1.6 (0.8) | 0.0167 | 50 |
| egg_storm_5 | marks | medium | 14 → 30 (8 → 4) | 22 (5 hits) | 1.6 (0.8) | 0.0167 | 46 |
| web_spiral | pattern | small | 12 → 22 (9 → 5) | — | 0.8 (-) | 0.0167 | 43 |
| leap | leap | big | 24 → 50 (5 → 2) | — | 1.6 (0.8) → 1.0 (0.8) | 0.5 → 0.4 | 36 |
| leap_chain | leap | big | 24 → 50 (5 → 2) | — | 1.4 (0.8) → 1.0 (0.8) | 0.5 → 0.4 | 36 |
| burrow | burrow | big | 24 → 50 (5 → 2) | 22 (5 hits) | 1.0 (0.8) | 0.0167 | 43 |
| burrow_2 | burrow | big | 24 → 50 (5 → 2) | 22 (5 hits) | 1.0 (0.8) | 0.0167 | 39 |
| brood | brood | small | 8 → 22 (13 → 5) | — | 0.8 (-) | 0.0167 | 36 |
| brood_4 | brood | small | 8 → 22 (13 → 5) | — | 0.6 (-) | 0.0167 | 28 |
| pounce_chain | leap | medium | 22 → 34 (5 → 3) | — | 1.2 (0.8) → 0.95 (0.8) | 0.45 → 0.35 | 54 |

### hive_lens

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| prism_spiral | pattern | small | 12 → 22 (9 → 5) | — | 0.9 (-) | 0.0167 | 54 |
| prism_spiral_fast | pattern | small | 12 → 22 (9 → 5) | — | 0.9 (-) | 0.0167 | 50 |
| petal_bloom | pattern | small | 12 → 22 (9 → 5) | — | 0.7 (-) | 0.0167 | 39 |
| petal_bloom_fast | pattern | small | 12 → 22 (9 → 5) | — | 0.7 (-) | 0.0167 | 36 |
| gaze | gaze | medium | 14 → 30 (8 → 4) | 22 (5 hits) | 0.8 (-) | 12.0 | 50 |
| gaze_fast | gaze | medium | 14 → 30 (8 → 4) | 22 (5 hits) | 0.8 (-) | 11.2 | 46 |
| focus_beam | lanes | big | 22 → 50 (5 → 2) | — | 1.6 (0.8) → 1.1 (0.8) | 0.3 | 43 |
| focus_beam_3 | lanes | medium | 22 → 34 (5 → 3) | — | 1.6 (0.8) → 1.1 (0.8) | 0.3 | 43 |
| lens_flare | slam_ring | medium | 18 → 30 (6 → 4) | — | 0.7 (-) | 0.0167 | 39 |
| dive | leap | big | 20 → 50 (5 → 2) | — | 1.4 (0.8) → 1.0 (0.8) | 0.5 → 0.4 | 43 |
| split | deploy | small | 14 → 22 (8 → 5) | — | 1.0 (-) | 0.0167 | 36 |

### siege_engine

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| turret_cross | pattern | small | 14 → 22 (8 → 5) | — | 0.9 (-) | 0.0167 | 57 |
| turret_cross_fast | pattern | small | 14 → 22 (8 → 5) | — | 0.9 (-) | 0.0167 | 54 |
| mortar_grid | grid | medium | 20 → 30 (5 → 4) | — | 1.6 (0.8) | 0.0167 | 36 |
| mortar_grid_3 | grid | medium | 20 → 30 (5 → 4) | — | 1.6 (0.8) | 0.0167 | 36 |
| barrage | marks | medium | 20 → 30 (5 → 4) | — | 1.6 (0.8) | 0.0167 | 32 |
| barrage_fast | marks | medium | 20 → 30 (5 → 4) | — | 1.5 (0.8) | 0.0167 | 32 |
| rail | lanes | big | 26 → 50 (4 → 2) | — | 1.5 (0.8) → 1.1 (0.8) | 0.2 | 39 |
| rail_3 | lanes | medium | 26 → 34 (4 → 3) | — | 1.5 (0.8) → 1.1 (0.8) | 0.2 | 39 |
| deploy | deploy | small | 15 → 22 (7 → 5) | — | 1.0 (-) | 0.0167 | 28 |
| shockwave | slam_ring | big | 22 → 50 (5 → 2) | — | 1.2 (-) → 0.9 (-) | 0.0167 | 54 |

### foundry

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| slag_fountain | pattern | small | 14 → 22 (8 → 5) | — | 1.0 (-) | 0.0167 | 57 |
| slag_fountain_2 | pattern | small | 14 → 22 (8 → 5) | — | 1.0 (-) | 0.0167 | 54 |
| furnace_waves | pattern | small | 14 → 22 (8 → 5) | — | 0.8 (-) | 0.0167 | 43 |
| molten_flood | row_flood | medium | 12 → 30 (9 → 4) | — | 1.6 (0.8) | 1.6 | 36 |
| molten_flood_5 | row_flood | medium | 12 → 30 (9 → 4) | — | 1.6 (0.8) | 1.6 | 32 |
| vent_blast | slam_ring | big | 20 → 50 (5 → 2) | — | 0.8 (-) → 0.6 (-) | 0.0167 | 46 |
| bomb_launch | brood | small | 12 → 22 (9 → 5) | — | 1.0 (-) → 0.7 (-) | 0.0167 | 36 |
| bomb_launch_3 | brood | small | 12 → 22 (9 → 5) | — | 1.0 (-) → 0.7 (-) | 0.0167 | 32 |
| firestorm | flood | medium | 16 → 30 (7 → 4) | — | 1.6 (0.8) | 1.2 | 50 |
| meltdown | melt | none | 8 (13) | — | 2.0 (-) | 0.5 | 36 |

### colossus

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| fist_combo | combo | medium | 20 → 34 (5 → 3) | — | 0.8 (0.5) | 0.0167 | 25 |
| fist_combo_3 | combo | medium | 20 → 34 (5 → 3) | — | 0.8 (0.5) | 0.0167 | 25 |
| leap_slam | leap | big | 24 → 50 (5 → 2) | 22 (5 hits) | 0.9 (0.5) → 0.7 (0.5) | 0.6 → 0.45 | 29 → 42 |
| leap_slam_2 | leap | big | 24 → 50 (5 → 2) | 22 (5 hits) | 0.9 (0.5) → 0.7 (0.5) | 0.6 → 0.45 | 29 → 42 |
| spike_chase | spike_chase | medium | 18 → 30 (6 → 4) | — | 0.9 (0.5) | 0.0167 | 25 |
| spike_chase_2 | spike_chase | medium | 18 → 30 (6 → 4) | — | 0.9 (0.5) | 0.0167 | 25 |
| spike_burst | spike_burst | medium | 18 → 30 (6 → 4) | — | 0.9 (0.5) | 0.0167 | 33 |
| boulder_throw | marks | medium | 22 → 34 (5 → 3) | 22 (5 hits) | 1.0 (0.5) → 0.75 (0.5) | 0.0167 | 25 |
| boulder_throw_3 | marks | medium | 22 → 34 (5 → 3) | 22 (5 hits) | 1.0 (0.5) → 0.75 (0.5) | 0.0167 | 25 |

### prism

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| cross_ring | cross | medium | 14 → 30 (8 → 4) | 22 (5 hits) | 1.0 (-) | 7.5 | 0 |
| cross_spiral | cross | medium | 14 → 30 (8 → 4) | 22 (5 hits) | 1.0 (-) | 7.5 | 0 |
| cross_flower | cross | medium | 14 → 30 (8 → 4) | 22 (5 hits) | 1.0 (-) | 7.5 | 0 |
| prism_bolt | bolt_fan | small | 12 → 22 (9 → 5) | — | 0.5 (0.4) | 0.0167 | 24 |

### nemesis

| Attack | Move | Class | Damage before → after (hits to kill 100 HP) | Orbs | Telegraph s (lock) before → after | Active s | Recovery (window) ticks before → after |
|---|---|---|---|---|---|---|---|
| nemesis_combo | mimic_combo | none | 100 % of its hit, unchanged (from the build) | — | 0.7 (0.4) | 0.0167 | 30 |
| nemesis_crescents | mimic_shots | none | 70 % of its hit, unchanged (from the build) | — | 0.8 (0.4) | 0.0167 | 30 |
| nemesis_volley | mimic_shots | none | 80 % of its hit, unchanged (from the build) | — | 0.8 (0.4) | 0.0167 | 30 |
| nemesis_point_blank | mimic_shots | none | 100 % of its hit, unchanged (from the build) | — | 0.65 (0.4) | 0.0167 | 30 |
| nemesis_card_1 | card_cast | none | 120 % of its hit, unchanged (from the build) | — | 1.0 (0.5) | 0.0167 | 30 |
| nemesis_card_2 | card_cast | none | 120 % of its hit, unchanged (from the build) | — | 1.0 (0.5) | 0.0167 | 30 |
| nemesis_card_3 | card_cast | none | 120 % of its hit, unchanged (from the build) | — | 1.0 (0.5) | 0.0167 | 30 |


**Not changed, hazards:** the closing band (6 a 0.5 s), the Foundry's lava (`lava_damage`) and the meltdown (8),
the arena hazards; the adds a boss brings (Hatchlings, turrets, Lens Drones) keep their enemy damage.

## For the owner
- **The Nemesis** (D23): its blows are capped at a fifth of your max HP (FB3, "never a one-shot"), so it needs 5+ hits:
  against O27's 3–4. Not changed; OWNER_TODO D23.
- **Which floor** (D24): the hit counts hold on the data (×1.0). In a run: floor 1 ×0.8 (orbs 17 = 6 hits, javelins 20
  = 5, medium 24/27 = 5/4, big 40 = 3), floor 2 ×1.2 (26 = 4, 30 = 4, 36/40 = 3, 60 = 2), floor 3 ×1.4 (30 = 4,
  35 = 3, 42/47 = 3, 70 = 2), before the catch-up. OWNER_TODO D24.
- The feel, whether it is harder and more skill: **OWNER ONLY**.

## Tests
- New `tests/content/test_boss_pace.gd` (6): hits to kill per class, loop scaling on top, the big attacks' windows,
  the javelins, sped-up / kept-slow lists, bad classes and windows refused.
- New `tests/unit/sim/test_boss_pace.gd` (4): the dodges, the still window, the six Blade kills, the final boss.
- New test in `tests/unit/presentation/test_boss_animations.gd`: the sped-up attacks animate on the sim's ticks.
- Changed on purpose: `test_boss_markers.gd` (the Warlord's javelins 6-7 m/s, not 3-5),
  `test_boss_signatures.gd` (the javelins stuck at 150 ticks, not 200; the phase-3 egg test holds the boss's next
  attack, which the dropped follow-up's roll moved onto a brood).
