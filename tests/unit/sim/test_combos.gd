extends GutTest
## v0.3.0 G: the eight named combos (unlock, each effect with the shipped numbers), and a soak of all 24 items
## against real enemies: no LIMIT from the watchdog, deterministic. Aim angle 0 = +x.

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT
const U := InputFrame.UTILITY
const D := InputFrame.DASH
const K := ItemTable.Kind
const E := ComboTable.Effect

var _tables: Array[ItemTable] = []
var _combos: Array[ComboTable] = []


func before_all() -> void:
	var repo := ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(repo)
	_combos = ContentCompiler.compile_combos(repo)


func _index(kind: int) -> int:
	for i in _tables.size():
		if _tables[i].kind == kind:
			return i
	return -1


func _combo_index(effect: int) -> int:
	for c in _combos.size():
		if _combos[c].effect == effect:
			return c
	return -1


func _world(
	kinds: Array = [], enemies: Array = [Vector2(1.2, 0)], utility: int = PlayerTable.Utility.NONE
) -> World:
	var t := PlayerTable.starting_values()
	t.utility = utility
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.set_item_tables(_tables)
	w.set_combo_tables(_combos)
	for k: int in kinds:
		w.add_item(_index(k))
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 500)
	return w


func _f(held: int = 0, pressed: int = 0, aim: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _idle(w: World, n: int, held: int = 0, aim: int = 0) -> void:
	for i in n:
		w.step(_f(held, 0, aim))


func _events(w: World, kind: SimEvent.Kind, effect := &"", after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind and (effect == &"" or e.effect_id == effect):
			out.append(e)
	return out


func _amounts(events: Array[SimEvent]) -> Array:
	return events.map(func(e: SimEvent) -> int: return e.amount)


## Presses attack and steps until the swing, its hit-stop and any Twin Arc echo are over (then 2 more ticks).
func _swing(w: World, aim: int = 0) -> void:
	w.step(_f(0, P, aim))
	for k in 120:
		if w.swing_t == 0 and w.echo_t == 0 and w.freeze_ticks == 0 and w.input_buffer[0] == 0:
			break
		w.step(_f(0, 0, aim))
	_idle(w, 2, 0, aim)


func _dash(w: World, aim: int) -> void:
	w.step(_f(0, D, aim))
	while w.is_dashing():
		w.step(_f(0, 0, aim))


# --- Data and unlocking ---------------------------------------------------------------------------------------
func test_eight_combos_each_with_its_own_effect() -> void:
	assert_eq(_combos.size(), 8)
	var effects := {}
	var pairs := {}
	for c in _combos:
		effects[c.effect] = c.id
		assert_ne(c.item_a, c.item_b, String(c.id))
		pairs[mini(c.item_a, c.item_b) * 100 + maxi(c.item_a, c.item_b)] = true
	assert_eq(effects.size(), 8, "mechanically distinct: one effect each")
	assert_eq(pairs.size(), 8, "no pair twice")


func test_owning_both_items_unlocks_the_combo_once() -> void:
	var w := _world([K.EMBER_EDGE])
	assert_eq(w.combos_owned.size(), 0)
	assert_false(Engines.has_combo(w, E.PLASMA_ARC))
	w.add_item(_index(K.CONDUCTOR))
	var ev := _events(w, SimEvent.Kind.COMBO_UNLOCKED)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].amount, _combo_index(E.PLASMA_ARC))
	assert_eq(ev[0].effect_id, &"plasma_arc")
	assert_eq(w.combos_owned, PackedInt32Array([_combo_index(E.PLASMA_ARC)]))
	assert_true(Engines.has_combo(w, E.PLASMA_ARC))
	w.add_item(_index(K.LONG_EDGE))
	assert_eq(_events(w, SimEvent.Kind.COMBO_UNLOCKED).size(), 1, "no repeat")
	var r := WorldReader.new(w)
	assert_eq(r.combo_item_ids(w.combos_owned[0]), [&"ember_edge", &"conductor"])
	assert_eq(r.combo_name_key(w.combos_owned[0]), &"ITEM_COMBO_PLASMA_ARC")


func test_carried_items_bring_their_combos_without_a_new_card() -> void:
	var w := _world()
	var owned := PackedInt32Array([_index(K.TWIN_ARC), _index(K.OVERCHARGE)])
	w.set_items_owned(owned)
	assert_true(Engines.has_combo(w, E.RESONANCE))
	assert_eq(_events(w, SimEvent.Kind.COMBO_UNLOCKED).size(), 0)
	var v := World.new(5, PlayerTable.starting_values())
	v.set_item_tables(_tables)
	v.add_item(_index(K.MOMENTUM))
	v.add_item(_index(K.SWIFT_FEET))
	assert_eq(v.combos_owned.size(), 0, "no combo tables yet")
	v.set_combo_tables(_combos)
	assert_true(Engines.has_combo(v, E.SLIPSTREAM), "tables set later: owned at once")
	assert_eq(_events(v, SimEvent.Kind.COMBO_UNLOCKED).size(), 0)


func test_all_24_items_own_all_8_combos() -> void:
	var w := _world()
	for k in _tables.size():
		w.add_item(k)
	assert_eq(w.combos_owned.size(), 8)
	assert_eq(_events(w, SimEvent.Kind.COMBO_UNLOCKED).size(), 8)


# --- Each combo -----------------------------------------------------------------------------------------------
func test_plasma_arc_shocking_a_burning_enemy_arcs_fire() -> void:
	var w := _world(
		[K.EMBER_EDGE, K.CONDUCTOR], [Vector2(1.2, 0), Vector2(2.2, 1.5), Vector2(1.2, 6)]
	)
	var a := w.actors
	a.burn_stacks[1] = 2
	a.burn_t[1] = 100
	var root := w.take_root()
	Engines.add_shock(w, 1, 1, root)
	var arc := _events(w, SimEvent.Kind.DAMAGE, &"plasma_arc")
	assert_eq(_amounts(arc), [8])
	assert_eq(arc[0].target_id, a.ids[2], "the nearest other enemy within 4 m")
	assert_eq(a.burn_stacks[2], 1, "and sets it burning")
	assert_eq(a.shock_stacks[2], 0, "the arc is a payoff: it feeds no shock")
	Engines.add_shock(w, 1, 1, root)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, &"plasma_arc").size(), 1, "once per root")
	a.burn_stacks[3] = 0
	Engines.add_shock(w, 3, 1, w.take_root())
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, &"plasma_arc").size(), 1, "not burning: no arc")


func test_shatter_dash_breaks_a_frozen_enemy() -> void:
	var w := _world([K.FROST_CORE, K.KINETIC_DASH], [Vector2(2.0, 0)])
	var a := w.actors
	a.frozen_t[1] = 60
	_dash(w, 0)
	assert_eq(_amounts(_events(w, SimEvent.Kind.DAMAGE, &"kinetic_dash")), [12])
	assert_eq(_amounts(_events(w, SimEvent.Kind.DAMAGE, &"shatter_dash")), [30])
	assert_false(Engines.frozen(w, 1), "shattered: the freeze ends")
	var v := _world([K.FROST_CORE, K.KINETIC_DASH], [Vector2(2.0, 0)])
	_dash(v, 0)
	assert_eq(_events(v, SimEvent.Kind.DAMAGE, &"shatter_dash").size(), 0, "not frozen: no shatter")


func test_resonance_the_echo_of_a_charged_swing_sends_a_wave() -> void:
	var w := _world([K.TWIN_ARC, K.OVERCHARGE])
	for k in 3:
		_swing(w)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, &"resonance").size(), 0, "plain swings' echoes")
	_swing(w)
	var waves := _events(w, SimEvent.Kind.DAMAGE, &"overcharge")
	var res := _events(w, SimEvent.Kind.DAMAGE, &"resonance")
	assert_eq(waves.size(), 1, "the 4th swing's shockwave")
	assert_eq(_amounts(res), _amounts(waves), "and its echo's, at full share")
	assert_gt(res[0].tick, waves[0].tick, "0.1 s later")
	assert_eq(res[0].root_id, waves[0].root_id, "inside the swing's chain")


func test_shrapnel_storm_bounced_bolts_burst_once() -> void:
	var w := _world([K.SPLINTER_SHOT, K.RICOCHET_CORE], [])
	var walls: Array[Obb] = [Obb.make(Vector2(3.0, 0), Vector2(0.25, 4.0), 0)]
	w.set_walls(walls)
	var shards := {}
	w.step(_f(S, 0, 0))
	for t in 60:
		w.step(_f(0, 0, 0))
		var p := w.projectiles
		for i in p.size():
			if p.tags[i] & SimEvent.TAG_SHRAPNEL:
				shards[p.ids[i]] = p.bounces[i]
	assert_eq(shards.size(), 6, "three bolts bounce, each bursts into two shards")
	for id in shards:
		assert_eq(shards[id], 0, "shards never bounce, so never burst again")


func test_blood_harvest_an_execution_bursts_and_heals_once() -> void:
	var w := _world(
		[K.VAMPIRIC_CORE, K.EXECUTIONER], [Vector2(1.2, 0), Vector2(2.4, 0.5), Vector2(8, 0)]
	)
	var a := w.actors
	a.hp[0] = 50
	a.hp[1] = 10
	a.hp[2] = 5
	Damage.hit(w, 1, 20, a.ids[0], a.ids[0], w.take_root(), SimEvent.TAG_MELEE, a.pos(0), a.pos(1))
	var nova := _events(w, SimEvent.Kind.DAMAGE, &"blood_harvest")
	assert_eq(nova.size(), 1, "the nova hits the neighbour, not the far one")
	assert_eq(nova[0].target_id, a.ids[2])
	assert_eq(_events(w, SimEvent.Kind.KILL).size(), 2, "and kills it, executed too")
	var heals := _events(w, SimEvent.Kind.HEAL, &"blood_harvest")
	assert_eq(heals.size(), 1, "once per root chain: the nova's own execution doesn't chain")
	assert_eq(heals[0].amount_applied, 2)
	assert_eq(a.hp[0], 50 + 3 + 3 + 2, "two Vampiric kills and one harvest")


func test_spiked_phase_the_phase_ring_also_fires_thorns() -> void:
	var w := _world(
		[K.THORN_MANTLE, K.PHASE_STRIKE],
		[Vector2(6, 0), Vector2(0, 1.0)],
		PlayerTable.Utility.BLINK
	)
	w.step(_f(0, U))
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, &"phase_strike").size(), 1)
	var thorns := 0
	for i in w.projectiles.size():
		if w.projectiles.tags[i] & SimEvent.TAG_THORN:
			thorns += 1
	assert_eq(thorns, 6, "the Thorn Mantle ring, without taking damage")
	assert_eq(w.spiked_tick, w.tick - 1)


func test_slipstream_a_momentum_hit_refunds_the_dash_once_per_window() -> void:
	var w := _world([K.MOMENTUM, K.SWIFT_FEET], [Vector2(-5.2, 0), Vector2(1.2, 0)])
	_dash(w, 2048)
	assert_gt(w.dash_cooldown_left, 0)
	w.step(_f(0, P, 2048))
	_idle(w, w.player.step(w.combo_step).active_tick + 1, 0, 2048)
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"slipstream").size(), 1)
	assert_eq(w.dash_cooldown_left, 0, "refunded at once")
	_idle(w, 16, 0, 2048)
	_dash(w, 0)
	_swing(w, 0)
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"slipstream").size(), 1, "within 1.5 s: no")
	assert_gt(w.dash_cooldown_left, 0)
	_idle(w, 100)
	_dash(w, 2048)
	_swing(w, 2048)
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"slipstream").size(), 2, "the window passed")


func test_frozen_bastion_guard_blocks_chill_the_attacker() -> void:
	var w := _world([K.BULWARK, K.GLACIAL_EDGE], [Vector2(1.2, 0), Vector2(6, 0)], 0)
	w.player.utility = PlayerTable.Utility.GUARD
	var a := w.actors
	w.step(_f(U))
	assert_true(w.guarding())
	Damage.hit(w, 0, 20, a.ids[1], a.ids[1], 70, 0, Vector2(3, 0), a.pos(0))
	assert_eq(a.frost_stacks[1], 2)
	a.invuln[0] = 0
	Damage.hit(w, 0, 20, a.ids[1], a.ids[1], 71, 0, Vector2(3, 0), a.pos(0))
	assert_true(Engines.frozen(w, 1), "two blocks: four stacks freeze it")
	a.invuln[0] = 0
	Damage.hit(w, 0, 20, a.ids[2], a.ids[2], 72, 0, Vector2(3, 0), a.pos(0))
	assert_eq(a.frost_stacks[2], 0, "6 m away: beyond the 4 m reach")
	assert_eq(w.guard_charges, 3)


# --- All 24 items against enemies -----------------------------------------------------------------------------
## 5,000 ticks with every item and combo, the guard, real enemies kept at six, walls to bounce off, and a scripted
## mix of swings, shots, dashes and guarding. Returns [world, LIMIT events, the most events in one tick].
func _soak(seed_value: int) -> Array:
	var t := PlayerTable.starting_values()
	t.utility = PlayerTable.Utility.GUARD
	t.hp = 1000000
	var w := World.new(seed_value, t)
	w.set_enemy_tables(CombatLab.tables())
	var walls: Array[Obb] = []
	for side: Vector2 in [Vector2(9, 0), Vector2(-9, 0), Vector2(0, 9), Vector2(0, -9)]:
		var half := Vector2(0.5, 9.5) if side.x != 0 else Vector2(9.5, 0.5)
		walls.append(Obb.make(side, half, 0))
	w.set_walls(walls)
	w.set_item_tables(_tables)
	w.set_combo_tables(_combos)
	for k in _tables.size():
		w.add_item(k)
	var kinds := [ActorStore.Kind.CHARGER, ActorStore.Kind.NEEDLE, ActorStore.Kind.WARDEN]
	var most := 0
	var seq := w.last_event_seq()
	for tick in 5000:
		if w.actors.size() < 7:
			var n := w.actors.size()
			var at := Vector2(5.0 * Kin.dir(n * 700 + tick).x, 5.0 * Kin.dir(n * 700 + tick).y)
			w.add_enemy(kinds[(tick + n) % 3], at)
		var aim := 0
		if w.actors.size() > 1:
			aim = Kin.angle_of(w.actors.pos(1) - w.player_pos())
		var phase := tick % 240
		var held := S if phase < 120 else (U if phase < 160 else 0)
		var pressed := 0
		if phase >= 160 and phase % 8 == 0:
			pressed = P
		if tick % 97 == 0:
			pressed |= D
		var move := Vector2i(Kin.dir(tick * 9).x * 100, Kin.dir(tick * 9).y * 100)
		w.step(InputFrame.make(move, aim, 300, held, pressed))
		most = maxi(most, w.last_event_seq() - seq)
		seq = w.last_event_seq()
	return [w, _events(w, SimEvent.Kind.LIMIT), most]


func test_all_24_items_for_5000_ticks_raise_no_limit_and_repeat_exactly() -> void:
	var a := _soak(21)
	var b := _soak(21)
	var w: World = a[0]
	var limits: Array[SimEvent] = a[1]
	var watchdog := limits.filter(
		func(e: SimEvent) -> bool: return e.effect_id != ItemProcs.EFFECT_VAMPIRIC_CORE
	)
	print(
		(
			"SOAK| kills=%d events=%d most_in_a_tick=%d limits=%d (watchdog %d, heal cap %d)"
			% [
				w.kills,
				w.last_event_seq(),
				a[2],
				limits.size(),
				watchdog.size(),
				limits.size() - watchdog.size()
			]
		)
	)
	assert_eq(watchdog.size(), 0, "no chain hit the watchdog")
	assert_lt(a[2], 256, "well under the per-tick watchdog (T-FUZZ's stricter bound)")
	assert_gt(w.kills, 20, "it really fought")
	for fx: StringName in [&"shock_discharge", &"bleed", &"freeze", &"plasma_arc", &"resonance"]:
		var n := 0
		for e in w.events_since(0):
			if e.effect_id == fx:
				n += 1
		print("SOAK| %s=%d (in the last %d events)" % [fx, n, World.EVENT_LOG_CAP])
	assert_eq(w.state_hash(), (b[0] as World).state_hash(), "deterministic")
