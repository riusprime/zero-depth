class_name AttackScenario
extends RefCounted
## v0.6.0 MX1: fixed scripted fights that exercise the weapon attacks (the Blade's four steps, the Gun's bolt, both
## Skills) with the items the modifier engine migrated, for the equivalence test (test_modifier_equivalence) and the
## combinatorial smoke test (test_modifier_smoke). Every input is a function of the tick, so a scenario replays
## exactly. The digest covers every event's outcome fields and the state that attacks touch; it leaves out the
## build's spec digest (hashed by World.state_hash since MX1) and HIT.proc_pct (a hook's hits carry its proc
## coefficient since MX1), so it compares the v0.5 code and the engine on outcomes alone.

const TICKS := 900
const DUMMIES := 14

## The scenarios the equivalence fixture pins: [id, weapon, item ids, heat, extra ability ids].
const CASES: Array = [
	["blade_plain", &"blade", [], false, []],
	["gun_plain", &"gun", [], false, []],
	["both_plain", &"", [], false, []],
	["blade_long_edge", &"blade", [&"long_edge"], false, []],
	["blade_twin_arc", &"blade", [&"twin_arc"], false, []],
	["blade_ember_edge", &"blade", [&"ember_edge"], false, []],
	["blade_overcharge", &"blade", [&"overcharge"], false, []],
	["blade_conductor", &"blade", [&"conductor"], false, []],
	["blade_serrated_edge", &"blade", [&"serrated_edge"], false, []],
	["blade_glacial_edge", &"blade", [&"glacial_edge"], false, []],
	["blade_wildfire_rider", &"blade", [&"wildfire"], false, []],
	["gun_splinter_shot", &"gun", [&"splinter_shot"], false, []],
	["gun_rapid_coil", &"gun", [&"rapid_coil"], false, []],
	["gun_ricochet_core", &"gun", [&"ricochet_core"], false, []],
	["gun_static_chain", &"gun", [&"static_chain"], false, []],
	["gun_frost_core", &"gun", [&"frost_core"], false, []],
	["gun_cinder_shot", &"gun", [&"cinder_shot"], false, []],
	["gun_barbed_bolts", &"gun", [&"barbed_bolts"], false, []],
	["gun_glacial_rider", &"gun", [&"glacial_edge", &"cold_snap"], false, []],
	[
		"blade_all",
		&"blade",
		[
			&"long_edge",
			&"twin_arc",
			&"ember_edge",
			&"overcharge",
			&"conductor",
			&"serrated_edge",
			&"glacial_edge",
			&"wildfire",
			&"cold_snap",
			&"momentum",
			&"executioner",
		],
		true,
		[&"flame_trail", &"orbit_blades"],
	],
	[
		"gun_all",
		&"gun",
		[
			&"splinter_shot",
			&"rapid_coil",
			&"ricochet_core",
			&"static_chain",
			&"frost_core",
			&"cinder_shot",
			&"barbed_bolts",
			&"wildfire",
			&"thorn_mantle",
		],
		true,
		[&"drone_buddy", &"arc_field"],
	],
	[
		"both_all",
		&"",
		[
			&"long_edge",
			&"twin_arc",
			&"ember_edge",
			&"overcharge",
			&"splinter_shot",
			&"ricochet_core",
			&"static_chain",
			&"frost_core",
			&"cinder_shot",
			&"barbed_bolts",
			&"serrated_edge",
		],
		true,
		[],
	],
]

static var _repo: ContentRepository


static func repo() -> ContentRepository:
	if _repo == null:
		_repo = ContentRepository.load_all()
	return _repo


## The world of one case: the runner (with the build's weapon, or both outside a build), crit on (its own stream),
## the shipped items, combos, abilities and stat cards, an arena with walls, and moving dummies that shoot.
static func world(
	weapon: StringName, items: Array, heat: bool, abilities: Array, seed_value: int = 7
) -> World:
	var r := repo()
	var t := ContentCompiler.compile_player(r.get_def(&"player", &"runner"))
	if weapon != &"":
		ContentCompiler.apply_build(t, r.get_def(&"build", weapon))
	var w := World.new(seed_value, t)
	w.dummy_fire_period = 50
	w.dummy_shot_damage = 2
	w.projectile_life = 90
	var walls: Array[Obb] = []
	var e := 9.5
	walls.append(Obb.make(Vector2(0.0, e), Vector2(e, 0.5), 0))
	walls.append(Obb.make(Vector2(0.0, -e), Vector2(e, 0.5), 0))
	walls.append(Obb.make(Vector2(e, 0.0), Vector2(0.5, e), 0))
	walls.append(Obb.make(Vector2(-e, 0.0), Vector2(0.5, e), 0))
	walls.append(Obb.make(Vector2(4.0, 4.0), Vector2(1.5, 0.3), 600))
	walls.append(Obb.make(Vector2(-4.5, -3.0), Vector2(0.4, 1.8), 0))
	w.set_walls(walls)
	var tables := ContentCompiler.compile_items(r)
	w.set_item_tables(tables)
	w.set_combo_tables(ContentCompiler.compile_combos(r))
	w.ability_tables = ContentCompiler.compile_abilities(r)
	w.stat_tables = ContentCompiler.compile_stat_cards(r)
	if heat:
		Heat.enable(w, ContentCompiler.compile_heat(r.get_def(&"heat", &"overclock")))
	for id: StringName in items:
		w.add_item(item_index(tables, id))
	Abilities.grant_start(w)
	for id: StringName in abilities:
		for k in w.ability_tables.size():
			if w.ability_tables[k].id == id:
				Abilities.grant(w, k)
	Abilities.start_floor(w)
	for k in DUMMIES:
		var ang := k * 4096 / DUMMIES
		var dist := 2.0 + float(k % 4) * 1.6
		w.add_dummy(Kin.dir(ang) * dist, 0.35, 260 + 40 * (k % 3))
	return w


static func item_index(tables: Array[ItemTable], id: StringName) -> int:
	for k in tables.size():
		if tables[k].id == id:
			return k
	return -1


## The input of tick `t`: SHOOT held, a melee press every 9 ticks, a dash every 97, the Skill every 151, a vent
## every 233, the aim sweeping round and a slow walk that turns.
static func frame(t: int) -> InputFrame:
	var held := InputFrame.SHOOT
	var pressed := 0
	if t % 9 == 0:
		pressed |= InputFrame.PRIMARY
	if t % 97 == 40:
		pressed |= InputFrame.DASH
	if t % 151 == 75:
		pressed |= InputFrame.SKILL
	if t % 233 == 200:
		pressed |= InputFrame.VENT
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var move: Vector2i = dirs[(t / 70) % 4] if (t / 35) % 2 == 0 else Vector2i.ZERO
	return InputFrame.make(move, (t * 37) & 4095, 300, held, pressed)


## Runs `ticks` ticks of the script and returns {digest, hits, damage, kills, launched}: the event and state digest
## and a few counts (player HIT events, total DAMAGE applied by the player, kills).
static func run(w: World, ticks: int = TICKS) -> Dictionary:
	var h := StateHasher.new()
	var seen := 0
	var hits := 0
	var dealt := 0
	var kills := 0
	var pid := w.actors.ids[0]
	for t in ticks:
		w.step(frame(t))
		for ev in w.events_since(seen):
			seen = ev.seq
			_digest_event(h, ev)
			if ev.owner_id == pid and ev.target_id != pid:
				if ev.kind == SimEvent.Kind.HIT:
					hits += 1
				elif ev.kind == SimEvent.Kind.DAMAGE:
					dealt += ev.amount_applied
				elif ev.kind == SimEvent.Kind.KILL:
					kills += 1
	_digest_state(h, w)
	return {"digest": h.finish_hex(), "hits": hits, "damage": dealt, "kills": kills}


static func _digest_event(h: StateHasher, e: SimEvent) -> void:
	for v in [
		e.seq,
		e.tick,
		e.kind,
		e.source_id,
		e.owner_id,
		e.target_id,
		e.root_id,
		e.parent_seq,
		e.depth,
		e.amount,
		e.amount_applied,
		e.tags,
	]:
		h.add_int(v)
	h.add_f32(e.pos.x)
	h.add_f32(e.pos.y)
	h.add_string(String(e.effect_id))
	h.add_string(",".join(e.ancestry))


## The state attacks touch, without the build's spec digest.
static func _digest_state(h: StateHasher, w: World) -> void:
	w.actors.hash_into(h)
	w.projectiles.hash_into(h)
	w.proc_ledger.hash_into(h)
	for s in [w.rng_map, w.rng_loot, w.rng_combat, w.rng_ai, w.rng_crit, w.rng_ability]:
		h.add_int(s.state)
	for v in [
		w.tick,
		w.freeze_ticks,
		w.swing_t,
		w.swing_angle,
		w.swing_root,
		w.combo_step,
		w.combo_window,
		w.shot_cd,
		w.echo_t,
		w.echo_angle,
		w.echo_step,
		w.echo_root,
		w.echo_damage,
		w.echo_tick,
		w.swing_count,
		1 if w.swing_overcharged else 0,
		w.overcharge_tick,
		w.chain_count,
		w.chain_root,
		w.chain_tick,
		w.engine_bolt_hits,
		w.guard_charges,
		w.kills,
	]:
		h.add_int(v)
