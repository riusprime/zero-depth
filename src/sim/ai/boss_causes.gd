class_name BossCauses
extends RefCounted
## The death recap's cause for a boss kill (moved out of BossAi in v0.8.0 FB3 to keep that file within its length;
## the rules are unchanged): the attack that landed it, a signature's late part, the closing band, a fireball's pattern.
## Pure.


## The death recap line for a boss kill: the attack that landed it (World.killer_attack), else the boss's projectile
## attack for a bolt, else &"".
static func key(w: World) -> StringName:  # gdlint: ignore=max-returns
	if w.killer_attack == Breakables.KILL_CAUSE:  # v0.9.0 DX: an explosive barrel's blast (no actor's attack)
		return Breakables.CAUSE_KEY
	var t := w.boss_table_of_kind(w.killer_kind)
	if t == null and w.killer_attack >= BossSignatures.LATE_CAUSE:
		# v0.8.0 BS2 (S5): a turret's ricochet names the boss that deployed it (its deploy attack's late part)
		t = _live_table(w)
		return BossSignatures.late_cause_key(t, w.killer_attack) if t != null else &""
	if t == null:
		return &""
	if w.killer_attack == BossChallenge.ARENA_ATTACK:
		return &"CAUSE_BOSS_ARENA"  # BX: the closing band
	if w.killer_attack >= BossSignatures.LATE_CAUSE:  # v0.8.0 BS1: a javelin coming back, an egg's burst
		return BossSignatures.late_cause_key(t, w.killer_attack)
	if w.killer_attack >= 0 and w.killer_attack < t.attacks.size():
		return t.attacks[w.killer_attack].cause_key
	for atk in t.attacks:  # v0.7.5 BF1: a fireball's, the boss's first pattern (or bolt fan)
		if (
			(atk.move == BossAttackTable.Move.BOLT_FAN or atk.move == BossAttackTable.Move.PATTERN)
			and w.killer_tags & SimEvent.TAG_PROJECTILE
		):
			return atk.cause_key
	return t.attacks[0].cause_key if not t.attacks.is_empty() else &""


## v0.8.0 BS2: the table of the first live boss (the recap of a turret's ricochet), or null.
static func _live_table(w: World) -> BossTable:
	for b in w.bosses.size():
		var i := w.actors.index_of(w.bosses.ids[b])
		if i >= 0:
			return BossAi.table_of(w, i)
	return null
