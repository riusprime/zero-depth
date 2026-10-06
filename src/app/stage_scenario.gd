class_name StageScenario
extends RefCounted
## The v0.0.1 stage: the showcase room with two idle enemies for scale. Nothing shoots and nothing hurts yet.

const ARENA_HALF := 10.0


static func build(seed_value: int, player: PlayerTable) -> World:
	var w := World.new(seed_value, player)
	var walls: Array[Obb] = []
	walls.append(Obb.make(Vector2(0, 9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(0, -9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(9.5, 0), Vector2(0.4, 9), 0))
	walls.append(Obb.make(Vector2(-9.5, 0), Vector2(0.4, 9), 0))
	walls.append(Obb.make(Vector2(-3.2, -1.0), Vector2(1.6, 0.25), 512))
	walls.append(Obb.make(Vector2(3.5, 2.5), Vector2(0.25, 1.8), 0))
	walls.append(Obb.make(Vector2(-4.0, 4.0), Vector2(1.2, 0.25), 1280))
	walls.append(Obb.make(Vector2(5.0, -4.0), Vector2(2.0, 0.25), 512))
	w.set_walls(walls)
	w.dummy_speed = 0.0
	w.dummy_fire_period = 0
	w.add_dummy(Vector2(4.5, 4.0), 0.35, 10)
	w.add_dummy(Vector2(6.0, -1.5), 0.35, 10)
	return w
