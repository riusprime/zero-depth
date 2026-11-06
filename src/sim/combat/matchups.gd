class_name Matchups
extends RefCounted
## v0.10.5 O10 (owner P3 "yes": the stress matrix as rock-paper-scissors; docs/roadmap/v0.10.5/O10_STRESS_MATRIX.md):
## every enemy kind (not a boss, not an elite) is weak to one form or element and resists another (EnemyTable.weak_to,
## resists: a form card's modifier id or an element id). A player's direct hit whose attack carries the id (the spec's
## modifier_ids or elements; the launch's spec or the landing one, either counts) takes weak_permille (TAG_WEAK_TO) or
## resist_permille (TAG_RESISTED); a damage-over-time tick of that element (burn: ember, poison: venom, bleed: bleed)
## takes the same. A hit that matches both cancels to 1000. Per-mille multipliers, never a flat cut (SIM_CONTRACTS
## §8 step 3); a resisted hit that lands keeps at least 1. Pure and integer.


## [multiplier per mille, tags] for the player's direct hit on actor `i` of an attack built by `spec` and/or `launch`
## (either may be null).
static func hit_mult(w: World, i: int, spec: AttackSpec, launch: AttackSpec = null) -> Array[int]:
	var t := table_of(w, i)
	if t == null:
		return [1000, 0]
	var weak := has(spec, t.weak_to) or has(launch, t.weak_to)
	var resisted := has(spec, t.resists) or has(launch, t.resists)
	return pick(t, weak, resisted)


## Sets the matchup the next Damage.hit takes (a direct hit's caller, right before it).
static func arm(w: World, i: int, spec: AttackSpec, launch: AttackSpec = null) -> void:
	var m := hit_mult(w, i, spec, launch)
	w.matchup_permille = m[0]
	w.matchup_tags = m[1]


## Takes the armed matchup ([per mille, tags]) and resets it, so a hit nested in this one is neutral.
static func take(w: World) -> Array[int]:
	var m: Array[int] = [w.matchup_permille, w.matchup_tags]
	w.matchup_permille = 1000
	w.matchup_tags = 0
	return m


## [multiplier per mille, tags] for the player's damage-over-time tick of `element` on actor `i`.
static func dot_mult(w: World, i: int, element: StringName) -> Array[int]:
	if element == &"":
		return [1000, 0]
	var t := table_of(w, i)
	if t == null:
		return [1000, 0]
	return pick(t, element == t.weak_to, element == t.resists)


## Whether `spec` is of the form or element `id`: a form card that rewrote it, or an element it carries.
static func has(spec: AttackSpec, id: StringName) -> bool:
	if spec == null or id == &"":
		return false
	var s := String(id)
	return spec.modifier_ids.has(s) or spec.elements.has(s)


static func pick(t: EnemyTable, weak: bool, resisted: bool) -> Array[int]:
	if weak == resisted:
		return [1000, 0]
	if weak:
		return [t.weak_permille, SimEvent.TAG_WEAK_TO]
	return [t.resist_permille, SimEvent.TAG_RESISTED]


## `amount` × `permille` / 1000; a softened hit that had damage keeps at least 1.
static func scale(amount: int, permille: int) -> int:
	if permille == 1000 or amount <= 0:
		return amount
	return maxi(1, amount * permille / 1000)


## The enemy table of actor `i` when it has a matchup (a normal enemy kind), else null.
static func table_of(w: World, i: int) -> EnemyTable:
	if i <= 0:
		return null
	var k := w.actors.kinds[i]
	if not EnemyAi.is_enemy_kind(k) or BossAi.is_boss_kind(k) or EliteAi.is_elite_kind(k):
		return null
	var t := w.enemy_table(k)
	if t == null or (t.weak_to == &"" and t.resists == &""):
		return null
	return t
