class_name SpellRoster
extends RefCounted
## The casts of
## the twelve spells O10 left for O11 (Spells.cast hands them here). Each returns true when it cast (it had its target),
## else the slot waits ready. The lasting parts run in SpellZones; the instant ones hit here (Spells.hit, status).
## - F1 Blizzard: a storm (SpellZones.BLIZZARD) on the densest pack, pulsing from now.
## - F3 Ice Lances: `count` shards at the nearest enemies, each hitting its line's first 1 + pierce enemies out to
##   reach; Lv 5: a shard's hit that kills splits into 2 more at the 2 nearest others within jump_m (one hit each).
## - B2 Burning Ground: a patch under you (an enemy within reach); Lv 5 it follows you.
## - B3 Meteor: the mark on the densest pack, locked now (SpellZones.METEOR_MARK; the strike at its end).
## - L2 Ball Lightning: an orb from you along your facing (an enemy within reach), at speed_m_tick.
## - L3 Static Field: a field around you (an enemy within reach).
## - V1 Venom Orb: an orb lobbed at the densest pack (the Fireballs' flight, Spells.land): the pool where it lands.
## - V2 Toxic Cloud: the cloud behind you (an enemy within reach), its first puff now.
## - V3 Spitter Vine: a vine where you stand (an enemy within reach), spitting from now.
## - X1 Blood Thorns: the ring now (an enemy in it); Lv 3+ a second ring delay_ticks later; Lv 5 the wall.
## - X2 Hemorrhage: `count` marks on the enemies with the most HP within reach (ties: the nearest, the lower index).
## - X3 Leech: a drain around you (a bleeding enemy within its radius; Lv 5 any enemy), pulsing from now.


static func cast(w: World, t: SpellTable, lv: int) -> bool:
	match t.spell:
		Spells.BLIZZARD:
			return _on_pack(w, t, lv, SpellZones.BLIZZARD, 0)
		Spells.ICE_LANCES:
			return _ice_lances(w, t, lv)
		Spells.BURNING_GROUND:
			return _burning_ground(w, t, lv)
		Spells.METEOR:
			return _on_pack(w, t, lv, SpellZones.METEOR_MARK, SpellZones.NEVER)
		Spells.BALL_LIGHTNING:
			return _ball_lightning(w, t, lv)
		Spells.STATIC_FIELD:
			return _around(w, t, lv, SpellZones.STATIC)
		Spells.VENOM_ORB:
			return _venom_orb(w, t, lv)
		Spells.TOXIC_CLOUD:
			return _around(w, t, lv, SpellZones.CLOUD)
		Spells.SPITTER_VINE:
			return _around(w, t, lv, SpellZones.VINE)
		Spells.BLOOD_THORNS:
			return _blood_thorns(w, t, lv)
		Spells.HEMORRHAGE:
			return _hemorrhage(w, t, lv)
		Spells.LEECH:
			return _leech(w, t, lv)
	return false


static func _has_enemy(w: World, at: Vector2, reach: float) -> bool:
	return not Spells.enemies_within(w, at, reach).is_empty()


## A zone of `kind` locked on the densest pack (Blizzard, Meteor's mark).
static func _on_pack(w: World, t: SpellTable, lv: int, kind: int, first: int) -> bool:
	var c := Spells.densest_pack(w, w.player_pos(), t.reach_m)
	if c < 0:
		return false
	var life := SpellTable.at_i(t.ticks, lv, 240) if kind == SpellZones.BLIZZARD else t.delay_ticks
	var r := SpellTable.at_f(t.radius_m, lv, 4.0)
	return (
		SpellZones.add(
			w, kind, t, lv, w.actors.pos(c), r, life, SpellTable.at_i(t.damage, lv), first
		)
		>= 0
	)


## A zone of `kind` on you (Static Field, Toxic Cloud, Spitter Vine): an enemy within reach.
static func _around(w: World, t: SpellTable, lv: int, kind: int) -> bool:
	var at := w.player_pos()
	if not _has_enemy(w, at, t.reach_m):
		return false
	var r := SpellTable.at_f(t.radius_m, lv, 2.0)
	var k := SpellZones.add(
		w, kind, t, lv, at, r, SpellTable.at_i(t.ticks, lv, 240), SpellTable.at_i(t.damage, lv)
	)
	if k >= 0 and kind == SpellZones.STATIC:
		w.spell_zone_aux[k] = 1 if w.is_dashing() else 0  # a dash already running doesn't discharge it
	return k >= 0


static func _burning_ground(w: World, t: SpellTable, lv: int) -> bool:
	var at := w.player_pos()
	if not _has_enemy(w, at, t.reach_m):
		return false
	var k := SpellZones.add(
		w,
		SpellZones.FIRE,
		t,
		lv,
		at,
		SpellTable.at_f(t.radius_m, lv, 3.0),
		SpellTable.at_i(t.ticks, lv, 300),
		SpellTable.at_i(t.damage, lv)
	)
	if k >= 0 and lv >= Spells.LEVELS:
		w.spell_zone_aux[k] = 1  # Lv 5: it follows you
	return k >= 0


static func _ball_lightning(w: World, t: SpellTable, lv: int) -> bool:
	var at := w.player_pos()
	if not _has_enemy(w, at, t.reach_m):
		return false
	var k := SpellZones.add(
		w,
		SpellZones.ORB,
		t,
		lv,
		at,
		SpellTable.at_f(t.radius_m, lv, 2.5),
		SpellTable.at_i(t.ticks, lv, 240),
		SpellTable.at_i(t.damage, lv),
		t.period_ticks
	)
	if k >= 0:
		w.spell_zone_vel[k] = Kin.dir(w.actors.facing[0]) * t.speed_m_tick
	return k >= 0


## The orb flies like a Fireball (World.spell_ball_*); Spells.land makes the pool.
static func _venom_orb(w: World, t: SpellTable, lv: int) -> bool:
	var from := w.player_pos()
	var c := Spells.densest_pack(w, from, t.reach_m)
	if c < 0:
		return false
	Spells.throw_ball(w, t, lv, from, w.actors.pos(c))
	return true


## Spells.land: the orb came down at `at`.
static func pool(w: World, t: SpellTable, lv: int, at: Vector2) -> void:
	SpellZones.add(
		w,
		SpellZones.POOL,
		t,
		lv,
		at,
		SpellTable.at_f(t.radius_m, lv, 3.0),
		SpellTable.at_i(t.ticks, lv, 300),
		SpellTable.at_i(t.damage, lv)
	)


static func _ice_lances(w: World, t: SpellTable, lv: int) -> bool:
	var from := w.player_pos()
	var a := w.actors
	var targets := Spells.nearest_n(w, from, t.reach_m, SpellTable.at_i(t.count, lv, 3))
	if targets.is_empty():
		return false
	var ids := PackedInt32Array()
	for i in targets:
		ids.append(a.ids[i])
	var dmg := SpellTable.at_i(t.damage, lv)
	for id in ids:
		var i := a.index_of(id)
		if i < 0 or a.dead[i] == 1:
			continue
		var root := w.take_root()
		var line := Spells.line(w, from, a.pos(i), t.reach_m, 1 + t.pierce, id)
		var end := a.pos(i)
		var hit := PackedInt32Array()
		var killed := false
		var kill_at := end
		for jd in line:
			var j := a.index_of(jd)
			if j < 0 or a.dead[j] == 1:
				continue
			end = a.pos(j)
			hit.append(jd)
			Spells.hit(w, j, dmg, root, from, t)
			Spells.status(w, j, t, root)
			if a.dead[j] == 1 and not killed:
				killed = true
				kill_at = a.pos(j)
		Spells.fx(w, Spells.FX_LANCE, from, end, 0.0, t.spell)
		if killed and lv >= Spells.LEVELS:
			_split(w, t, dmg, root, kill_at, hit)
	return true


## F3 Lv 5: a kill splits the shard into 2 more at the 2 nearest other enemies within jump_m.
static func _split(
	w: World, t: SpellTable, dmg: int, root: int, at: Vector2, skip: PackedInt32Array
) -> void:
	var a := w.actors
	var n := 0
	for j in Engines.nearest_enemies(w, 0, at, t.jump_m, 2 + skip.size()):
		if n >= 2:
			break
		if skip.has(a.ids[j]) or a.dead[j] == 1:
			continue
		n += 1
		Spells.fx(w, Spells.FX_LANCE, at, a.pos(j), 0.0, t.spell)
		Spells.hit(w, j, dmg, root, at, t)
		Spells.status(w, j, t, root)


static func _blood_thorns(w: World, t: SpellTable, lv: int) -> bool:
	var at := w.player_pos()
	var r := SpellTable.at_f(t.radius_m, lv, 4.0)
	if not _has_enemy(w, at, r):
		return false
	var dmg := SpellTable.at_i(t.damage, lv)
	Spells.fx(w, Spells.FX_THORNS, at, at, r, t.spell)
	SpellZones.ring(w, t, at, t.inner_m, r, dmg, w.take_root())
	if lv >= 3:
		SpellZones.add(w, SpellZones.RING_LATER, t, lv, at, r, t.delay_ticks, dmg, SpellZones.NEVER)
	if lv >= Spells.LEVELS:
		SpellZones.add(
			w, SpellZones.THORN_WALL, t, lv, at, r, t.bonus_ticks, t.bonus_damage, t.period_ticks
		)
	return true


static func _hemorrhage(w: World, t: SpellTable, lv: int) -> bool:
	var a := w.actors
	var from := w.player_pos()
	var cands := Spells.enemies_within(w, from, t.reach_m)
	if cands.is_empty():
		return false
	var picked := PackedInt32Array()
	for n in SpellTable.at_i(t.count, lv, 1):
		var best := -1
		for c in cands:
			if picked.has(c):
				continue
			if best < 0 or a.hp[c] > a.hp[best]:
				best = c
			elif a.hp[c] == a.hp[best]:
				var dc := (a.pos(c) - from).length_squared()
				if dc < (a.pos(best) - from).length_squared():
					best = c
		if best < 0:
			break
		picked.append(best)
	for i in picked:
		var k := SpellZones.add(
			w,
			SpellZones.HEMO,
			t,
			lv,
			a.pos(i),
			SpellTable.at_f(t.radius_m, lv, 3.0),
			t.delay_ticks,
			SpellTable.at_i(t.damage, lv),
			SpellZones.NEVER
		)
		if k >= 0:
			w.spell_zone_aux[k] = a.ids[i]
	return true


static func _leech(w: World, t: SpellTable, lv: int) -> bool:
	var a := w.actors
	var at := w.player_pos()
	var r := SpellTable.at_f(t.radius_m, lv, 6.0)
	var ready := false
	for i in Spells.enemies_within(w, at, r):
		if lv >= Spells.LEVELS or a.bleed_stacks[i] > 0:
			ready = true
			break
	if not ready:
		return false
	return (
		SpellZones.add(
			w,
			SpellZones.LEECH,
			t,
			lv,
			at,
			r,
			SpellTable.at_i(t.ticks, lv, 240),
			SpellTable.at_i(t.damage, lv)
		)
		>= 0
	)
