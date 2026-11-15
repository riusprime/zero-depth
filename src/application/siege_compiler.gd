class_name SiegeCompiler
extends RefCounted
## Compiles a boss's siege mechanics (BossDefinition.siege, SiegeRules.SPEC) into its table's BossSiegeTable, in sim
## units (its own file: ContentCompiler is at its line limit).

## The enemy the ammo cart's body is (a sturdy walker that never acts as a cart: BossDoom moves it).
const CART_ENEMY := &"warden"


## PatternCompiler.compile_cadence: the siege mechanics, or none (t.siege stays null). The boss's attacks are compiled
## already (the turrets' kind is its first `deploy` attack's enemy).
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var sg := def.siege
	if sg.is_empty():
		return
	var st := BossSiegeTable.new()
	st.lock_phase = _int(sg, "lock_phase")
	st.lock_first_ticks = _ticks(sg, "lock_first_seconds")
	st.lock_every_ticks = _ticks(sg, "lock_every_seconds")
	st.lock_ticks = _ticks(sg, "lock_seconds")
	st.lock_hold_ticks = _ticks(sg, "lock_hold_seconds")
	st.lock_radius_m = SiegeRules.value(sg, "lock_radius_m")
	st.lock_follow = _int(sg, "lock_follow_permille")
	st.lock_hit = _int(sg, "lock_permille")
	st.boulder_half = SiegeRules.value(sg, "boulder_size_m") * 0.5
	st.boulder_ticks = _ticks(sg, "boulder_seconds")
	st.boulder_max = _int(sg, "boulder_max")
	st.cover_phase = _int(sg, "cover_phase")
	st.shock_cap = _int(sg, "shockwave_cap_permille")
	st.doom_phase = _int(sg, "doom_phase")
	st.doom_first_ticks = _ticks(sg, "doom_first_seconds")
	st.doom_every_ticks = _ticks(sg, "doom_every_seconds")
	st.doom_count = _int(sg, "doom_count")
	st.doom_late_phase = _int(sg, "doom_late_phase")
	st.doom_late_count = _int(sg, "doom_late_count")
	st.cart_hp = _int(sg, "cart_hp_permille")
	st.cart_radius_m = SiegeRules.value(sg, "cart_radius_m")
	st.cart_ticks = _ticks(sg, "cart_roll_seconds")
	st.doom_ticks = _ticks(sg, "doom_delay_seconds")
	st.doom_hit = _int(sg, "doom_permille")
	st.cart_blast_m = SiegeRules.value(sg, "cart_blast_m")
	st.cart_blast_hit = _int(sg, "cart_blast_permille")
	st.strip_ticks = _ticks(sg, "strip_seconds")
	st.strip_taken = _int(sg, "strip_taken_permille")
	st.cart_kind = ContentCompiler.ENEMY_KINDS[CART_ENEMY]
	for k in def.attacks.size():
		var a := def.attacks[k]
		if a == null:
			continue
		if a.move == &"deploy" and st.turret_kind < 0:
			st.turret_kind = t.attacks[k].enemy_kind
		if a.move == &"marks" and st.shell_cause < 0:
			st.shell_cause = k
	t.siege = st


static func _int(sg: Dictionary, key: String) -> int:
	return int(SiegeRules.value(sg, key))


static func _ticks(sg: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(SiegeRules.value(sg, key)))
