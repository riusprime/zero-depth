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
	for j in [i, BossTwin.partner_of(w, i)]:  # v0.9.0 NB2: the Twin Wardens' twin rises with it
		if j < 0:
			continue
		w.actors.state[j] = EnemyAi.State.MOVE
		w.actors.state_t[j] = 0
		w.actors.invuln[j] = 0
		w.actors.facing[j] = 0
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


## v0.7.5 BF1: steps the world until boss `aid`'s shield is down (its signature pattern over), at most `limit` ticks.
static func until_open(w: World, aid: int, limit: int = 900) -> void:
	for k in limit:
		var i := w.actors.index_of(aid)
		if i < 0 or not BossDodge.shielded(w, i):
			return
		w.step(InputFrame.new())


## v0.7.5 BF1: appends attack `def` (compiled) to boss `id`'s table in this world and returns its index. The tests of
## a move no shipped boss uses any more (the Gatekeeper's old vortex) build it here.
static func with_attack(w: World, id: StringName, def: BossAttackDefinition) -> int:
	var t := w.boss_tables[table_index(w, id)]
	var atk := ContentCompiler.compile_boss_attack(def, ContentRepository.load_all())
	atk.opens_weak = def.opens_weak_point
	atk.recover_ticks = atk.recover_ticks * 600 / 1000
	t.attacks.append(atk)
	return t.attacks.size() - 1


## v0.7.5 BF1: the Gatekeeper's vortex slam before BF1 (the pull move's test fixture; its v0.3.0 BX numbers).
static func vortex_def() -> BossAttackDefinition:
	var d := BossAttackDefinition.new()
	d.id = &"vortex_slam"
	d.shape = AttackDefinition.Shape.RING
	d.shape_params = {"inner_radius_m": 0.0, "pull_mps": 5.5, "pull_range_m": 30.0, "radius_m": 4.5}
	d.telegraph_seconds = 1.3
	d.active_seconds = 0.0167
	d.recovery_seconds = 1.5
	d.damage = 24
	d.move = &"pull"
	d.cause_key = &"CAUSE_GATEKEEPER_PULL"
	d.opens_weak_point = true
	return d


## v0.7.5 BF3: the Siege Engine's v0.7.0 attacks that BF3 replaced (a scattered barrage, the rail sweep, the fast
## bolt fan), as fixtures for the tests of their moves (the Hive Lens's own may change in BF2). Their v0.7.0 numbers.
static func siege_v070_def(attack_id: StringName) -> BossAttackDefinition:
	var d := BossAttackDefinition.new()
	d.id = attack_id
	d.active_seconds = 0.0167
	d.min_range_m = 0.0
	match attack_id:
		&"barrage_7":
			d.shape = AttackDefinition.Shape.CIRCLE
			d.shape_params = {"count": 7, "radius_m": 1.6, "spread_m": 4.0}
			d.telegraph_seconds = 1.0
			d.recovery_seconds = 0.6
			d.damage = 20
			d.move = &"barrage"
			d.max_range_m = 30.0
			d.cause_key = &"CAUSE_SIEGE_BARRAGE"
		&"rail_sweep":
			d.shape = AttackDefinition.Shape.CONE
			d.shape_params = {"arc_degrees": 110.0, "reach_m": 13.0}
			d.telegraph_seconds = 1.0
			d.active_seconds = 1.2
			d.recovery_seconds = 1.2
			d.damage = 28
			d.move = &"rail"
			d.max_range_m = 13.0
			d.cause_key = &"CAUSE_SIEGE_RAIL"
			d.opens_weak_point = true
		&"bolt_fan":
			d.shape = AttackDefinition.Shape.PROJECTILE
			d.shape_params = {
				"count": 7,
				"gap_seconds": 0.25,
				"radius_m": 0.16,
				"range_m": 16.0,
				"speed_mps": 10.0,
				"spread_degrees": 10.0,
				"volleys": 3
			}
			d.telegraph_seconds = 0.7
			d.active_seconds = 0.75
			d.recovery_seconds = 0.6
			d.damage = 10
			d.move = &"bolt_fan"
			d.max_range_m = 16.0
			d.cause_key = &"CAUSE_SIEGE_BOLTS"
			d.opens_weak_point = true
		_:
			return null
	return d


## v0.7.5 BF3: makes sure boss `id` in this world has attack `attack_id`: a v0.7.0 Siege Engine fixture
## (siege_v070_def) is appended when its table has no attack by that id. Returns the attack's index (-1: none).
static func ensure_attack(w: World, id: StringName, attack_id: StringName) -> int:
	var t := w.boss_tables[table_index(w, id)]
	var k := t.attack_index(attack_id)
	if k >= 0:
		return k
	var d := siege_v070_def(attack_id)
	return with_attack(w, id, d) if d != null else -1
