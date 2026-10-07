# v0.4.0 Step EN — evidence: six horde enemies (12 behaviours)

PLAN [`../PLAN.md`](../PLAN.md) "Enemies (EN)", ROADMAP R2 ("12 enemy behaviours": 6 after v0.3.5 + 6 here). Every
number below is pasted from the command shown, run by the agent in a cloud container (Linux, Godot 4.7.2-stable,
headless unless noted). Owner-only fields (feel, fun, the look, results on the owner's hardware) are left for the owner.

- **Build:** the tree committed as `v0.4.0 Step EN: six horde enemies (12 behaviours)`, on parent `b110985`. Every
  run below was made on that working tree after its last code change; only this file, the screenshot and
  `tests/MIN_TEST_COUNT` changed after the runs (`bash scripts/ci/check_gut_log.sh build/gut.log` with the new
  minimum: `check_gut_log: ok (770 passing, minimum 770)`).

## 1. What was built (rules: SIM_CONTRACTS §10c; params: CONTENT_SCHEMA §3)

| Kind | Behaviour | Starting values | Spawn mix |
|---|---|---|---|
| **Swarmer** | The Charger's charge as a short unbent lunge bite; arrives in packs | HP 8 (one sword slash: the first step deals 10), damage 5, 1 shard, 4.6 m/s, lunge 2 m at 12 m/s after a 24-30 tick lane | weight 3, tier 1, `pack` 8 |
| **Splitter** | Swipes a disc 0.9 m ahead (r 1.1 m); on death splits into 2 Splitlings, once | HP 50, damage 12, 3 shards, 2.4 m/s, windup 27-40 ticks | weight 2, tier 1 |
| (Splitling) | The same swipe, smaller (r 0.7 m, 0.6 m ahead); never splits | HP 16, damage 6, 1 shard, 3.4 m/s, windup 24-36 ticks | (from Splitters only) |
| **Shield Bearer** | Blocks every hit from its front 120 deg (multiplier 0, `TAG_BLOCKED`; a bolt ends on it), sides/back full; turns 80 deg/s while walking; bashes a lane (1.6 m past its body, 0.6 m half-width) only at a player in its shield arc | HP 90, damage 18, 6 shards, 1.4 m/s, windup 30-40 ticks | weight 2, tier 2 |
| **Mender** | Keeps 6-9 m; heals the most hurt ally within 7 m through a beam (`HEAL` events); no attack; marked as the priority target (a spinning green cross) | HP 35, 5 shards, 2.8 m/s, 5 HP every 0.5 s | weight 1, tier 3 |
| **Mine Layer** | Keeps 4-7 m; drops a mine (0.5 s drop) every 2.5 s, at most 3, each lasting 20 s; a mine arms when the player touches its 1.5 m circle and blows 36 ticks later (its telegraph, the filling circle) | HP 40, damage 18, 4 shards, 2.4 m/s | weight 2, tier 2 |
| **Sniper** | Keeps 10-14 m; a 20 m line shown 60 ticks, following the player until its last 24; a hit down the drawn line; then walks (1.5x speed) to a spot 45-90 deg around the player before it fires again | HP 30, damage 28, 5 shards, 2.6 m/s | weight 1, tier 2 |

All values are **starting values** for the owner to tune (Charger 45 HP / 20 damage, Needle 30 / 8, Warden 100 / 25 as
the reference). `SpawnMixEntry.pack` is new (>= 1): a pack arrives in a 0.8 m ring around one spawn point and is cut
to the alive cap (at the current caps, 5 at tier 1, a Swarmer pack is at most 5 until SC's bigger caps land).

Also: code-built models (`HordeAvatar`, one class for the six kinds, flash materials from `ActorViews.flashable`,
nothing toggles `emission_enabled`), `HordeVisuals` (mines on the floor with their faint circle, the Mender's beam,
the Sniper's tracer), telegraph styles (`snipe`: the bolt's bright core; `bash`: two chevrons; `mine`: a turning
spiked star in each armed circle), eleven synthesised sounds (six deaths, `sniper_shot`, `mine_arm`, `mine_blast`,
`shield_bash`, `mender_heal`; the Splitling reuses the hatchling's death), death-recap causes (`CAUSE_SWARMER`,
`CAUSE_SPLITTER` for both splitter kinds, `CAUSE_SHIELD_BEARER`, `CAUSE_MINE_LAYER`, `CAUSE_SNIPER`; the Mender deals
no damage), names and causes in en + es, and the dev panel's Next enemy / Spawn enemy route (it lists every enemy
table, so the seven new kinds appear with no panel change).

**Cost per tick (SC runs concurrently):** no new per-tick O(n^2): the Mender scans for a patient every 15 ticks
(staggered by id) and otherwise checks one id; mines are a short list scanned once a tick without allocating per
mine; the Splitter's split happens once at death. The existing `spread_push` is unchanged.

## 2. Full suite, lint, import

```
$ godot --headless --path . --editor --import --quit
(no ERROR or SCRIPT ERROR lines in the log)
$ gdformat --check src scripts tests
387 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
$ bash scripts/verify.sh
...
Totals
------
Scripts             128
Tests               770
Passing Tests       770
Asserts           417798
Time              542.506s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (770 passing, minimum 735)
```
`tests/MIN_TEST_COUNT` 735 -> 770.

New tests: `tests/unit/sim/test_horde_enemies.gd` (23: each behaviour, the pack, parity for the line, bash, swipe
and mine disc, determinism, readable cause), `tests/unit/presentation/test_horde_avatars.gd` (8),
`tests/e2e/test_e2e_horde_enemies.gd` (2), and horde cases added to `tests/content/test_enemy_validation.gd` and
`test_spawning_validation.gd`. Updated expectations (counts that grew with the new content): enemy count 6 -> 13,
mix size 5 -> 11, unlocked kinds per tier (`test_spawn_director.gd`), shards per kind (`test_rewards.gd`).

## 3. Readable cause (no damage without a readable cause)

`tests/unit/sim/test_readable_cause.gd` passes inside the suite above, unchanged (its hit bar `damage > 20` and the
telegraph minimum untouched). `tests/support/readable_cause.gd` needed no change: the horde kinds' causes come from
`EndPanel.CAUSES` by kind, an armed mine is its layer's telegraph (the damage's owner), and the Sniper's hit is
checked against its 60-tick line. The horde-only fight in `test_horde_enemies.gd` (six seeds x 2400 ticks, the
fighting bot, refilled to 8 enemies), from the verify log:
```
    HORDE_CAUSES { "CAUSE_SNIPER": 12, "CAUSE_SHIELD_BEARER": 8, "CAUSE_MINE_LAYER": 6, "CAUSE_SWARMER": 2, "CAUSE_SPLITTER": 4 }
```
(32 hits, 0 violations: the test fails on any.) The 12-seed x 3-floor check:
```
$ godot --headless --path . -s scripts/checks/readable_cause.gd
{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_ARC_CASTER": 24,
		"CAUSE_BOSS_ARENA": 25,
		"CAUSE_BROOD_BROOD": 2,
		"CAUSE_BROOD_BURROW": 57,
		"CAUSE_BROOD_LEAP": 7,
		"CAUSE_CHARGER": 98,
		"CAUSE_GATEKEEPER_CHARGE": 7,
		"CAUSE_GATEKEEPER_LANES": 7,
		"CAUSE_GATEKEEPER_SLAM": 5,
		"CAUSE_GATEKEEPER_SWEEP": 41,
		"CAUSE_HATCHLING": 36,
		"CAUSE_NEEDLE": 97,
		"CAUSE_SIEGE_BARRAGE": 33,
		"CAUSE_SIEGE_BOLTS": 37,
		"CAUSE_SIEGE_RAIL": 33,
		"CAUSE_SPLITTER": 11,
		"CAUSE_SWARMER": 5,
		"CAUSE_WARDEN": 38
	},
	"damage_to_player": 563,
	"death_recap_mismatches": [],
	"deaths_checked": 22,
	"floor_ticks": 3600,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}
```
(exit 0.) 3600 floor ticks reach tier 1 only (Swarmers, Splitters). The longer run reaches tier 2 (Shield Bearer,
Mine Layer, Sniper); the Mender (tier 3) deals no damage:
```
$ godot --headless --path . -s scripts/checks/readable_cause.gd -- seeds=12 floor_ticks=5400 boss_ticks=3600
{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_ARC_CASTER": 55,
		"CAUSE_BOMB_DRONE": 11,
		"CAUSE_BOSS_ARENA": 95,
		"CAUSE_BROOD_BROOD": 6,
		"CAUSE_BROOD_BURROW": 46,
		"CAUSE_BROOD_LEAP": 6,
		"CAUSE_CHARGER": 133,
		"CAUSE_GATEKEEPER_CHARGE": 9,
		"CAUSE_GATEKEEPER_LANES": 6,
		"CAUSE_GATEKEEPER_SLAM": 4,
		"CAUSE_GATEKEEPER_SWEEP": 29,
		"CAUSE_HATCHLING": 25,
		"CAUSE_MINE_LAYER": 5,
		"CAUSE_NEEDLE": 122,
		"CAUSE_SHIELD_BEARER": 1,
		"CAUSE_SIEGE_BARRAGE": 31,
		"CAUSE_SIEGE_BOLTS": 53,
		"CAUSE_SIEGE_DEPLOY": 3,
		"CAUSE_SIEGE_RAIL": 36,
		"CAUSE_SNIPER": 2,
		"CAUSE_SPLITTER": 32,
		"CAUSE_SWARMER": 7,
		"CAUSE_WARDEN": 98
	},
	"damage_to_player": 815,
	"death_recap_mismatches": [],
	"deaths_checked": 22,
	"floor_ticks": 5400,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}
```
(exit 0.)

## 4. Reached in the real game

`tests/e2e/test_e2e_horde_enemies.gd` (in the suite): boots `main.tscn`, a Gun run from the menu, backtick opens the
dev panel, mouse clicks on God, Next enemy (until the panel names the kind) and Spawn enemy. The Swarmer, Splitter,
Shield Bearer (style `bash`) and Sniper (style `snipe`) each show their telegraph and land a HIT on the player; the
Mine Layer's mine is drawn on the floor, the left stick walks the player onto it, its armed circle (style `mine`) is
drawn and it blows on the player. A second test spawns a Mender and a Splitter, shoots the Splitter (mouse aim, right
button held) until it is hurt, and sees the Mender's beam drawn and a HEAL from it to the Splitter. On a normal run
the kinds arrive from the spawner at tiers 1-3 (`tests/content/test_spawning_validation.gd`).

**An e2e changed, named here:** `tests/e2e/test_e2e_heat.gd` failed on this tree (`heat peak 43.0, ready false at
tick 9009`; on `b110985` it passes, `ready true at tick 5760`). Its bot walks to the nearest enemy and swings; with
the new mix the nearest was often a Shield Bearer (every frontal swing blocked: no damage, no heat) or a kind that
backs off, and heat (a swing landing at least every 1 s) never built past Hot + 8. The test now skips Shield Bearers
as targets and has the dev panel (already open for God mode) bring in a Warden next to the player whenever none is
alive (at most 12). Its assertions are unchanged; from the verify log: `heat peak 52.5, ready true at tick 513`.

## 5. Goldens, sounds, export smoke

No golden changed. The new state is hashed only where it is used: `MineStore` only once a mine was dropped; the
horde kinds use the existing actor fields (`pick` holds the Mender's patient id and the Sniper's relocating flag).
```
$ python3 scripts/audio/generate_sfx.py --check
...
0 difference(s)
```
(the 58 existing files byte-identical; eleven new files and their manifest entries.)
```
$ bash scripts/ci/export_smoke.sh
...
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ...
  ok    audio cues: 69
  ok    every cue's sound loads from the pack (missing: [])
  ...
0 miss(es)
```
(exit 0.)

## 6. Screenshot

[`horde_enemies.png`](horde_enemies.png), rendered with
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/horde_enemies.gd`
(software Vulkan, llvmpipe) and copied by hand from `build/shots/v0.3.0-dev/enemies/horde_enemies.png`. Top row: a
Swarmer pack with their bite lanes, a Splitter's swipe beside two Splitlings, a Shield Bearer's bash lane with its
chevrons. Bottom row: a Mender's green beam on a hurt Shield Bearer, an armed mine filling under the player beside
its Mine Layer, a Sniper's line across the room. Look: **OWNER ONLY**.

## 7. Gaps

- The models have no concept sheet; they are the agent's reading of the enemy style (ART_DIRECTION "Horde enemies").
- A Swarmer pack is cut to the alive cap, so at today's caps (3 + 2 per tier, max 14) packs are small; SC's caps
  (14/30/50 + 6 per tier) are what make packs of 8 common.
- The Mender's "priority target" is a visual mark only; nothing in the sim targets it first (no auto-targeting
  ability exists yet; BS's auto abilities could use `EnemyAi.is_priority`).
- A Sniper whose line is cut by a wall still fires down the cut line (as the Arc Caster's bolt).
- `ActorStore.Kind` gains seven kinds after `BOMB_DRONE`; BO's bosses are appended concurrently, so merging the two
  steps needs one order of the enum (both append; nothing is renumbered within either step).
- Feel, difficulty and the starting values: **OWNER ONLY** (playtest).
