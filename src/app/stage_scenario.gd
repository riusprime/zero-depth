class_name StageScenario
extends RefCounted
## The Combat Lab room (v0.1.0): the v0.0.1 showcase walls and an encounter of waves. Spawn slots ring the room
## (any slot inside a wall is dropped).

const ARENA_HALF := 10.0
const SLOT_RING := 7.8
const SLOTS := 16


static func build(
	seed_value: int,
	player: PlayerTable,
	enemies: Array[EnemyTable] = [],
	encounter: EncounterTable = null
) -> World:
	var w := World.new(seed_value, player)
	w.set_enemy_tables(enemies)
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
	for k in SLOTS:
		var p := Kin.dir(k * 4096 / SLOTS) * SLOT_RING
		var clear := true
		for wall in walls:
			if Collide.circle_vs_obb(p, 0.9, wall) != Vector2.ZERO:
				clear = false
				break
		if clear:
			w.spawn_points.append(p)
	w.encounter = encounter
	return w
