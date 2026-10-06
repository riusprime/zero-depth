class_name CombatLab
extends RefCounted
## Test helpers: a world with the real compiled player and enemies from data/.


static func tables() -> Array[EnemyTable]:
	return ContentCompiler.compile_enemies(ContentRepository.load_all())


static func world(utility: int = PlayerTable.Utility.NONE) -> World:
	var t := PlayerTable.starting_values()
	t.utility = utility
	var w := World.new(11, t)
	w.set_enemy_tables(tables())
	return w


static func idle(w: World, n: int) -> void:
	for i in n:
		w.step(InputFrame.new())


## Steps until `cond.call(w)` or `limit` ticks; returns the ticks used (or -1).
static func until(w: World, cond: Callable, limit: int = 600) -> int:
	for i in limit:
		if cond.call(w):
			return i
		w.step(InputFrame.new())
	return -1


static func player_damage(w: World) -> Array:
	var out := []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
			out.append(e.amount_applied)
	return out
