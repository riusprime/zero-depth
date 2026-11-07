class_name RuinsRocksCompiler
extends RefCounted
## v0.11.0 O13b (ENEMIES.md R1-R4, approved 2026-11-07; owner Q22): the Ruins' and the Night Rocks' signature enemies in
## the sim's units (RuinsRocks runs them). ContentCompiler compiles each one's shared numbers (HP, speed, its one
## attack's windup, damage and cooldown, a keep-away band), then its own here. The Wire Weaver's post is a table of its
## own (extra_tables), made from the Weaver's: an actor with post_hp HP and no attack.

## A hidden Rock Lurker's wall is a square this share of its radius on each side, so its body's circle holds it whole
## (a hero's shot meets the body first; the enemies' shots, which pass their own side's bodies, meet the wall).
const HIDE_SHARE := 0.68


## A signature's own numbers onto its compiled table `t` (nothing for any other behaviour).
static func compile(def: EnemyDefinition, t: EnemyTable) -> void:
	var bp := def.behaviour_params
	var sp := def.attacks[0].shape_params if not def.attacks.is_empty() else {}
	match def.behaviour_id:
		&"wire_weaver":
			t.max_cables = int(bp["max_cables"])
			t.post_hp = int(bp["post_hp"])
			t.post_radius_m = float(bp["post_radius_m"])
			t.cable_period_ticks = maxi(
				1, SimTick.seconds_to_ticks(float(bp["cable_period_seconds"]))
			)
			t.reach_m = float(sp["length_m"])
			t.lane_half_m = float(sp["half_width_m"])
		&"scrap_hound":
			t.circle_m = float(bp["circle_m"])
			t.rear_half_arc = ContentCompiler.degrees_to_units(float(bp["rear_arc_degrees"]) * 0.5)
			t.stagger_ticks = maxi(1, SimTick.seconds_to_ticks(float(bp["stagger_seconds"])))
			t.charge_speed = float(sp["speed_mps"]) / SimTick.TICKS_PER_SECOND
			t.charge_distance_m = float(sp["length_m"])
		&"rock_lurker":
			t.wake_m = float(bp["wake_m"])
			t.rumble_m = float(bp["rumble_m"])
			t.hide_half_m = def.radius_m * HIDE_SHARE
			t.slam_radius_m = float(sp["radius_m"])
		&"stone_thrower":
			t.flight_ticks = maxi(1, SimTick.seconds_to_ticks(float(bp["flight_seconds"])))
			t.rock_ticks = maxi(1, SimTick.seconds_to_ticks(float(bp["rock_seconds"])))
			t.rock_half_m = float(bp["rock_half_m"])
			t.max_rocks = int(bp["max_rocks"])
			t.slam_radius_m = float(sp["radius_m"])


## The tables the signatures add beside their own (after `tables`, the compiled enemies): the Wire Weaver's post.
static func extra_tables(tables: Array[EnemyTable]) -> Array[EnemyTable]:
	var out: Array[EnemyTable] = []
	for t in tables:
		if t.kind == ActorStore.Kind.WIRE_WEAVER:
			out.append(RuinsRocks.post_table(t))
	return out
