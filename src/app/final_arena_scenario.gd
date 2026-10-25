class_name FinalArenaScenario
extends RefCounted
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F1-F3): the final arena's World, the run's last after the Ascension portal
## (v0.8.0 P2; End the run before). Its floor is FinalArena's round room (its radius and segments from the
## FinalArenaDefinition), the hero arriving on the +y side (the portal transit's arrival), the floor's tables as any
## floor (the run's carry, curses, heat, the hidden catch-up: Main sets them as on every floor), no spawner, rewards,
## shop, events or gate. Its boss flow only runs the arrival (its state is FIGHT from the start, no door, no portal).
## The bosses are the floors' (so every saved index means what it did) and then the final boss's bodies, scaled as a
## boss of the loop's last floor (RunState.scale_bosses: the loop's factor too, F7 for the Colossus; the Prism's and
## the Nemesis's own rules are FB2's and FB3's). begin() starts the fight once Main has set the loadout (the first
## body's rise counts the hidden catch-up).
## v0.9.0 FA (owner C §3: "The player should no longer teleport directly into the final boss arena"; Q18): with
## `approach` (the run's way in, FloorPlan) the floor is the final approach (FinalArena.approach_layout: the stair
## causeway up to the plateau, which is the arena) and World.approach runs the pylons and the buildup; the fight begins
## when the buildup ends (FinalApproach.advance), not at begin(). Without it (the tests' and tools' direct path, and a
## save made in the final arena before FA) the ring arena with the fight from the start, as before.


static func build(
	run: RunState,
	arena: FinalArenaDefinition,
	player: PlayerTable,
	enemies: Array[EnemyTable],
	items: Array[ItemTable],
	combos: Array[ComboTable],
	bosses: Array[BossTable],
	finals: Array[BossTable],
	approach: bool = false
) -> World:
	var seed_value := final_seed(run)
	var layout := (
		FinalArena.approach_layout(seed_value, arena.radius_m, arena.segments)
		if approach
		else FinalArena.layout(seed_value, arena.radius_m, arena.segments)
	)
	var w := World.new(seed_value, player, layout.start_pos)
	w.set_walls(layout.walls)
	w.floor_layout = layout
	w.set_enemy_tables(enemies)
	w.set_item_tables(items)
	w.set_combo_tables(combos)
	var all: Array[BossTable] = []
	all.append_array(bosses)
	all.append_array(finals)
	w.set_boss_tables(all)
	w.boss_flow = BossFlow.create(-1)
	w.floor_index = run.floor_index
	run.prepare(w)
	w.boss_flow.ascension = false
	w.boss_flow.deep = false
	w.boss_flow.final_next = false
	w.boss_flow.state = BossFlow.State.FIGHT  # no door to seal: the fight is the room
	w.boss_flow.sealed_tick = 0
	if approach:  # v0.9.0 FA: the pylons, then the buildup, then the fight
		w.approach = FinalApproach.create(
			body_tables(w, finals.size()), run.table.final_shatter_ticks, run.table.final_name_key
		)
		w.approach.register(w)  # v0.9.0 IX: the pylons are shared interactables
	return w


## The final arena's seed: derived from the run seed and the run's floor it was reached from.
static func final_seed(run: RunState) -> int:
	return RngStream.derive(run.run_seed, "final_%d" % run.run_floor()).next_u32()


## The fight's bodies' indices into World.boss_tables (after the floors' bosses).
static func body_tables(w: World, finals: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in finals:
		out.append(w.boss_tables.size() - finals + k)
	return out


## Starts the fight: the first body rises at the arena's centre (FinalBoss.begin).
static func begin(w: World, run: RunState, finals: int) -> void:
	FinalBoss.begin(
		w, body_tables(w, finals), run.table.final_shatter_ticks, w.floor_layout.boss_spawn
	)
	w.final_fight.name_key = run.table.final_name_key
