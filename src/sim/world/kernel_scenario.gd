class_name KernelScenario
extends RefCounted
## Seeded test worlds for the v0.0.1 kernel: the player, dummy movers that chase and shoot, and walls.
## Used by the replay golden, the export smoke, the kernel smoke and the bench. Pure sim code.

const ARENA_HALF := 15.0
## The v0.0.1 dash cooldown (0.8 s). The kernel worlds keep it when the game's dash slowed to 1.4 s (v0.3.5 K, owner
## F12), so the replay golden and the export smoke hash stay the cross-OS proof they were recorded as.
const KERNEL_DASH_COOLDOWN_TICKS := 48


## movers: dummy count; fire_period / life: ticks; inner_walls: walls besides the 4 arena edges.
static func build(
	seed_value: int, movers: int, fire_period: int, life: int, inner_walls: int
) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.player.dash_cooldown_ticks = KERNEL_DASH_COOLDOWN_TICKS
	w.dummy_fire_period = fire_period
	w.projectile_life = life
	var walls: Array[Obb] = []
	var e := ARENA_HALF + 0.5
	walls.append(Obb.make(Vector2(0.0, e), Vector2(e, 0.5), 0))
	walls.append(Obb.make(Vector2(0.0, -e), Vector2(e, 0.5), 0))
	walls.append(Obb.make(Vector2(e, 0.0), Vector2(0.5, e), 0))
	walls.append(Obb.make(Vector2(-e, 0.0), Vector2(0.5, e), 0))
	for i in inner_walls:
		var c := _point(w.rng_map, 12.0)
		if Kin.length(c) < 3.0:
			c += Vector2(4.0, 4.0)
		var half := Vector2(
			w.rng_map.range_int(50, 300) / 100.0, w.rng_map.range_int(20, 50) / 100.0
		)
		walls.append(Obb.make(c, half, w.rng_map.range_int(0, 4095)))
	w.set_walls(walls)
	for i in movers:
		var p := _point(w.rng_map, 13.0)
		if Kin.length(p) < 6.0:
			p = p.normalized() * 6.0 if p != Vector2.ZERO else Vector2(6.0, 0.0)
		w.add_dummy(p, 0.35, 10)
	return w


## The v0.0.1 golden scene: 20 movers, about 50 projectiles alive, 4 edge walls + 8 inner walls.
static func golden(seed_value: int) -> World:
	return build(seed_value, 20, 48, 120, 8)


static func _point(rng: RngStream, extent: float) -> Vector2:
	var span := int(extent * 100.0)
	return Vector2(rng.range_int(-span, span) / 100.0, rng.range_int(-span, span) / 100.0)
