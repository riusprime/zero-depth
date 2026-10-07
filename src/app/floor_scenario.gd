class_name FloorScenario
extends RefCounted
## The first floor (PLAN v0.2.0 F): a generated layout (FloorGenerator), the player at its start, the stone gate's
## footprint as a wall, continuous spawning over every room's spawn points (limited to the player's room and its
## neighbours by SpawnDirector), and item pedestals on the layout's item spots (1-2 per room, none in the start
## hall, PLAN L15), drawn from the loot stream. When the pool runs out, every room's first spot is filled before
## any second spot, and the rest stay empty.
## v0.3.0 B: a boss room off the farthest room (BossRoomBuilder, sized by `arena`), the gate inside it, and the boss
## flow (BossFlow); on a run, the floor number and the carry from the floor before (RunState.prepare), applied before
## the loot is drawn.


static func build(
	seed_value: int,
	player: PlayerTable,
	enemies: Array[EnemyTable],
	spawning: SpawnTable,
	items: Array[ItemTable],
	arena: BossArenaSpec = null,
	run: RunState = null
) -> World:
	var layout := FloorGenerator.generate(seed_value)
	var spec := arena if arena != null else BossArenaSpec.new()
	BossRoomBuilder.attach(layout, spec)
	var w := World.new(seed_value, player, layout.start_pos)
	var walls: Array[Obb] = layout.walls.duplicate()
	walls.append(gate_collider(layout))
	w.set_walls(walls)
	w.prepare_wall(layout.boss_door_wall)
	w.floor_layout = layout
	w.set_enemy_tables(enemies)
	for pts in layout.spawn_points:
		w.spawn_points.append_array(pts)
	w.spawner = spawning
	w.set_item_tables(items)
	w.boss_flow = BossFlow.create(spec.boss_index)
	if run != null:
		run.prepare(w)
	var order := spot_order(layout)
	var draws := ItemPool.draw(w, order.size())
	for k in draws.size():
		w.add_pickup(draws[k], layout.item_spots[order[k]])
	return w


## Item spot indices in fill order: each room's first spot (in room order), then the second spots.
static func spot_order(layout: FloorLayout) -> PackedInt32Array:
	var first := PackedInt32Array()
	var second := PackedInt32Array()
	for i in layout.item_spots.size():
		if i > 0 and layout.item_rooms[i - 1] == layout.item_rooms[i]:
			second.append(i)
		else:
			first.append(i)
	first.append_array(second)
	return first


## The gate's stone footprint: as deep as the gate, as wide as its pillars, so you can't walk through it.
static func gate_collider(layout: FloorLayout) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(layout.portal_pos, half, layout.portal_angle)
