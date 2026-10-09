class_name BossLab
extends RefCounted
## Test helpers for the bosses (v0.3.0 C): a CombatLab world with the real compiled bosses from data/.


static func tables() -> Array[BossTable]:
	return ContentCompiler.compile_bosses(ContentRepository.load_all())


static func world(seed_value: int = 11) -> World:
	var t := PlayerTable.starting_values()
	var w := World.new(seed_value, t)
	w.set_enemy_tables(CombatLab.tables())
	w.set_boss_tables(tables())
	return w


## The index of boss `id` in w.boss_tables.
static func table_index(w: World, id: StringName) -> int:
	for k in w.boss_tables.size():
		if w.boss_tables[k].id == id:
			return k
	return -1


## Spawns boss `id` at `pos`, past its intro (acting, hittable), facing +x. Returns its actor index.
static func ready_boss(w: World, id: StringName, pos: Vector2 = Vector2.ZERO) -> int:
	var aid := w.spawn_boss(table_index(w, id), pos)
	var i := w.actors.index_of(aid)
	w.actors.state[i] = EnemyAi.State.MOVE
	w.actors.state_t[i] = 0
	w.actors.invuln[i] = 0
	w.actors.facing[i] = 0
	return i


## Starts attack `attack_id` of the boss at index i (the aim locks on the player where it stands now). It runs alone:
## marked as a follow-up, so it never chains into another (BX); BossAi.start_attack itself lets it chain.
static func start(w: World, i: int, attack_id: StringName) -> void:
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(attack_id))
	w.bosses.chained[BossAi.entry_of(w, i)] = 1


static func boss_damage_to_player(w: World) -> Array:
	return CombatLab.player_damage(w)


## v0.5.5 DS: steps boss `aid` through the phase gate it is in (BossGates) and one tick more, so its new phase's entry
## attack has started.
static func through_gate(w: World, aid: int) -> void:
	for k in BossGates.GATE_TICKS + 2:
		var i := w.actors.index_of(aid)
		if i < 0 or w.actors.state[i] != BossAi.GATE:
			break
		w.step(InputFrame.new())
	w.step(InputFrame.new())
