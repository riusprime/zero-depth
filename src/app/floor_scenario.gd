class_name FloorScenario
extends RefCounted
## The first floor (PLAN v0.2.0 F): a generated layout (FloorGenerator), the player at its start, the stone gate's
## footprint as a wall, continuous spawning over every room's spawn points (limited to the player's room and its
## neighbours by SpawnDirector), and one item pedestal per room except the start, drawn from the loot stream.


static func build(
	seed_value: int,
	player: PlayerTable,
	enemies: Array[EnemyTable],
	spawning: SpawnTable,
	items: Array[ItemTable]
) -> World:
	var layout := FloorGenerator.generate(seed_value)
	var w := World.new(seed_value, player, layout.start_pos)
	var walls: Array[Obb] = layout.walls.duplicate()
	walls.append(gate_collider(layout))
	w.set_walls(walls)
	w.floor_layout = layout
	w.set_enemy_tables(enemies)
	for pts in layout.spawn_points:
		w.spawn_points.append_array(pts)
	w.spawner = spawning
	w.set_item_tables(items)
	var draws := ItemPool.draw(w, layout.item_spots.size())
	for k in draws.size():
		w.add_pickup(draws[k], layout.item_spots[k])
	return w


## The gate's stone footprint: as deep as the gate, as wide as its pillars, so you can't walk through it.
static func gate_collider(layout: FloorLayout) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(layout.portal_pos, half, layout.portal_angle)
