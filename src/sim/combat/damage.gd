class_name Damage
extends RefCounted
## The damage pipeline (SIM_CONTRACTS §8, without items until v0.2.0): HIT, then target multipliers (per-mille,
## never a flat cut), then HP, then DAMAGE, then at most one KILL. Every event carries its provenance.


## Per-mille multiplier for a hit arriving from `from` (the player's guard, the Warden's armour). Returns
## [mult, tags]. The Warden never blocks (owner, 2026-10-07): a hit from its front arc is ARMOURED (front mult), one
## from its rear arc lands on its WEAK_SPOT (rear mult), and the sides (or a hit from its own position) take 1000.
static func target_mult(w: World, target: int, from: Vector2) -> Array[int]:
	var a := w.actors
	var to_attacker := Kin.angle_of(from - a.pos(target))
	if target == 0 and w.guarding():
		if Kin.angle_diff(to_attacker, a.facing[0]) <= w.player.guard_half_arc:
			return [w.player.guard_mult_permille, SimEvent.TAG_GUARDED]
	elif BossAi.is_boss_kind(a.kinds[target]) and from != a.pos(target):
		# Bosses (v0.3.0 C): armour by direction, as the Warden's.
		var bt := BossAi.table_of(w, target)
		var off := Kin.angle_diff(to_attacker, a.facing[target])
		if bt.front_half_arc > 0 and off <= bt.front_half_arc:
			return [bt.front_mult_permille, SimEvent.TAG_ARMOURED]
		if bt.rear_half_arc > 0 and off >= 2048 - bt.rear_half_arc:
			return [bt.rear_mult_permille, SimEvent.TAG_WEAK_SPOT]
	elif a.kinds[target] == ActorStore.Kind.WARDEN and from != a.pos(target):
		var def := w.enemy_table(a.kinds[target])
		if def != null:
			var off := Kin.angle_diff(to_attacker, a.facing[target])
			if def.front_half_arc > 0 and off <= def.front_half_arc:
				return [def.front_mult_permille, SimEvent.TAG_ARMOURED]
			if def.rear_half_arc > 0 and off >= 2048 - def.rear_half_arc:
				return [def.rear_mult_permille, SimEvent.TAG_WEAK_SPOT]
	return [1000, 0]


## Applies one hit to the actor at index `target`. `from` is where the attack came from (the attacker, or the
## projectile's previous position), `at` where it landed. `effect_id` names the item effect that made the hit
## (v0.2.0), or &"". Returns the HP removed.
static func hit(
	w: World,
	target: int,
	amount: int,
	source_id: int,
	owner_id: int,
	root_id: int,
	tags: int,
	from: Vector2,
	at: Vector2,
	effect_id: StringName = &""
) -> int:
	var a := w.actors
	if a.dead[target] == 1:
		return 0
	var target_id := a.ids[target]
	# Items: Executioner is an attacker multiplier, applied before the target's (SIM_CONTRACTS §8 step 2).
	var exec := ItemProcs.execute_mult(w, target, owner_id)
	if exec != 1000:
		amount = amount * exec / 1000
		tags |= SimEvent.TAG_EXECUTE
	var h := w.emit_event(SimEvent.Kind.HIT, source_id, owner_id, target_id, at)
	h.root_id = root_id
	h.amount = amount
	h.tags = tags
	h.proc_pct = 100
	h.effect_id = effect_id
	if amount <= 0 or a.invuln[target] > 0 or (target == 0 and w.dash_iframes_active()):
		return 0
	var m := target_mult(w, target, from)
	h.tags |= m[1]
	var scaled := amount * m[0] / 1000
	var got := 0
	if scaled > 0:
		got = _apply(
			w, target, scaled, source_id, owner_id, root_id, h.tags, at, h.seq, 1, effect_id
		)
	if target == 0 and m[1] & SimEvent.TAG_GUARDED:
		ItemProcs.on_guard_block(w)  # Items: Phase Strike.
	return got


## A damage-over-time tick (SIM_CONTRACTS §8): DAMAGE with TAG_DOT and proc_pct 0, never a HIT, so it can't
## trigger on-hit effects. A status tick opens its own root. Ignores guard and armour; skips invulnerable or dead
## targets. Returns the HP removed.
static func tick_dot(
	w: World, target: int, amount: int, source_id: int, owner_id: int, effect_id: StringName
) -> int:
	var a := w.actors
	if a.dead[target] == 1 or a.invuln[target] > 0 or amount <= 0:
		return 0
	var root := w.take_root()
	return _apply(
		w,
		target,
		amount,
		source_id,
		owner_id,
		root,
		SimEvent.TAG_DOT,
		a.pos(target),
		-1,
		0,
		effect_id
	)


## Removes HP, emits DAMAGE (child of parent_seq at `depth`) and at most one KILL.
static func _apply(
	w: World,
	target: int,
	scaled: int,
	source_id: int,
	owner_id: int,
	root_id: int,
	tags: int,
	at: Vector2,
	parent_seq: int,
	depth: int,
	effect_id: StringName
) -> int:
	var a := w.actors
	var target_id := a.ids[target]
	var applied := mini(scaled, a.hp[target])
	a.hp[target] -= applied
	var d := w.emit_event(SimEvent.Kind.DAMAGE, source_id, owner_id, target_id, at)
	d.root_id = root_id
	d.parent_seq = parent_seq
	d.depth = depth
	d.amount = scaled
	d.amount_applied = applied
	d.tags = tags
	d.effect_id = effect_id
	d.proc_pct = 0 if tags & SimEvent.TAG_DOT else 100
	if target == 0:
		a.invuln[0] = w.player.hurt_iframe_ticks
		w.add_freeze(w.player.hurt_freeze_ticks)
	if a.hp[target] <= 0:
		a.dead[target] = 1
		if target == 0:
			var k := a.index_of(owner_id)
			w.killer_kind = a.kinds[k] if k >= 0 else -1
			w.killer_tags = tags
		var k := w.emit_event(SimEvent.Kind.KILL, source_id, owner_id, target_id, at)
		k.root_id = root_id
		k.parent_seq = d.seq
		k.depth = depth + 1
		k.effect_id = effect_id
		if target != 0 and owner_id == a.ids[0]:
			ItemProcs.on_kill(w, k)  # Items: Vampiric Core.
	if target != 0 and not (tags & SimEvent.TAG_DOT):
		BossAi.on_damage(w, target, applied)  # Bosses (v0.3.0 C): hits fill the stagger meter.
	if target == 0:
		ItemProcs.on_player_hurt(w)  # Items: Thorn Mantle.
	return applied
