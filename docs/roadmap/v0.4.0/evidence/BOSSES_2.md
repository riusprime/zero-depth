# v0.4.0 Step BO: a second boss in every pool (evidence)

PLAN: [`../PLAN.md`](../PLAN.md) "Bosses (BO)". Every number below was pasted from the command shown, run by the agent
in a cloud container (Linux, Godot 4.7.2-stable; headless unless noted). Feel, fun and the look against a future
sheet are `OWNER ONLY`.

- **Base:** `b110985` (`claude/lucid-fermat-9wv2tf`). **Build:** the working tree on top of it, committed as
  `v0.4.0 Step BO: a second boss in every pool`. This file is part of that commit, so its SHA is in the hand-off
  report. The suite below ran on the committed code, data and tests (this file and PROGRESS were still being written).

## 1. What was built

| Pool | Boss | HP | Radius | Arena (cells, template) | Phase 1 | Phase 2 (at 50 %) | Punish (9 m for 4 s) | Gap-closer (2 s) |
|---|---|---|---|---|---|---|---|---|
| Floor 1 | **Warlord** (shielded knight) | 1400 | 1.1 m | 3 x 2, open | Shield Bash (sweep 130°, 2.3 m), Spear Lines (3 parallel lanes, 2.4 m apart, 14 m), Lunge Dash (charge 16 m at 16 m/s) | opens with Spear Wall (5 lanes); +30 % speed, cooldowns x0.65 | Javelin Rain (6 shells, 1.6 m) | Lunge Dash beyond 5 m |
| Floor 2 | **Hive Lens** (floating eye) | 1650 | 1.0 m | 2 x 2, centre | Lens Sweep (rail 100°, 12 m), Prism Fan (5 bolts x 2 volleys), Glare Ring (1.2-3.6 m), Dive (leap 2.2 m) | opens with **Split** (deploy: three Lens Drones off its rim); Twin Sweep (rail 150°); +25 % speed, cooldowns x0.65 | Focus Beam (rail 70°, 30 m) | Dive beyond 5 m |
| Floor 3 | **Foundry** (walking furnace) | 1900 | 1.5 m | 3 x 2, bunkers | Molten Flood (3 lanes 3 m apart, 1.4 m wide, 16 m, burning 2 s), Slag Mortar (barrage of 4), Vent Blast (ring 0-4.2 m), Bomb Launch (2 Bomb Drones, at most 3 alive) | opens with Molten Flood x5; Bomb Launch x3 (at most 4 alive); speed x0.9, cooldowns x0.65 | Firestorm (7 molten lanes, 2 m wide, 26 m) | Slag Mortar beyond 10 m |

- **The framework, unchanged:** BossDefinition data, the stagger meter (220 / 240 / 300 points), phases with entry
  attacks, punish windows (recoveries x0.6), follow-ups, one shape function per attack, v0.3.5's tracking until the
  last 12 ticks, dash-landing aim (0.5 s) and lead (0.3 s); BX's ranged armour (40 % at 12 m), punish move, closing
  band (phase 2 or 45 s, 1 m per 6 s, warned 1.5 s) and weak point (x2 damage and stagger within 2.5 m for 2 s).
- **One new move, `flood`** (`BossAi.flood_lane_of`; CONTENT_SCHEMA §4): `count` parallel lanes `gap_m` apart, marked
  for the windup, then standing for the active time and hurting a player in them at most once per `burn_seconds`
  (0.5 s). The Warlord's spear lines and the Foundry's molten floor both use it; the view draws the standing lanes as
  spear heads or a hot core with cross bars.
- **The Warlord's shield:** front 140° takes 65 % (`front_mult_permille` 650), the rear 100° 125 %. New field
  `weak_point_drops_armour`: while its weak point is open (after Spear Lines, Spear Wall, Lunge Dash, Javelin Rain)
  the front armour is off (`Damage.target_mult`). Only the Warlord sets it.
- **The Hive Lens's split:** a `deploy` of a new enemy, the **Lens Drone** (`data/enemies/lens_drone.tres`: HP 45,
  2 pulses of 8, keeps 6 m, 3 shards), its own actor kind flying the Needle's rules (`EnemyAi.behaviour_of`).
- **The Foundry's Bomb Drones** are the existing v0.3.5 enemy, launched by the `brood` move (capped alive).
- **Telegraphs** are all at least 24 ticks (validation and the runtime test below); every attack names a recap cause
  (16 new lines, en + es: 15 for the bosses' attacks, one for the Lens Drone).
- **Views:** code-built `WarlordAvatar`, `HiveLensAvatar`, `FoundryAvatar` (BossAvatar subclasses, BossParts pieces:
  outlined, flashable through `ActorViews.flashable`, glows change energy only), `LensDroneAvatar`; posed from the boss
  state (the shield lifts on the weak point, the pods drift off in the split's windup and are gone after, the grate's
  door opens on the weak point). `model_id()` is `warlord` / `hive_lens` / `foundry`, so a later
  `assets/models/bosses/<id>.glb` replaces the body (whole-body motion until rigged).
- **Sounds** (`scripts/audio/generate_sfx.py`, five new recipes, generator v2 unchanged): `boss_telegraph_warlord`,
  `boss_telegraph_hive_lens`, `boss_telegraph_foundry` (captioned), `boss_floor_burst` (a flood's lanes bursting up),
  `enemy_death_lens_drone`; cues in `data/audio/cues`.
- **Real game:** each floor's pool now holds two (`data/boss_pools`), drawn per run from the `boss_<f>` stream. The dev
  panel's Next boss / Spawn boss reach all six (no panel code change). Boss bar names: "The Warlord", "The Hive Lens",
  "The Foundry" (es: "El Señor de la Guerra", "La Lente Enjambre", "La Fundición").
- **Image prompts** for the owner's reference sheets: [`../../../art/BOSSES_2.md`](../../../art/BOSSES_2.md).

## 2. Fight length (the bots of `tests/unit/sim/test_boss_fights.gd`)

The three bots (melee Blade, near Gun 4-6 m, far Gun 9.5-10.5 m from the edge; no items; HP raised so they live) now
also fight the three new bosses. **No band was changed** (melee 25-90 s, near 25-120 s, far >= 1.5 x melee).

First measurement (scratch probe `build/dbg/bo_fights.gd`, which calls the test's own `fight()`; first data:
Warlord front 500 ‰, Hive Lens HP 1500, Foundry HP 1700, Warlord spear lines from 2.5 m):

```
$ godot --headless --path . -s build/dbg/bo_fights.gd
FIGHT| warlord bot=0 ticks=3734 seconds=62.2 hits=158 deflected=0 exposed=7 punished=0 gap=0
FIGHT| warlord bot=1 ticks=3966 seconds=66.1 hits=544 deflected=0 exposed=0 punished=0 gap=0
FIGHT| warlord bot=2 ticks=6498 seconds=108.3 hits=896 deflected=652 exposed=24 punished=0 gap=17
FIGHT| hive_lens bot=0 ticks=1619 seconds=27.0 hits=68 deflected=0 exposed=26 punished=0 gap=0
FIGHT| hive_lens bot=1 ticks=3272 seconds=54.5 hits=455 deflected=0 exposed=0 punished=0 gap=0
FIGHT| hive_lens bot=2 ticks=7602 seconds=126.7 hits=1057 deflected=806 exposed=3 punished=1 gap=23
FIGHT| foundry bot=0 ticks=1793 seconds=29.9 hits=77 deflected=0 exposed=30 punished=0 gap=0
FIGHT| foundry bot=1 ticks=3663 seconds=61.0 hits=498 deflected=0 exposed=10 punished=0 gap=0
FIGHT| foundry bot=2 ticks=9244 seconds=154.1 hits=1220 deflected=1216 exposed=0 punished=36 gap=0
```

All already inside the bands. Two things were changed in the new bosses' own starting values, not in the bands: the
melee bot never struck the Warlord's weak point (`exposed=7`), because Spear Lines needed 2.5 m and a hugging player
only drew the bash, so the spear lines now fire from 0 m (fighting close opens the shield, the design); and the Hive
Lens's 27.0 s sat near the 25 s floor, so HP 1500 -> 1650 (and the Foundry 1700 -> 1900, the Warlord front 500 ->
650 ‰, so the floor-1 boss isn't the slowest to melee). Final numbers, from the suite run in §3:

```
BOSSFIGHT| warlord MELEE ticks=2057 seconds=34.3 hits=87 deflected=0 exposed=27 punished=0
BOSSFIGHT| warlord RANGED_NEAR ticks=3966 seconds=66.1 hits=544 deflected=0 exposed=0 punished=0
BOSSFIGHT| hive_lens MELEE ticks=1743 seconds=29.1 hits=74 deflected=0 exposed=31 punished=0
BOSSFIGHT| hive_lens RANGED_NEAR ticks=3582 seconds=59.7 hits=497 deflected=0 exposed=1 punished=0
BOSSFIGHT| foundry MELEE ticks=2059 seconds=34.3 hits=88 deflected=0 exposed=32 punished=0
BOSSFIGHT| foundry RANGED_NEAR ticks=4098 seconds=68.3 hits=555 deflected=0 exposed=11 punished=0
BOSSFIGHT| warlord RANGED_FAR ticks=5843 seconds=97.4 hits=805 deflected=591 punished=0 gap_closed=15
BOSSFIGHT| hive_lens RANGED_FAR ticks=8396 seconds=139.9 hits=1167 deflected=892 punished=1 gap_closed=25
BOSSFIGHT| foundry RANGED_FAR ticks=10322 seconds=172.0 hits=1361 deflected=1357 punished=39 gap_closed=0
```

| Boss | Melee (25-90 s) | Near (25-120 s) | Far | Far / melee (>= 1.5) |
|---|---|---|---|---|
| Warlord | 34.3 s | 66.1 s | 97.4 s | 2.8x |
| Hive Lens | 29.1 s | 59.7 s | 139.9 s | 4.8x |
| Foundry | 34.3 s | 68.3 s | 172.0 s | 5.0x |

- Every boss is beaten by both builds (the melee bot is a Blade run, both shooters Gun runs: L15/L16), within the bands.
- The first three bosses' lines in the same run are unchanged from v0.3.5's (`gatekeeper MELEE 33.5`, `brood_mother
  RANGED_NEAR 106.3`, `siege_engine RANGED_FAR 158.6`, ...).
- The Hive Lens melee time (29.1 s) is the closest to a band edge (25 s). These bots never dodge and never miss: the
  times are perfect-uptime floors. Whether real fights land in 60-120 s: `OWNER ONLY` (playtest).
- The far bot is answered by the gap-closer (Warlord, Hive Lens) or the punish (Foundry: its gap-closer needs more
  than 10 m for 2 s, which a bot holding 9.5-10.5 m keeps resetting, so the 4 s punish beyond 9 m answers it).

## 3. Full suite

```
$ bash scripts/verify.sh
...
REPLAY| final=5171fdadd6442c3e5c568273b2fcb361fa5f19fddd3e922231fe6c4bb3d841ae
...
Totals
------
Scripts             128
Tests               769
Passing Tests       769
Asserts           417893
Time              456.326s

---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (769 passing, minimum 735)
```

`tests/MIN_TEST_COUNT` 735 -> 769. Lint: `gdformat --check src scripts tests` -> `386 files would be left unchanged`;
`gdlint src scripts tests` -> `Success: no problems found`. The hand-off report pastes the rerun from a clean worktree
of the commit.

New tests (34):
- `tests/unit/sim/test_bosses_2.gd` (19): two bosses per pool; 40 runs per floor meet both (and a run always meets the
  same); the new kinds are bosses and the drone isn't; arenas from data; every attack of the three telegraphs >= 24
  ticks before it lands on a player who stays put; flood lanes parallel, `gap_m` apart, the middle one on the player,
  five in the wall; the molten floor stays drawn ("molten") through the active time and burns again, at most once per
  period; a spear kill shows spear marks and names `CAUSE_WARLORD_SPEARS`; the Warlord's shield (650 ‰ front, 1250 ‰
  rear) is off while its weak point is open and back after, and the Gatekeeper keeps its armour; the Hive Lens opens
  phase 2 with the split (marked discs) and three drones come, once; Lens Drones mark their shots and fire, through
  `behaviour_of`; the Foundry's launches cap at three alive; its phase 2 opens with five molten lanes; the anti-kite
  rules on each (ranged armour, punish, gap-closer, closing band, weak point, tracking, dash reading, >= 2 openers);
  staying far brings the punish; flood windups track, then hold for the last 12 ticks; recap causes; determinism
  (two runs, same hash, each boss); readable cause against each in its real boss room (below).
- `tests/unit/presentation/test_bosses_2_views.gd` (12): flashable outlined pieces (emission on at energy 0) and
  X-ray twins; the Lens Drone hovers over its ground shadow; windup and stagger poses; the shield lifts on the weak
  point; the pods split off; the Foundry's door opens; the weak point glows by energy only; ActorViews picks each model
  and the drone's; the standing flood lanes are drawn styled (spears, molten); **the drawn flood lanes are the hit
  area** (a player just inside an edge lane is hit, just outside is not; EI-07); each boss's telegraph cue and file,
  the flood's burst, the drone's death sound and recap; the boss bar names each (translated).
- `tests/e2e/test_e2e_bosses_2.gd` (3): drives `main.tscn` with input events only: backtick opens the dev panel, mouse
  clicks God, Next boss until the panel names the boss, and Spawn boss; the boss appears with its own model and its
  name on the HUD's bar, and its telegraph is drawn and its attack reaches the player (a HIT from it).
- Changed: the boss and enemy counts (6 and 7), the pool test (two per floor, the first still there), the fight
  test's boss list (six), `test_boss_views`'s model table, the rewards table (Lens Drone 3 shards),
  `test_boss_pressure`'s v0.3.0-speed check (skips the new bosses, made at the faster speeds).

## 4. Readable cause (no damage without a readable cause)

The 12-seed x 3-floor check, on the final tree (the 12 run seeds draw all six bosses):

```
$ godot --headless --path . -s scripts/checks/readable_cause.gd
{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_ARC_CASTER": 23,
		"CAUSE_BOMB_DRONE": 39,
		"CAUSE_BOSS_ARENA": 45,
		"CAUSE_BROOD_BROOD": 1,
		"CAUSE_BROOD_BURROW": 19,
		"CAUSE_BROOD_LEAP": 3,
		"CAUSE_CHARGER": 110,
		"CAUSE_FOUNDRY_FLOOD": 27,
		"CAUSE_FOUNDRY_LAUNCH": 2,
		"CAUSE_FOUNDRY_SLAG": 5,
		"CAUSE_FOUNDRY_VENT": 26,
		"CAUSE_GATEKEEPER_CHARGE": 3,
		"CAUSE_GATEKEEPER_LANES": 4,
		"CAUSE_GATEKEEPER_SLAM": 2,
		"CAUSE_GATEKEEPER_SWEEP": 16,
		"CAUSE_HATCHLING": 14,
		"CAUSE_HIVE_DIVE": 2,
		"CAUSE_HIVE_GLARE": 33,
		"CAUSE_HIVE_PRISM": 3,
		"CAUSE_HIVE_SPLIT": 1,
		"CAUSE_HIVE_SWEEP": 46,
		"CAUSE_LENS_DRONE": 8,
		"CAUSE_NEEDLE": 95,
		"CAUSE_SIEGE_BARRAGE": 20,
		"CAUSE_SIEGE_BOLTS": 32,
		"CAUSE_SIEGE_DEPLOY": 2,
		"CAUSE_SIEGE_RAIL": 16,
		"CAUSE_WARDEN": 52,
		"CAUSE_WARLORD_BASH": 17,
		"CAUSE_WARLORD_DASH": 1,
		"CAUSE_WARLORD_SPEARS": 20
	},
	"damage_to_player": 687,
	"death_recap_mismatches": [],
	"deaths_checked": 24,
	"floor_ticks": 3600,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}
```

(exit 0.) The in-suite check per new boss (`test_every_hit_from_the_new_bosses_has_a_readable_cause`, its real
floor, the first run seed from 9100 whose pool draws it):

```
BO_CAUSE| warlord seed=9100 ticks=1989 hits=5 violations=0 by_cause={ "CAUSE_WARLORD_DASH": 1, "CAUSE_WARLORD_BASH": 2, "CAUSE_WARLORD_SPEARS": 2 }
BO_CAUSE| hive_lens seed=9100 ticks=3600 hits=17 violations=0 by_cause={ "CAUSE_HIVE_PRISM": 2, "CAUSE_HIVE_GLARE": 7, "CAUSE_HIVE_SWEEP": 4, "CAUSE_BOSS_ARENA": 4 }
BO_CAUSE| foundry seed=9102 ticks=3600 hits=25 violations=0 by_cause={ "CAUSE_FOUNDRY_VENT": 4, "CAUSE_BOMB_DRONE": 17, "CAUSE_FOUNDRY_FLOOD": 4 }
```

**A problem found and fixed on the way:** the Warlord first had the CROSS arena template. In a real floor its boss
room's cross wall stood between the door and the boss, and neither the bot nor the boss got round it: 3600 ticks,
0 hits, the boss never touched (scratch probe `build/dbg/bo_rc.gd`). The Warlord's arena is now OPEN (3 x 2), and
the test above guards it. The 12-seed check was run once before that change (also `violations: 0`, only
`CAUSE_WARLORD_DASH` missing) and again after it (pasted above).

## 5. Sounds, export smoke, goldens

```
$ python3 scripts/audio/generate_sfx.py --check
...
0 difference(s)
```
(63 files; the 58 earlier files byte-identical, five new files and their manifest entries.)

```
$ bash scripts/ci/export_smoke.sh
manifest: dd3eb57f83d63f3bf03da64baba270612094f77f352d5e80aa481d5524fe5614 (130 files, 0 errors)
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ...
  ok    audio cues: 63
  ok    every cue's sound loads from the pack (missing: [])
  ...
0 miss(es)
```
(exit 0.) **No golden changed.** The replay hash is the one v0.3.0 C pasted (`5171fdad...`), the export smoke's world
hash matches, and the boss state (hashed only in worlds with boss tables) has no new fields: the flood reuses
`BossStore`'s points and hit flag. Boss table indices did shift (the compiled bosses are in id order: brood_mother,
foundry, gatekeeper, hive_lens, siege_engine, warlord), which only worlds with a boss flow hash; no golden has one.

## 6. Screenshot

```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --audio-driver Dummy --resolution 1600x900 -s scripts/shots/bosses.gd -- mode=sheet set=2
bosses: res://build/shots/v0.3.0-dev/bosses/bosses_2.png cells=warlord idle, warlord spear_lines@active, warlord lunge_dash, hive_lens idle, hive_lens lens_sweep@active, hive_lens split@half, foundry idle, foundry molten_flood@active, foundry bomb_launch
```

[`bosses_2.png`](bosses_2.png) is that file (1680 x 1200, 378,574 bytes) scaled to 75 % and quantised to 256 colours
by hand (172,439 bytes): the game view (Ruins stage, iso camera, ActorViews, TelegraphViews) of a real World. Rows:
the Warlord idle, its spear lines standing (a lane cut short by a wall), its lunge's lane; the Hive Lens idle, its
beam sweeping, its split (pods drifting off, the drones' landing discs); the Foundry idle, its molten lanes burning
(the grate flaring), its Bomb Drone launch discs.

Agent's reading: the three silhouettes read apart (a knight with a shield and a crest, a red-eyed sphere, a box
furnace with chimneys); the spear heads and the molten bars read as standing hazards. The Warlord's spear is held
upright at rest and reads thin. Look and verdict: `OWNER ONLY`.

## 7. Gaps

- No reference sheets yet: the models are the agent's reading of the prompts in `docs/art/BOSSES_2.md`.
- The fight times are perfect-uptime bot floors; the 60-120 s target with a real player is `OWNER ONLY`.
- The Hive Lens's split spawns three drones beside the eye; the eye itself stays one body (it does not become a
  drone). The pods vanish from the model when the drones appear.
- The Lens Drone flies the Needle's rules (only its look and numbers are its own).
- The Foundry's "molten floor" hurts on a 0.5 s period, not continuously; it leaves no lasting hazard after the
  attack ends.
- Not rendered: the X-ray silhouettes behind walls and the models at the owner's resolution (`OWNER ONLY`).
