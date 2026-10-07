# v0.3.5 Step AI — evidence: smarter bosses and enemies, Arc Caster and Bomb Drone

Owner lines F3, F4, F5, F6 ([`../PLAN.md`](../PLAN.md) "Enemy and boss AI"). Every number below is pasted from the
command shown, run by the agent in a cloud container (Linux, Godot 4.7.2-stable, headless unless noted). Owner-only
fields (feel, fun, results on the owner's hardware) are left for the owner.

- **Build:** `6ef6f24` (`v0.3.5 Step AI: smarter bosses and enemies, Arc Caster and Bomb Drone`), on `66124b6`.
- **Baseline ("before"):** `66124b6`, extracted with `git archive HEAD` into a scratch folder and run the same way.

## 1. What was built (summary; the rules are in SIM_CONTRACTS §10b)

| Owner line | Built | Starting values |
|---|---|---|
| F3 bosses | +30 % move speed; aimed windups track the player until their last 12 ticks, then commit; for 0.5 s after a dash aimed attacks go at its landing point; recoveries a further -25 % (`recovery_permille` 800 → 600); a gap-closer after 2 s out of reach (Gatekeeper charge beyond 5 m, Brood Mother leap beyond 4.5 m, Siege Engine bolt fan beyond 12 m, from the boss's edge); the punish move keeps priority | `track_commit_seconds` 0.2, `dash_read_seconds` 0.5, `gap_close_seconds` 2.0 |
| F3 bug found | A boss charge (and an enemy charge) never hit a player standing in its lane: phase 5 pushed the bodies exactly apart before phase 6's exact touch test. Fixed with a 0.02 m contact slop | `CONTACT_SLOP_M` 0.02 |
| F4 enemies | Windups drawn 24–40 ticks per attack (`ai:enemy` sub-stream); Needle and Arc Caster shots lead the player's velocity and track until the last 12 ticks; a dashing player is aimed at the dash's end; Charger/Hatchling charges bend at 60°/s (the rest of the run stays drawn); Needle bursts fan 3 shots 10° apart; walkers push apart within 1.6 m and melee walkers flank within 2–6 m | as listed |
| F5 Arc Caster | From danger tier 1 (30 s); keeps 6–9 m; bolt 22 m/s after a 30-tick line, 3-bolt spread (14°, 16 m/s), rune under the player erupting after 36 ticks (r 1.6 m); HP 40, damage 12, 4 shards | weights bolt 3 / spread 2 / rune 2 |
| F6 Bomb Drone | From danger tier 2 (60 s); a ground-plane body (melee and shots hit it), drawn 1.8 m up with a bob and a ground shadow; keeps 5–8 m; lobs at the player's spot: a 1.8 m circle filling for 48 ticks, then 16 damage; HP 30, 4 shards. Killing it before the bomb lands defuses it (the bomb is its windup) | |

Also: code-built low-poly models (`ArcCasterAvatar`, `BombDroneAvatar`, flash materials from `ActorViews.flashable`),
telegraph styles (bolt core line, rune ring with turning spokes, bomb cross-hair with the bomb arcing in), six
synthesised sounds (`arc_bolt`, `rune_erupt`, `bomb_lob`, `bomb_blast`, two deaths), death-recap causes
(`CAUSE_ARC_CASTER`, `CAUSE_BOMB_DRONE`), names, en + es strings, and a dev-panel route (Next enemy / Spawn enemy).
The minimap shows no enemies, so it is unchanged.

## 2. Full suite (on the build)

```
$ bash scripts/verify.sh
...
Totals
------
Scripts             117
Tests               698
Passing Tests       698
Asserts           415077
Time              406.852s

---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (698 passing, minimum 698)
```
`tests/MIN_TEST_COUNT` 664 → 698. Lint: `gdformat --check src scripts tests` → `360 files would be left unchanged`;
`gdlint src scripts tests` → `Success: no problems found`.

## 3. Boss fight lengths (the bots of `tests/unit/sim/test_boss_fights.gd`)

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_boss_fights.gd -gexit
```
Before (`66124b6`):
```
BOSSFIGHT| gatekeeper MELEE ticks=1975 seconds=32.9 hits=85 deflected=0 exposed=28 punished=0
BOSSFIGHT| gatekeeper RANGED_NEAR ticks=4215 seconds=70.2 hits=590 deflected=0 exposed=0 punished=0
BOSSFIGHT| brood_mother MELEE ticks=2317 seconds=38.6 hits=105 deflected=0 exposed=27 punished=0
BOSSFIGHT| brood_mother RANGED_NEAR ticks=6034 seconds=100.6 hits=735 deflected=0 exposed=10 punished=0
BOSSFIGHT| siege_engine MELEE ticks=2090 seconds=34.8 hits=89 deflected=0 exposed=27 punished=0
BOSSFIGHT| siege_engine RANGED_NEAR ticks=3886 seconds=64.8 hits=537 deflected=0 exposed=0 punished=0
BOSSFIGHT| gatekeeper RANGED_FAR ticks=8022 seconds=133.7 hits=1133 deflected=1015 punished=13
BOSSFIGHT| brood_mother RANGED_FAR ticks=10034 seconds=167.2 hits=1410 deflected=616 punished=12
BOSSFIGHT| siege_engine RANGED_FAR ticks=9390 seconds=156.5 hits=1290 deflected=1286 punished=26
```
After (`6ef6f24`, from the verify log):
```
BOSSFIGHT| gatekeeper MELEE ticks=2008 seconds=33.5 hits=86 deflected=0 exposed=28 punished=0
BOSSFIGHT| gatekeeper RANGED_NEAR ticks=4223 seconds=70.4 hits=590 deflected=0 exposed=0 punished=0
BOSSFIGHT| brood_mother MELEE ticks=2301 seconds=38.4 hits=104 deflected=0 exposed=25 punished=0
BOSSFIGHT| brood_mother RANGED_NEAR ticks=6377 seconds=106.3 hits=757 deflected=0 exposed=13 punished=0
BOSSFIGHT| siege_engine MELEE ticks=2090 seconds=34.8 hits=89 deflected=0 exposed=27 punished=0
BOSSFIGHT| siege_engine RANGED_NEAR ticks=3902 seconds=65.0 hits=537 deflected=0 exposed=0 punished=0
BOSSFIGHT| gatekeeper RANGED_FAR ticks=6109 seconds=101.8 hits=853 deflected=613 punished=0 gap_closed=12
BOSSFIGHT| brood_mother RANGED_FAR ticks=9704 seconds=161.7 hits=1362 deflected=533 punished=0 gap_closed=14
BOSSFIGHT| siege_engine RANGED_FAR ticks=9516 seconds=158.6 hits=1290 deflected=1286 punished=30 gap_closed=0
```
All within the existing bands (melee 25–90 s, near 25–120 s, far ≥ 1.5 × melee); **no band was changed**. The test
now counts the gap-closer as "staying far is punished" (`punished + gap_closed > 0`): against the Gatekeeper and the
Brood Mother the 2 s gap-closer now answers the far bot before the 4 s punish can. These bots never dodge and have
unlimited HP, so their fight length measures the player's damage uptime, not how hard the boss is to avoid; that is
why it barely moves. The far bot's fights got shorter (Gatekeeper 133.7 → 101.8 s) because the gap-closer brings the
boss into full-damage range.

## 4. How often the player gets hit (scratch probes, not tracked tests)

`build/dbg/boss_pressure_probe.gd` replays the three bots above and sums the hits and damage the bot took
(`bot=0` melee, `1` near shooter, `2` far shooter):
```
$ godot --headless --path . -s build/dbg/boss_pressure_probe.gd
```
Before (`66124b6`):
```
PRESSURE| gatekeeper bot=0 seconds=32.9 hits_taken=5 damage_taken=98 per_minute=178.6
PRESSURE| gatekeeper bot=1 seconds=70.2 hits_taken=21 damage_taken=446 per_minute=380.9
PRESSURE| gatekeeper bot=2 seconds=133.7 hits_taken=24 damage_taken=504 per_minute=226.2
PRESSURE| brood_mother bot=0 seconds=38.6 hits_taken=6 damage_taken=120 per_minute=186.4
PRESSURE| brood_mother bot=1 seconds=100.6 hits_taken=24 damage_taken=352 per_minute=210.0
PRESSURE| brood_mother bot=2 seconds=167.2 hits_taken=27 damage_taken=624 per_minute=223.9
PRESSURE| siege_engine bot=0 seconds=34.8 hits_taken=11 damage_taken=148 per_minute=254.9
PRESSURE| siege_engine bot=1 seconds=64.8 hits_taken=30 damage_taken=422 per_minute=390.9
PRESSURE| siege_engine bot=2 seconds=156.5 hits_taken=84 damage_taken=1414 per_minute=542.1
```
After (`6ef6f24`):
```
PRESSURE| gatekeeper bot=0 seconds=33.5 hits_taken=5 damage_taken=98 per_minute=175.7
PRESSURE| gatekeeper bot=1 seconds=70.4 hits_taken=23 damage_taken=486 per_minute=414.3
PRESSURE| gatekeeper bot=2 seconds=101.8 hits_taken=32 damage_taken=748 per_minute=440.8
PRESSURE| brood_mother bot=0 seconds=38.4 hits_taken=7 damage_taken=128 per_minute=200.3
PRESSURE| brood_mother bot=1 seconds=106.3 hits_taken=31 damage_taken=472 per_minute=266.5
PRESSURE| brood_mother bot=2 seconds=161.7 hits_taken=42 damage_taken=1008 per_minute=373.9
PRESSURE| siege_engine bot=0 seconds=34.8 hits_taken=11 damage_taken=148 per_minute=254.9
PRESSURE| siege_engine bot=1 seconds=65.0 hits_taken=34 damage_taken=508 per_minute=468.7
PRESSURE| siege_engine bot=2 seconds=158.6 hits_taken=84 damage_taken=1420 per_minute=537.2
```
`build/dbg/dodge_probe.gd`: a "dodger" that holds 4–6 m, shoots, and dashes sideways 16 ticks before every
telegraphed attack lands (90 s against each boss with unlimited HP, and against one enemy of each kind):
```
$ godot --headless --path . -s build/dbg/dodge_probe.gd
```
Before (`66124b6`; the new kinds don't exist there):
```
DODGE| boss gatekeeper ticks=5400 dodges=25 hits_taken=0 hits_per_minute=0.0
DODGE| boss brood_mother ticks=5400 dodges=45 hits_taken=0 hits_per_minute=0.0
DODGE| boss siege_engine ticks=5400 dodges=27 hits_taken=27 hits_per_minute=18.0
DODGE| enemy charger ticks=5400 dodges=30 hits_taken=0 hits_per_minute=0.0
DODGE| enemy warden ticks=5400 dodges=0 hits_taken=0 hits_per_minute=0.0
DODGE| enemy needle ticks=5400 dodges=27 hits_taken=0 hits_per_minute=0.0
```
After (`6ef6f24`):
```
DODGE| boss gatekeeper ticks=5400 dodges=27 hits_taken=14 hits_per_minute=9.3
DODGE| boss brood_mother ticks=5400 dodges=48 hits_taken=8 hits_per_minute=5.3
DODGE| boss siege_engine ticks=5400 dodges=28 hits_taken=37 hits_per_minute=24.7
DODGE| enemy charger ticks=5400 dodges=30 hits_taken=0 hits_per_minute=0.0
DODGE| enemy warden ticks=5400 dodges=0 hits_taken=0 hits_per_minute=0.0
DODGE| enemy needle ticks=5400 dodges=26 hits_taken=26 hits_per_minute=17.3
DODGE| enemy arc_caster ticks=5400 dodges=34 hits_taken=24 hits_per_minute=16.0
DODGE| enemy bomb_drone ticks=5400 dodges=28 hits_taken=0 hits_per_minute=0.0
```
Reading (the agent's, not the owner's): before, a well-timed dash made the Gatekeeper and the Brood Mother unable to
land a hit ("some times is impossible to get hit by them"); now they do. The Needle and the new Arc Caster now catch a
well-timed dash. The Charger is still beaten by this dodge (its 60°/s bend can't follow a 4 m sideways dash); the
Warden never attacks a player who stays 4 m away; the Bomb Drone's circle is fixed where you stood, so a dash out
of it always works (by design: the circle is the warning). Feel: **OWNER ONLY**.

## 5. Readable cause (no damage without a readable cause)

`tests/unit/sim/test_readable_cause.gd` passes inside the suite (its hit bar `damage > 20` unchanged), and the new
`tests/unit/sim/test_enemy_ai.gd::test_every_hit_from_the_new_kinds_has_a_readable_cause` fights both new kinds
directly. The 12-seed × 3-floor check:
```
$ godot --headless --path . -s scripts/checks/readable_cause.gd
{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_ARC_CASTER": 28,
		"CAUSE_BOSS_ARENA": 80,
		"CAUSE_BROOD_BROOD": 6,
		"CAUSE_BROOD_BURROW": 49,
		"CAUSE_BROOD_LEAP": 5,
		"CAUSE_CHARGER": 107,
		"CAUSE_GATEKEEPER_CHARGE": 8,
		"CAUSE_GATEKEEPER_LANES": 5,
		"CAUSE_GATEKEEPER_SLAM": 6,
		"CAUSE_GATEKEEPER_SWEEP": 31,
		"CAUSE_HATCHLING": 20,
		"CAUSE_NEEDLE": 101,
		"CAUSE_SIEGE_BARRAGE": 31,
		"CAUSE_SIEGE_BOLTS": 46,
		"CAUSE_SIEGE_DEPLOY": 1,
		"CAUSE_SIEGE_RAIL": 35,
		"CAUSE_WARDEN": 45
	},
	"damage_to_player": 604,
	"death_recap_mismatches": [],
	"deaths_checked": 24,
	"floor_ticks": 3600,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}
```
(exit 0, on `6ef6f24`.) With the default 3600 floor ticks the run never reaches tier 2, so no Bomb Drone spawns; a
longer run that does (on the same sim code, the working tree just before the commit, which then only gained a test
and formatting):
```
$ godot --headless --path . -s scripts/checks/readable_cause.gd -- seeds=12 floor_ticks=5400 boss_ticks=3600
{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_ARC_CASTER": 96,
		"CAUSE_BOMB_DRONE": 18,
		"CAUSE_BOSS_ARENA": 24,
		"CAUSE_BROOD_BROOD": 6,
		"CAUSE_BROOD_BURROW": 50,
		"CAUSE_BROOD_LEAP": 6,
		"CAUSE_CHARGER": 160,
		"CAUSE_GATEKEEPER_CHARGE": 8,
		"CAUSE_GATEKEEPER_LANES": 6,
		"CAUSE_GATEKEEPER_SLAM": 8,
		"CAUSE_GATEKEEPER_SWEEP": 41,
		"CAUSE_HATCHLING": 33,
		"CAUSE_NEEDLE": 149,
		"CAUSE_SIEGE_BARRAGE": 27,
		"CAUSE_SIEGE_BOLTS": 54,
		"CAUSE_SIEGE_DEPLOY": 1,
		"CAUSE_SIEGE_RAIL": 31,
		"CAUSE_WARDEN": 118
	},
	"damage_to_player": 836,
	"death_recap_mismatches": [],
	"deaths_checked": 22,
	"floor_ticks": 5400,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}
```
**A checker fix, named here:** with the faster bosses, seed 9101 floor 2 died to the closing arena band while the
checker had booked that band's damage to the attack the Brood Mother was making (`CAUSE_BROOD_BURROW`), so the recap
(`CAUSE_BOSS_ARENA`, correct) "mismatched". `tests/support/readable_cause.gd` now books a hit with
`effect_id == &"arena_band"` to `CAUSE_BOSS_ARENA` (the band has its own warning, validated ≥ the telegraph minimum).
The hit bar and the telegraph rule are unchanged.

## 6. Parity (EI-07) with tracking

The windup shape now moves until it commits, so the parity tests compare the hit with the shape drawn *after* the
commit: the boss parity test keeps the player on the aim point while the boss tracks and steps to the test spot once
it has committed; the enemy parity test takes the last drawn windup shape (the Charger's with its bend set to 0; the
bend has its own test, and the rest of a running charge is drawn, `EnemyAi.running_lane`). Both pass in the suite.

## 7. Reached in the real game

`tests/e2e/test_e2e_new_enemies.gd` (in the suite above): boots `main.tscn`, backtick opens the dev panel, mouse
clicks on God, Next enemy (until the panel names the Arc Caster / Bomb Drone) and Spawn enemy; each one's model is
drawn, its spell's styled telegraph shows and the spell reaches the player (a HIT event on the player from it). In a
normal run they arrive from the spawner at danger tiers 1 and 2 (`tests/unit/sim/test_spawn_director.gd`,
`tests/content/test_spawning_validation.gd`).

## 8. Goldens and export smoke

No golden changed. The new state (the `ai:enemy` stream, `ActorStore.AI_FIELDS`) is hashed only in worlds with enemy
tables, and the new boss fields only in worlds with boss tables; the kernel golden has neither.
```
$ bash scripts/ci/export_smoke.sh
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ...
  ok    audio cues: 55
  ok    every cue's sound loads from the pack (missing: [])
  ...
0 miss(es)
```
(exit 0.) `python3 scripts/audio/generate_sfx.py --check` → `0 difference(s)` (the existing 49 files are
byte-identical; six new files and their manifest entries were added).

## 9. Screenshot

`new_enemies.png` (this folder), rendered with
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/new_enemies.gd`
(software Vulkan, llvmpipe) and copied by hand from `build/shots/v0.3.0-dev/enemies/new_enemies.png`: the Arc
Caster's bolt line, its 3-bolt spread, its rune under the player, and the Bomb Drone hovering over its shadow with
its bomb arcing into the filling circle. Look: **OWNER ONLY**.

## 10. Gaps

- The Charger is still dodged by a well-timed sideways dash (§4); making it read dashes too was not in the PLAN.
- The Arc Caster and Bomb Drone have no concept sheet; their models are the agent's reading of the enemy style.
- The playtest of all of this: **OWNER ONLY**.
