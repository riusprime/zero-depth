class_name SpellZones
extends RefCounted
## The spells that
## last, one store for all of them (World.spell_zone_*, oldest first, hashed with the spells): each zone is a kind, the
## spell and level that made it, a root, the tick it ends, its next pulse, its damage a pulse, two counters, a centre,
## a velocity and a radius. Every period_ticks (the spell's) a zone pulses: it hits each living enemy whose centre is
## within its radius (Spells.hit: the player's, TAG_ABILITY, the spell's id) and gives it the element's status
## (Spells.status); each pulse is its own root. At its end some zones do one last thing (finish). The fire patches of
## the wand (ElementAbilities) run AttackSpecs from the wand's book; a spell has no spec there, so the spells keep
## this store of their own and reuse the statuses and the burn (Engines, Venom) as they are.
## - BLIZZARD: locked on the densest pack; Lv 5: what is still inside at the end freezes bonus_ticks.
## - FIRE (B2 Burning Ground; Fireball's Lv 5 ground; Meteor's Lv 5 crater): burns what stands in it; B2 Lv 5 (aux 1)
##   follows you at speed_m_tick (half the hero's walk).
## - METEOR_MARK: no pulse; at its end the strike hits what is inside the mark then (enemies can walk out), burns
##   and knocks down for the level's ticks (a hold); Lv 5 leaves a crater (FIRE) of bonus_radius_m for bonus_ticks.
## - ORB: rolls on at its velocity, each pulse zaps the nearest `count` enemies within its radius; Lv 5: a burst
##   of bonus_radius_m at its end.
## - STATIC: around you; Lv 5: your dash discharges it (a bonus_radius_m burst of bonus_damage; it ends).
## - POOL (V1, landed by the orb in flight): a venom pool; Lv 5 (aux 0): an enemy that dies in it leaves a small pool
##   (aux 1, bonus_radius_m for bonus_ticks; at most SMALL_POOLS at once; a small one leaves none).
## - CLOUD: follows you, each pulse drops a PUFF (its radius, bonus_ticks long) where you stand; the puffs pulse on
##   the cloud's beat and hit an enemy once a tick however many it stands in; Lv 5: they slow (a hold).
## - VINE: stands where it grew, each pulse its `count` heads spit at the nearest enemies within reach (one each);
##   Lv 5: a spit passes through `pierce` more on its line.
## - RING_LATER (X1 Lv 3+): the second ring of thorns, at its end. THORN_WALL (X1 Lv 5): the ring stays, pulsing.
## - HEMO: follows its mark (aux: the actor id); at its end: the hit, then all its bleed at once (one DoT tick of
##   what the bleed had left), and its stacks spread to the enemies within the radius.
## - LEECH: around you, drains the bleeding enemies within its radius (Lv 5: the others at half); aux counts the
##   HP it took, aux2 the HP it healed: you heal 1 HP per heal_per_damage, at most the level's heal_cap a cast.
## Bounded: at most MAX zones (a new one past it is not made). No randomness.

const BLIZZARD := 0
const FIRE := 1
const METEOR_MARK := 2
const ORB := 3
const STATIC := 4
const POOL := 5
const CLOUD := 6
const PUFF := 7
const VINE := 8
const RING_LATER := 9
const THORN_WALL := 10
const HEMO := 11
const LEECH := 12
const MAX := 64
const SMALL_POOLS := 8
## Toxic Cloud's Lv 5 slow lasts this long after a puff's pulse (refreshed each pulse).
const SLOW_TICKS := 45
## The most drain lines one Leech pulse logs for the view.
const DRAIN_FX := 6
const NEVER := 1 << 30


## A new zone (its index, or -1 past MAX). `first`: ticks to its first pulse (NEVER: it never pulses).
static func add(
	w: World,
	kind: int,
	t: SpellTable,
	lv: int,
	at: Vector2,
	r: float,
	life: int,
	dmg: int,
	first := 0
) -> int:
	if w.spell_zone_kind.size() >= MAX:
		return -1
	w.spell_zone_kind.append(kind)
	w.spell_zone_spell.append(t.spell)
	w.spell_zone_level.append(lv)
	w.spell_zone_root.append(w.take_root())
	w.spell_zone_end.append(w.tick + maxi(1, life))
	w.spell_zone_next.append(NEVER if first >= NEVER else w.tick + first)
	w.spell_zone_dmg.append(dmg)
	w.spell_zone_aux.append(0)
	w.spell_zone_aux2.append(0)
	w.spell_zone_pos.append(at)
	w.spell_zone_vel.append(Vector2.ZERO)
	w.spell_zone_r.append(r)
	return w.spell_zone_kind.size() - 1


static func _remove(w: World, k: int) -> void:
	w.spell_zone_kind.remove_at(k)
	w.spell_zone_spell.remove_at(k)
	w.spell_zone_level.remove_at(k)
	w.spell_zone_root.remove_at(k)
	w.spell_zone_end.remove_at(k)
	w.spell_zone_next.remove_at(k)
	w.spell_zone_dmg.remove_at(k)
	w.spell_zone_aux.remove_at(k)
	w.spell_zone_aux2.remove_at(k)
	w.spell_zone_pos.remove_at(k)
	w.spell_zone_vel.remove_at(k)
	w.spell_zone_r.remove_at(k)


## Tick phase 6 (Spells.advance): each zone moves, pulses when due, and finishes at its end.
static func advance(w: World) -> void:
	if w.spell_zone_kind.is_empty():
		return
	var puffed := {}  # the enemy ids a puff hit this tick (one hit a tick, however many puffs)
	var k := 0
	while k < w.spell_zone_kind.size():
		var t := Spells.table(w, w.spell_zone_spell[k])
		if t == null:
			_remove(w, k)
			continue
		_move(w, k, t)
		if w.tick < w.spell_zone_end[k] and w.spell_zone_next[k] <= w.tick:
			w.spell_zone_next[k] += t.period_ticks
			_pulse(w, k, t, puffed)
		if w.tick >= w.spell_zone_end[k]:
			_finish(w, k, t)
			_remove(w, k)
			continue
		k += 1


static func _move(w: World, k: int, t: SpellTable) -> void:
	var a := w.actors
	match w.spell_zone_kind[k]:
		ORB:
			w.spell_zone_pos[k] += w.spell_zone_vel[k]
		STATIC:
			w.spell_zone_pos[k] = w.player_pos()
			if w.spell_zone_level[k] >= Spells.LEVELS:
				var dashing := 1 if w.is_dashing() else 0
				if dashing == 1 and w.spell_zone_aux[k] == 0:
					_discharge(w, k, t)
				w.spell_zone_aux[k] = dashing
		CLOUD, LEECH:
			w.spell_zone_pos[k] = w.player_pos()
		FIRE:
			if w.spell_zone_aux[k] == 1:  # B2 Lv 5: it follows you
				var to := w.player_pos() - w.spell_zone_pos[k]
				var d := Kin.length(to)
				if d > t.speed_m_tick:
					w.spell_zone_pos[k] += to / d * t.speed_m_tick
				else:
					w.spell_zone_pos[k] = w.player_pos()
		HEMO:
			var i := a.index_of(w.spell_zone_aux[k])
			if i > 0 and a.dead[i] == 0:
				w.spell_zone_pos[k] = a.pos(i)


static func _pulse(w: World, k: int, t: SpellTable, puffed: Dictionary) -> void:
	var at := w.spell_zone_pos[k]
	var r := w.spell_zone_r[k]
	var dmg := w.spell_zone_dmg[k]
	match w.spell_zone_kind[k]:
		BLIZZARD, FIRE, STATIC, POOL:
			_area(w, t, at, r, dmg, w.take_root())
		PUFF:
			var root := w.take_root()
			var slow := w.spell_zone_level[k] >= Spells.LEVELS
			for id in _ids(w, Spells.enemies_within(w, at, r)):
				if puffed.has(id):
					continue
				puffed[id] = true
				var i := w.actors.index_of(id)
				if i < 0 or w.actors.dead[i] == 1:
					continue
				Spells.hit(w, i, dmg, root, at, t)
				Spells.status(w, i, t, root)
				if slow and w.actors.dead[i] == 0:
					Spells.hold(w, i, SLOW_TICKS, t.slow_permille)
		CLOUD:
			add(w, PUFF, t, w.spell_zone_level[k], at, r, t.bonus_ticks, dmg)
		VINE:
			_spit(w, k, t)
		ORB:
			var root := w.take_root()
			var hit := Spells.nearest_n(
				w, at, r, SpellTable.at_i(t.count, w.spell_zone_level[k], 1)
			)
			for id in _ids(w, hit):
				var i := w.actors.index_of(id)
				if i < 0 or w.actors.dead[i] == 1:
					continue
				Spells.fx(w, Spells.FX_ZAP, at, w.actors.pos(i), 0.0, t.spell)
				Spells.hit(w, i, dmg, root, at, t)
				Spells.status(w, i, t, root)
		THORN_WALL:
			ring(w, t, at, t.inner_m, r, dmg, w.take_root())
		LEECH:
			_drain(w, k, t)


## Every living enemy within r of `at`: the hit and the element's status.
static func _area(w: World, t: SpellTable, at: Vector2, r: float, dmg: int, root: int) -> void:
	for id in _ids(w, Spells.enemies_within(w, at, r)):
		var i := w.actors.index_of(id)
		if i < 0 or w.actors.dead[i] == 1:
			continue
		Spells.hit(w, i, dmg, root, at, t)
		Spells.status(w, i, t, root)


## Blood Thorns' ring: every living enemy whose body reaches between `inner` and `outer` of `at`.
static func ring(
	w: World, t: SpellTable, at: Vector2, inner: float, outer: float, dmg: int, root: int
) -> int:
	var a := w.actors
	var n := 0
	for id in _ids(w, Spells.enemies_within(w, at, outer + 1.0)):
		var i := a.index_of(id)
		if i < 0 or a.dead[i] == 1:
			continue
		var d := Kin.length(a.pos(i) - at)
		if d + a.radius[i] < inner or d - a.radius[i] > outer:
			continue
		Spells.hit(w, i, dmg, root, at, t)
		Spells.status(w, i, t, root)
		n += 1
	return n


static func _ids(w: World, idx: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in idx:
		out.append(w.actors.ids[i])
	return out


## Each head spits at one of the nearest enemies within reach of the vine (Lv 5: through `pierce` more).
static func _spit(w: World, k: int, t: SpellTable) -> void:
	var at := w.spell_zone_pos[k]
	var lv := w.spell_zone_level[k]
	var targets := Spells.nearest_n(w, at, t.reach_m, SpellTable.at_i(t.count, lv, 1))
	var root := w.take_root()
	var through := t.pierce if lv >= Spells.LEVELS else 0
	for id in _ids(w, targets):
		var i := w.actors.index_of(id)
		if i < 0 or w.actors.dead[i] == 1:
			continue
		var to := w.actors.pos(i)
		var line := Spells.line(w, at, to, t.reach_m, 1 + through, id)
		var end := to
		for jd in line:
			var j := w.actors.index_of(jd)
			if j < 0 or w.actors.dead[j] == 1:
				continue
			end = w.actors.pos(j)
			Spells.hit(w, j, w.spell_zone_dmg[k], root, at, t)
			Spells.status(w, j, t, root)
		Spells.fx(w, Spells.FX_SPIT, at, end, 0.0, t.spell)


## X3: drain this pulse, then heal what the drained HP has earned (within the cast's cap).
static func _drain(w: World, k: int, t: SpellTable) -> void:
	var a := w.actors
	var at := w.spell_zone_pos[k]
	var lv := w.spell_zone_level[k]
	var root := w.take_root()
	var lines := 0
	for id in _ids(w, Spells.enemies_within(w, at, w.spell_zone_r[k])):
		var i := a.index_of(id)
		if i < 0 or a.dead[i] == 1:
			continue
		var dmg := w.spell_zone_dmg[k]
		if a.bleed_stacks[i] <= 0:
			if lv < Spells.LEVELS:
				continue
			dmg = maxi(1, dmg / 2)  # Lv 5: the others at half
		if lines < DRAIN_FX:
			Spells.fx(w, Spells.FX_DRAIN, a.pos(i), at, 0.0, t.spell)
			lines += 1
		w.spell_zone_aux[k] += Spells.hit(w, i, dmg, root, at, t)
	var want := mini(SpellTable.at_i(t.heal_cap, lv, 10), w.spell_zone_aux[k] / t.heal_per_damage)
	var give := want - w.spell_zone_aux2[k]
	if give <= 0 or w.player_dead():
		return
	var applied := maxi(0, mini(give, a.max_hp[0] - a.hp[0]))
	a.hp[0] += applied
	w.spell_zone_aux2[k] += applied
	var h := w.emit_event(SimEvent.Kind.HEAL, a.ids[0], a.ids[0], a.ids[0], w.player_pos())
	h.root_id = root
	h.amount = give
	h.amount_applied = applied
	h.effect_id = t.id


## L3 Lv 5: the dash spends the field in one burst around you.
static func _discharge(w: World, k: int, t: SpellTable) -> void:
	var at := w.player_pos()
	Spells.fx(w, Spells.FX_DISCHARGE, at, at, t.bonus_radius_m, t.spell)
	_area(w, t, at, t.bonus_radius_m, t.bonus_damage, w.take_root())
	w.spell_zone_end[k] = w.tick


static func _finish(w: World, k: int, t: SpellTable) -> void:
	var a := w.actors
	var at := w.spell_zone_pos[k]
	var lv := w.spell_zone_level[k]
	var r := w.spell_zone_r[k]
	match w.spell_zone_kind[k]:
		BLIZZARD:
			if lv >= Spells.LEVELS:
				var root := w.take_root()
				for id in _ids(w, Spells.enemies_within(w, at, r)):
					var i := a.index_of(id)
					if i >= 0 and a.dead[i] == 0:
						Spells.freeze(w, i, t.bonus_ticks, root, t)
		METEOR_MARK:
			var root := w.spell_zone_root[k]
			Spells.fx(w, Spells.FX_STRIKE, at, at, r, t.spell)
			for id in _ids(w, Spells.enemies_within(w, at, r)):
				var i := a.index_of(id)
				if i < 0 or a.dead[i] == 1:
					continue
				Spells.hit(w, i, w.spell_zone_dmg[k], root, at, t)
				Spells.status(w, i, t, root)
				if a.dead[i] == 0:
					Spells.hold(w, i, SpellTable.at_i(t.ticks, lv, 30), 0)  # knocked down
			if lv >= Spells.LEVELS:
				add(w, FIRE, t, lv, at, t.bonus_radius_m, t.bonus_ticks, t.bonus_damage)
		ORB:
			if lv >= Spells.LEVELS:
				Spells.fx(w, Spells.FX_DISCHARGE, at, at, t.bonus_radius_m, t.spell)
				_area(w, t, at, t.bonus_radius_m, t.bonus_damage, w.take_root())
		RING_LATER:
			Spells.fx(w, Spells.FX_THORNS, at, at, r, t.spell)
			ring(w, t, at, t.inner_m, r, w.spell_zone_dmg[k], w.spell_zone_root[k])
		HEMO:
			_hemorrhage(w, k, t)


## X2's end: the hit on its mark, then all its bleed at once, which spreads.
static func _hemorrhage(w: World, k: int, t: SpellTable) -> void:
	var a := w.actors
	var i := a.index_of(w.spell_zone_aux[k])
	if i <= 0 or a.dead[i] == 1:
		return
	var at := a.pos(i)
	var root := w.spell_zone_root[k]
	Spells.fx(w, Spells.FX_HEMO, at, at, w.spell_zone_r[k], t.spell)
	Spells.hit(w, i, w.spell_zone_dmg[k], root, at, t)
	Spells.status(w, i, t, root)
	var m := w.item_mods
	var n := a.bleed_stacks[i]
	if a.dead[i] == 1 or n <= 0 or m.bleed_period_ticks <= 0:
		return
	var periods := (a.bleed_t[i] + m.bleed_period_ticks - 1) / m.bleed_period_ticks
	var cash := m.bleed_damage * n * periods
	a.bleed_stacks[i] = 0
	a.bleed_t[i] = 0
	a.bleed_cd[i] = 0
	var pid := a.ids[0]
	Damage.tick_dot(w, i, cash, pid, pid, Spells.EFFECT_HEMORRHAGE, &"bleed")
	for id in _ids(w, Spells.enemies_within(w, at, w.spell_zone_r[k])):
		var j := a.index_of(id)
		if j > 0 and j != i and a.dead[j] == 0:
			Engines.add_bleed(w, j, n, root)


## Damage._apply: the player killed enemy `i`: a Lv 5 Venom Orb pool it died in leaves a small pool.
static func on_kill(w: World, i: int) -> void:
	var at := w.actors.pos(i)
	var small := 0
	for k in w.spell_zone_kind.size():
		if w.spell_zone_kind[k] == POOL and w.spell_zone_aux[k] == 1:
			small += 1
	if small >= SMALL_POOLS:
		return
	for k in w.spell_zone_kind.size():
		if (
			w.spell_zone_kind[k] != POOL
			or w.spell_zone_aux[k] != 0
			or w.spell_zone_level[k] < Spells.LEVELS
			or w.tick >= w.spell_zone_end[k]
		):
			continue
		var r := w.spell_zone_r[k]
		if (at - w.spell_zone_pos[k]).length_squared() > r * r:
			continue
		var t := Spells.table(w, w.spell_zone_spell[k])
		if t == null:
			return
		var p := add(
			w,
			POOL,
			t,
			w.spell_zone_level[k],
			at,
			t.bonus_radius_m,
			t.bonus_ticks,
			w.spell_zone_dmg[k]
		)
		if p >= 0:
			w.spell_zone_aux[p] = 1
			w.spell_zone_next[p] = w.tick + t.period_ticks
		return


static func hash_into(w: World, h: StateHasher) -> void:
	h.add_ints(w.spell_zone_kind)
	h.add_ints(w.spell_zone_spell)
	h.add_ints(w.spell_zone_level)
	h.add_ints(w.spell_zone_root)
	h.add_ints(w.spell_zone_end)
	h.add_ints(w.spell_zone_next)
	h.add_ints(w.spell_zone_dmg)
	h.add_ints(w.spell_zone_aux)
	h.add_ints(w.spell_zone_aux2)
	for p in w.spell_zone_pos:
		h.add_f32(p.x)
		h.add_f32(p.y)
	for p in w.spell_zone_vel:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_f32s(w.spell_zone_r)
	h.add_ints(w.spell_hold_id)
	h.add_ints(w.spell_hold_t)
	h.add_ints(w.spell_hold_permille)


## For the view (WorldReader.spell_zones): each zone's kind, spell, level, centre, radius and the life left (0..1000).
static func read(w: World) -> Dictionary:
	var left := PackedInt32Array()
	for k in w.spell_zone_kind.size():
		var t := Spells.table(w, w.spell_zone_spell[k])
		var life := _life(w, k, t)
		left.append(clampi((w.spell_zone_end[k] - w.tick) * 1000 / maxi(1, life), 0, 1000))
	return {
		"kind": w.spell_zone_kind.duplicate(),
		"spell": w.spell_zone_spell.duplicate(),
		"level": w.spell_zone_level.duplicate(),
		"pos": w.spell_zone_pos.duplicate(),
		"r": w.spell_zone_r.duplicate(),
		"left": left,
		"root": w.spell_zone_root.duplicate(),  # a stable key for the view's held effects
		"aux": w.spell_zone_aux.duplicate(),
	}


## A zone's full life (ticks; the view's fade).
static func _life(w: World, k: int, t: SpellTable) -> int:
	if t == null:
		return 1
	var lv := w.spell_zone_level[k]
	match w.spell_zone_kind[k]:
		METEOR_MARK, HEMO, RING_LATER:
			return maxi(1, t.delay_ticks)
		PUFF, THORN_WALL:
			return maxi(1, t.bonus_ticks)
		FIRE:
			if t.spell != Spells.BURNING_GROUND:
				return maxi(1, t.bonus_ticks)
		POOL:
			if w.spell_zone_aux[k] == 1:
				return maxi(1, t.bonus_ticks)
	return maxi(1, SpellTable.at_i(t.ticks, lv, 240))
