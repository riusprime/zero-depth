# v0.3.0 O — no damage without a readable cause (evidence)

- **Status:** RUN. **0 violations** in 514 hits on the player over 36 runs; 24 deaths, every recap line matched.
- **Build:** the working tree of workstream O on `5e24bf7`, before it was committed. Godot
  `4.7.2.stable.official.ed1daf0bf`, headless, on the shared 4-vCPU cloud container. **Date:** 2026-10-07.
  **Who ran it:** agent.

## The rule checked (`tests/support/readable_cause.gd`)
Every `DAMAGE` event whose target is the player must:
1. come from an attack whose telegraph (`WorldReader.telegraph`, the same function that resolves the hit, EI-07)
   was visible for at least `MIN_TELEGRAPH_TICKS` (24) before the hit — the burrow ripple, which marks where a
   boss is and not the area it hits, doesn't count; **or** be a projectile that was on screen for at least
   `PROJECTILE_MIN_TICKS` (24, a starting value) or was fired by an attack telegraphed for 24 ticks;
2. have an attacker, and a death-recap cause line (a boss attack's `cause_key`, else the enemy kind's
   `EndPanel.CAUSES` line) present in en and es.

Each run: a real floor of a run (built as Main builds it), `FightBot` (walks at the nearest enemy, swings close,
shoots far, strafes, dashes, uses its utility) for `floor_ticks` with the floor's spawning, then into the boss room
for `boss_ticks` against the floor's boss (or until it dies). HP is topped up after each tick so hits keep coming
(a test-side write); at the end the top-up stops at 1 HP and the run plays on until a hit kills, and the recap's
cause (`WorldReader.killer_cause_key` / `EndPanel.CAUSES`) must equal the cause of the killing hit. Seeds
9100–9111, floors 1–3, guard on even seeds and blink on odd ones.

The unit test `tests/unit/sim/test_readable_cause.gd` runs one seed per floor (1,200 + 2,400 ticks) in the suite,
and proves the checker isn't blind: an untelegraphed hit and a 2-tick-old untelegraphed bolt are reported, a
26-tick-old one isn't.

## Command
```
godot --headless --path . -s scripts/checks/readable_cause.gd -- seeds=12 floor_ticks=3600 boss_ticks=3600
```
(wrapped in `uptime; time …; echo exit=$?; uptime`).

## Raw output
```
 14:53:38 up  1:08,  0 user,  load average: 14.43, 20.40, 21.31
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_BROOD_BROOD": 17,
		"CAUSE_BROOD_BURROW": 53,
		"CAUSE_BROOD_LEAP": 1,
		"CAUSE_CHARGER": 65,
		"CAUSE_GATEKEEPER_CHARGE": 5,
		"CAUSE_GATEKEEPER_LANES": 10,
		"CAUSE_GATEKEEPER_SLAM": 8,
		"CAUSE_GATEKEEPER_SWEEP": 44,
		"CAUSE_HATCHLING": 36,
		"CAUSE_NEEDLE": 101,
		"CAUSE_SIEGE_BARRAGE": 55,
		"CAUSE_SIEGE_BOLTS": 36,
		"CAUSE_SIEGE_DEPLOY": 2,
		"CAUSE_SIEGE_RAIL": 38,
		"CAUSE_WARDEN": 43
	},
	"damage_to_player": 514,
	"death_recap_mismatches": [],
	"deaths_checked": 24,
	"floor_ticks": 3600,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}

real	8m44.219s
user	3m57.347s
sys	0m0.944s
exit=0
 15:02:22 up  1:16,  0 user,  load average: 13.32, 18.46, 20.45
```

## Notes
- All 15 cause lines in the data were hit at least once (11 boss attack lines, 4 enemy kinds); the Brood Mother's
  leap only once and the Siege Engine's turret deploy twice, so those two are thinly covered.
- Not covered: the hazards and punish moves the BX workstream is adding in parallel; this check will judge them
  once merged (run the command above).
- Owner's PC: not needed (the check is deterministic sim logic).
