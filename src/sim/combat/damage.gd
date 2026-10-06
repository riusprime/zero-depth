class_name Damage
extends RefCounted
## The damage pipeline (SIM_CONTRACTS §8, without items until v0.2.0): HIT, then target multipliers (per-mille,
## never a flat cut), then HP, then DAMAGE, then at most one KILL. Every event carries its provenance.


## Per-mille multiplier for a hit arriving from `from` (guard, shields). Returns [mult, tags].
static func target_mult(w: World, target: int, from: Vector2) -> Array[int]:
	var a := w.actors
	var to_attacker := Kin.angle_of(from - a.pos(target))
	if target == 0 and w.guarding():
		if Kin.angle_diff(to_attacker, a.facing[0]) <= w.player.guard_half_arc:
			return [w.player.guard_mult_permille, SimEvent.TAG_GUARDED]
	elif a.kinds[target] == ActorStore.Kind.WARDEN and from != a.pos(target):
		var def := w.enemy_table(a.kinds[target])
		if def != null and Kin.angle_diff(to_attacker, a.facing[target]) <= def.shield_half_arc:
			return [0, SimEvent.TAG_BLOCKED]
	return [1000, 0]


## Applies one hit to the actor at index `target`. `from` is where the attack came from (the attacker, or the
## projectile's previous position), `at` where it landed. Returns the HP removed.
static func hit(
	w: World,
	target: int,
	amount: int,
	source_id: int,
	owner_id: int,
	root_id: int,
	tags: int,
	from: Vector2,
	at: Vector2
) -> int:
	var a := w.actors
	if a.dead[target] == 1:
		return 0
	var target_id := a.ids[target]
	var h := w.emit_event(SimEvent.Kind.HIT, source_id, owner_id, target_id, at)
	h.root_id = root_id
	h.amount = amount
	h.tags = tags
	h.proc_pct = 100
	if amount <= 0 or a.invuln[target] > 0 or (target == 0 and w.dash_iframes_active()):
		return 0
	var m := target_mult(w, target, from)
	h.tags |= m[1]
	var scaled := amount * m[0] / 1000
	if scaled <= 0:
		return 0
	var applied := mini(scaled, a.hp[target])
	a.hp[target] -= applied
	var d := w.emit_event(SimEvent.Kind.DAMAGE, source_id, owner_id, target_id, at)
	d.root_id = root_id
	d.parent_seq = h.seq
	d.depth = 1
	d.amount = scaled
	d.amount_applied = applied
	d.tags = h.tags
	if tags & SimEvent.TAG_FULL_CHARGE:
		w.add_freeze(w.player.bolt_full_hitstop_ticks)
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
		k.depth = 2
	return applied
