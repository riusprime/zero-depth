class_name StageScenario
extends RefCounted
## The Combat Lab room (v0.1.0): the v0.0.1 showcase walls, with one Charger, one Warden and one Needle.
## Step 5 replaces the fixed trio with waves.

const ARENA_HALF := 10.0


static func build(seed_value: int, player: PlayerTable, enemies: Array[EnemyTable] = []) -> World:
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
	if enemies.is_empty():
		return w
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(6.5, 6.0))
	w.add_enemy(ActorStore.Kind.WARDEN, Vector2(6.0, -6.5))
	w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(-6.5, 6.5))
	return w
