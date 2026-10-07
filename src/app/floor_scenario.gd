class_name FloorScenario
extends RefCounted
## The first floor (PLAN v0.2.0 F): a generated layout (FloorGenerator), the player at its start, the stone gate's
## footprint as a wall, continuous spawning over every room's spawn points (limited to the player's room and its
## neighbours by SpawnDirector).
## v0.3.0 B: a boss room off the farthest room (BossRoomBuilder, sized by `arena`), the gate inside it, and the boss
## flow (BossFlow); on a run, the floor number and the carry from the floor before (RunState.prepare).
## v0.3.0 E: the floor's free altars and shard chests on the layout's item spots (Rewards.place: one per room while
## rooms last, never in the start hall or the boss room, which has no item spots), placed after the carry so no
## card offers an item you hold. v0.2.0's item pedestals are gone: items come from an altar's or chest's pick.


static func build(
	seed_value: int,
	player: PlayerTable,
	enemies: Array[EnemyTable],
	spawning: SpawnTable,
	items: Array[ItemTable],
	rewards: RewardTable = null,
	floor_index: int = 1,
	arena: BossArenaSpec = null,
	run: RunState = null,
	combos: Array[ComboTable] = []
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
	w.set_combo_tables(combos)  # v0.3.0 G: named combos, set before the run's carry restores the owned ones.
	w.boss_flow = BossFlow.create(spec.boss_index)
	if rewards != null:
		w.reward_table = rewards
	w.floor_index = floor_index
	if run != null:
		run.prepare(w)
	Rewards.place(w, layout)  # after the carry, so no card offers an item you hold
	return w


## Item spot indices in fill order: each room's first spot (in room order), then the second spots.
static func spot_order(layout: FloorLayout) -> PackedInt32Array:
	return Rewards.spot_order(layout)


## The gate's stone footprint: as deep as the gate, as wide as its pillars, so you can't walk through it.
static func gate_collider(layout: FloorLayout) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(layout.portal_pos, half, layout.portal_angle)
